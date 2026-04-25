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

### Phase 4a Architect Q&A (2026-04-22)

Architect followed up with four targeted feasibility questions. All answered:

**Q1 — Kael Avatar chain staggered scaling (Statue/Idol in 4a, Avatar in 4b):**
Clean — no client-cached chain state. Each spawn is an independent `NewSpawn_Struct`.
Scaling two of the three in 4a creates zero client anomaly.

**Q2 — Growth event-control NPCs (L1 1M HP `a_warm_light`, L65 1M HP `a_thifling_focuser`):**
No client anomaly. HP renders as uint8 percentage regardless of absolute value. `/consider`
shows green (L1) or level-appropriate con — cosmetically expected for event mobs. Leave as-is.

**Q3 — Jaled Dar's Shade (3M HP, turn-in NPC):**
No client concern. `MobHealth` = percentage only. 3M HP and 30k HP are identical on wire.
`/consider` correctly shows red (L70). Leave at 3M HP.

**Q4 — thurgadinb (Icewell Keep):**
Standard static outdoor zone, confirmed no DZ. Dain Frostreaver IV (129003) is a normal
static spawn. Scales identically to any outdoor boss via `npc_types` UPDATE.

**Q5 — Ring War Lua wave-count changes:**
Zero client impact. `eq.spawn_condition()` is server-internal. Client sees only
NewSpawn/DeleteSpawn per wave mob.

**Q6 — Respawn timer / Ring War interaction:**
Zero interaction. Ring War uses spawn_condition (not spawn2.respawntime) for waves.
Narandi's out-of-event respawntime is an independent system.

**Q7 — Velious-specific opcodes:**
None. All Phase 4a zones use standard ZoneChange_Struct → ZoneServerInfo_Struct flow.
No Velious-era opcode in Titanium client.

---

## Context for Next Agent

Protocol-agent has completed consultation for Phases 2 (Classic), 3 (Kunark), and
4a (Velious non-ToV). Core finding across all three phases: **all changes are purely
server-side and have zero Titanium client protocol impact.**

Key source refs:
- `CombatDamage_Struct` at eq_packet_structs.h:1335 — standard hit packet
- `MobHealth` at eq_packet_structs.h:1487 — HP percentage only, no absolute values
- `Death_Struct` at eq_packet_structs.h:1367 — same packet used for all kills
- `quest::setnexthpevent` — server-side trigger, percentage-based, unaffected by HP scale
- VP door-gate: `OP_MoveDoor` (standard Titanium opcode, no new protocol needed)
- `eq.spawn_condition()` — server-internal toggle, no client opcode
- `eq.unique_spawn()` — standard NewSpawn_Struct to client
- `thurgadinb` — standard static zone, not DZ/instance

Phase 4b (Velious ToV+Sleeper+Vulak) — consultation complete 2026-04-22.
Phase 5 (Luclin VT+Shards) warrants re-consultation when architect starts.

---

## Phase 4b: Velious ToV + Sleeper + Vulak + AoW Protocol Consultation (2026-04-22)

**Scope:** templeveeshan (16 dragon lords + 12 mid-tier named), sleeper (5 Ancients +
4 Warders + Progenitor + Final Arbiter + Master of the Guard + Milas An`Rev),
kael AoW (113457), Vulak`Aerr (124155, script-spawned).

**Summary finding: Phase 4b is fully server-side. Zero client protocol impact.**
Same conclusion as Phases 2, 3, and 4a. Detailed findings below.

### Files Examined

| File | What You Found |
|------|----------------|
| `akk-stack/server/quests/templeveeshan/player.lua` | Illegal-bind guard only — no DZ/expedition logic |
| `akk-stack/server/quests/sleeper/script_init.lua` | Loads `motg` encounter only — no DZ/expedition |
| `akk-stack/server/quests/sleeper/#Hraashna_the_Warder.pl` | EVENT_DEATH_COMPLETE checks entity_list for other 3 Warders; signalwith(128094,66,0) only if all 4 dead |
| `akk-stack/server/quests/sleeper/#Nanzata_the_Warder.pl` | Same pattern as Hraashna — signalwith(128094,66,0) conditional on all-4-dead |
| `akk-stack/server/quests/sleeper/#Ventani_the_Warder.pl` | Same pattern |
| `akk-stack/server/quests/sleeper/#Tukaarak_the_Warder.pl` | Same pattern |
| `akk-stack/server/quests/sleeper/#The_Sleeper.pl` | EVENT_SIGNAL(66): depop_withtimer + spawn2(128089) — spawns #Kerafyrm |
| `akk-stack/server/quests/sleeper/#Kerafyrm.pl` | EVENT_SPAWN: setglobal("kerafyrm",1,7,"F"), spawn_condition(sleeper,2,1), spawn_condition(sleeper,1,0), forcedooropen(46), timer→spawn2(128095) |
| `akk-stack/server/quests/sleeper/#Kerafyrm_.pl` | Roaming form (128095); setglobal("kerafyrm",2/3) on zone/death |
| `akk-stack/server/quests/sleeper/#Kildrukaun_the_Ancient.pl` | Checks entity_list for Kerafyrm on spawn — depops itself if Kerafyrm already up |
| `akk-stack/server/quests/sleeper/encounters/motg.lua` | Master of the Guard (128145) add-wave script — signal-driven sentry spawns |
| `akk-stack/server/quests/templeveeshan/#Vulak-Aerr.pl` | EVENT_AGGRO only: adds NPC 124157 to hate list — no spawn chain |
| `akk-stack/server/quests/templeveeshan/#Thylex_of_Veeshan.pl` | Vulak coordinator: checks 6 lords (124077/76/08/10/74/17) all dead, then spawn2(124155) + setglobal("vulak") |
| grep: DZ/expedition across both zone dirs | Zero hits — no DZ, no expedition in either zone |

### Finding 1: ToV + Sleeper's Tomb — Standard Static Zones

Both `templeveeshan` and `sleeper` are standard persistent static zones. No
`MovePCDynamicZone`, `expedition` API call, `DynamicZone`, or `ServerOP_Expedition*`
anywhere in either zone's scripts. Entry is via standard `ZoneChange_Struct` →
`ZoneServerInfo_Struct` flow — identical to Phase 4a kael/skyshrine.

ToV: unkeyed entry (L46+ CoV faction). Sleeper's Tomb: key item gates door access,
but no script enforces it at zone-entry level. Normal `#reloadworld` / repop refresh
applies to both zones.

### Finding 2: Kerafyrm / Sleeper Awake Event — Behavioral Gate Only

The awakening chain is triggered exclusively by gameplay kills. Exact flow:

1. Any Warder death → `EVENT_DEATH_COMPLETE` → entity_list check (other 3 Warders dead?)
2. If and only if all 4 dead → `quest::signalwith(128094, 66, 0)` to `#The_Sleeper`
3. `#The_Sleeper` `EVENT_SIGNAL(66)` → `quest::depop_withtimer()` + `quest::spawn2(128089)` (#Kerafyrm)
4. `#Kerafyrm` `EVENT_SPAWN` → `setglobal("kerafyrm",1,7,"F")` + `spawn_condition` flips + `forcedooropen(46)` + 1s timer → `spawn2(128095)` (#Kerafyrm_)

Client-visible packets: `OP_MoveDoor` (forcedooropen), `NewSpawn_Struct` (spawn2),
`DeleteSpawn_Struct` (depop). All standard.

**Scaling Warder HP emits zero awakening-related packets.** Gate is behavioral (kill
condition), not stat-based. Decision #12 is safe — HP scaling cannot accidentally
trigger awakening.

### Finding 3: Vulak`Aerr Summoning — Entity-Presence Check

Implemented in `#Thylex_of_Veeshan.pl`. On spawn, Thylex sets a 60s timer. On timer
fire, checks `GetMobByNpcTypeID()` for six lords (124077, 124076, 124008, 124010,
124074, 124017). If all absent AND qglobal `vulak` not set AND Vulak not spawned:
`quest::spawn2(124155, ...)` fires, Thylex depops.

Client sees: standard `NewSpawn_Struct` for Vulak. No altar-click opcode, no DZ.
Presence check is entity-based (not HP-based) — Phase 4b HP scaling on these 6 lords
does not affect the Vulak summoning chain. Same pattern as VP door-gate (Phase 3).

**Flag for architect:** Thylex_of_Veeshan is not in the boss catalog and is not a kill
target. Exclude from HP scaling SQL. Consider noting its coordinator role — if killed
by AoE before its timer fires, Vulak does not spawn that cycle.

### Finding 4: AoW Chain Closure — No New Concern

AoW (113457) spawned by `#The_Idol_of_Rallos_Zek.lua` `event_death_complete` →
`eq.unique_spawn(113457, ...)`. Client sees `NewSpawn_Struct`. Phase 4b scaling AoW
completes the Kael chain. Same pattern confirmed safe in Phase 4a.

### Finding 5: MobHealth Percentage — Ultra-High HP No-Op on Wire

`hp = (int)GetHPRatio()` — 0-100 percentage. Kerafyrm (3.5M untouched) and Jaled
Dar's Shade (3M untouched) are wire-identical to a 30k named mob. No overflow risk:
`npc_types.hp` is `bigint(20)`.

### Finding 6: Vyemm MR=1000 — Server-Side Only

`MR` is a `npc_types` column used in server-side spell resist calculation only. Client
never receives NPC resist values — sees only combat result packets. MR=1000 invisible
on wire. No client display concern.

### Finding 7: No Zone-Specific Titanium Quirks

No zone-specific protocol quirks in `templeveeshan` or `sleeper`. `player.lua`'s
MovePC on illegal bind sends standard zone-change traffic. No exotic opcodes.

### Phase 4b Protocol Summary

| Concern | Verdict |
|---------|---------|
| ToV / ST zone type | Standard static — no DZ/expedition |
| Warder HP scaling triggering awakening | Impossible — behavioral kill gate only |
| Kerafyrm awakening chain on wire | OP_MoveDoor + NewSpawn + DeleteSpawn — all standard |
| Vulak summoning | Entity presence check + NewSpawn_Struct — same as VP/AoW pattern |
| Vulak HP scaling vs summoning chain | Safe — check is entity presence, not HP |
| AoW chain closure | No new protocol concern |
| Ultra-high HP wire format (3.5M) | Percentage-only, no impact |
| Vyemm MR=1000 | Server-side only, invisible to client |
| Zone-specific Titanium quirks | None found |

**No Phase 4b changes require opcode additions, struct modifications, or Titanium
translation layer changes. Phase 4b is 100% server-side (SQL), same as Phases 2, 3, 4a.**

---

## Phase 5a: Luclin non-VT Protocol Consultation (2026-04-22)

**Scope:** Ssraeshza Temple (ssratemple), Akheva Ruins (akheva), Sanctus Seru
(sseru), Katta Castellum (katta), Grieg's End (griegsend), Umbral Plains (umbral),
Acrylia Caverns (acrylia), The Deep (thedeep). All Luclin raid zones excluding Vex
Thal (Phase 5b).

**Summary finding: Phase 5a is fully server-side. Zero client protocol impact.**
Same conclusion as Phases 2, 3, 4a, and 4b. Detailed findings below.

### Files Examined

| File | What You Found |
|------|----------------|
| `akk-stack/server/quests/ssratemple/#Emperor_Ssraeshza_.pl` | EVENT_SPAWN: 30-min depop timer. EVENT_COMBAT: extends timer to 40 min. EVENT_DEATH_COMPLETE: spawn2 x5 (A_shissar_wraith 162210), signal(162260,2) to EmpCycle. Standard spawn/signal only. |
| `akk-stack/server/quests/ssratemple/#EmpCycle.pl` | Full Emperor event controller. Uses qglobals (Emperor, BloodCoolDown), unique_spawn for Blood_of_Ssraeshza (162189) + Emperor_No_Target (162065), then EmpPrep timer spawns real Emperor (162227). Signal 1=Blood/Golem dead→EmpPrep, 2=Emperor dead→qglobal respawn timer (3-5 days), 3=raid failure→BloodCoolDown. No DZ. |
| `akk-stack/server/quests/ssratemple/#Blood_of_Ssraeshza.lua` | event_combat: spawns 4× Ssraezsha (162280) adds. event_death_complete: signal(162260,1) to EmpCycle. |
| `akk-stack/server/quests/ssratemple/#Ssraeshzian_Blood_Golem.lua` | Same pattern as Blood_of_Ssraeshza — combat spawns 4× Ssraezsha adds, death_complete signals EmpCycle. |
| `akk-stack/server/quests/ssratemple/#Vyzh-dra_the_Cursed.lua` | 30-min depop timer paused in combat. death_complete: signal(162255,3) to cursed_controller. |
| `akk-stack/server/quests/ssratemple/#Vyzh-dra_the_Exiled.lua` | 30-min depop timer. death_complete: signal(162255,2) + set_global("exiled_dead"). |
| `akk-stack/server/quests/ssratemple/#cursed_controller.pl` | Manages Cursed/Exiled/Banished/Glyphed/Runed Vyzh`dra spawn chain via entity_list checks and qglobals. Cascading qglobal-gated spawn sequence. No DZ. |
| `akk-stack/server/quests/akheva/#Shei_Vinitras_.lua` | Non-aggro merchant form. death_complete: spawns real Shei (179032=NPC ID for `#Shei_Vinitras`) + 4 named adds (Diabo_Tatrua, Tavuel_Tatrua, Thall_Tatrua, Va_Tatrua). Standard spawn-swap. |
| `akk-stack/server/quests/akheva/#Shei_Vinitras.lua` | Real Shei. event_spawn: spawns 4 named adds + sets 10-min depop. event_combat: stops depop, sets 5-min repopadds timer. event_timer(repopadds): re-spawns missing named adds on timer + AddToHateList. event_slay: spawns random Tatrua. |
| `akk-stack/server/quests/akheva/#The_Insanity_Crawler.lua` | event_slay only: spawns 5× A_mind_worm (179136). No death_complete chain. |
| `akk-stack/server/quests/akheva/#The_Itraer_Vius_.lua` | event_combat: CastSpell(2818,"Shadow Fog") + depop_with_timer. Simple script — casts one spell on aggro then vanishes. |
| `akk-stack/server/quests/griegsend/163045.lua` and `163046.lua` | Grieg Veneficus dual-guardian spawn chain: both guards must die + guard NPC 163097 still present → eq.unique_spawn(163075 = #Grieg_Veneficus) + depop_with_timer(163097). Entity-presence check. Same pattern as VP Phase 3. |
| `akk-stack/server/quests/sseru/#Lord_Inquisitor_Seru.pl` | Non-targetable placeholder. EVENT_AGGRO: starts timer. EVENT_TIMER: if still engaged → continue; else spawn2(159691 = real Seru) + depop. Timer-based swap from placeholder to real boss. Standard spawn-swap. |
| `akk-stack/server/quests/sseru/#Lord_Inquisitor_Seru_.pl` | Real Seru. EVENT_SPAWN: 1s timer → GMMove to time chamber if out of bounds. EVENT_DEATH: stoptimer. Pure positioning guard. |
| `akk-stack/server/quests/katta/#Nathyn_Illuminious.pl` | Quest NPC only (dialogue/item turn-in). Not a combat boss. No spawn or signal calls. |
| `akk-stack/server/quests/umbral/#Doomshade.lua` | 1-hour depop timer paused in combat. No add-wave or spawn chain. Simpler than Velious bosses. |
| `akk-stack/server/quests/acrylia/Khati_Sha_the_Twisted.lua` | event_combat: spawns 4× Defiled Minion adds + sets 120s re-spawn timer. event_timer(2): re-spawns 4 Defiled Minions every 2 min. event_timer(1): position guard — if Khati has left chamber, depops + respawns at original position. |
| `akk-stack/server/quests/thedeep/The_Burrower_Beast.pl` | Event controller for Burrower Beast encounter. Wave-based spawn sequence (8 counters: rock burrowers → spined rock burrowers → stone carvers → core burrowers → parasite larva → burrower parasite). Proximity-triggered. No DZ. |
| DZ/expedition grep — all Phase 5a zones | Zero hits across ssratemple, akheva, griegsend, sseru, katta, thedeep, acrylia, umbral. One false positive ("expedition" in NPC dialogue text — Tilbok_Furrunner.pl, not API call). |
| spawn_condition/setnexthpevent grep — all Phase 5a zones | Zero hits. No HP-percentage event hooks in any Phase 5a zone. |

### Finding 1: All Phase 5a Zones Are Standard Static Zones — No DZ/Expedition

Zero use of `MovePCDynamicZone`, `expedition` API, `DynamicZone`, or
`ServerOP_Expedition*` in any Phase 5a zone. All zones use standard
`ZoneChange_Struct` → `ZoneServerInfo_Struct` entry flow.

Contrast with Phase 2's `hateplaneb` which DID use `MovePCDynamicZone("hateplaneb")`.
No Phase 5a equivalent. No expedition protocol overhead.

### Finding 2: Emperor Ssraeshza — Complex Event, Server-Side Only

The Emperor encounter uses the most complex event script in any phase so far.
The full flow:

```
#EmpCycle (162260) — always-running coordinator NPC
  ↓ unique_spawn #Blood_of_Ssraeshza (162189) + #Emperor_NoTarget (162065)
  ↓ Blood killed → signal(162260,1) → EmpPrep 150s timer
  ↓ EmpPrep fires → depop(162065) + unique_spawn real Emperor (162227) → qglobal BloodCoolDown
Blood_of_Ssraeshza combat → 4× Ssraezsha adds (162280)
Emperor (162227) killed → 5× shissar_wraith (162210) + signal(162260,2) → qglobal EmpRespawnTimer (3-5 days)
Raid failure (Emperor_NoTarget depop timer) → signal(162260,3) → qglobal BloodCoolDown (3-4h)
```

**Protocol assessment:** The entire event chain uses `quest::unique_spawn`,
`quest::spawn2`, `quest::signalwith`, and qglobals. Client sees only:
- `NewSpawn_Struct` for each spawned NPC
- `DeleteSpawn_Struct` for each depop
- `ChannelMessage_Struct` for the death emote

No new opcodes. No DZ. No client-cached event state. The cascading spawn
sequence is indistinguishable on the wire from any other quest-script spawn chain.

**HP scaling implication:** The Emperor's 1,250,500 HP drop to ~120k does NOT
affect EmpCycle's qglobal-gate logic (gate checks NPC presence via
`GetNPCByNPCTypeID`, not HP). Blood_of_Ssraeshza's HP drop (no audit figure
given — investigate) similarly safe; signal fires on death_complete not on
HP threshold. Ssraezsha adds (162280) are NOT in the boss catalog — verify HP.

**Key flag for architect:** The EmpPrep 150s timer and BloodCoolDown (3-4h) /
EmpRespawnTimer (3-5 days) are Lua/Perl LOCAL variables. These timers are not
`rule_values` — they cannot be tuned via SQL. If the architect wants to reduce
the 3-5 day post-kill respawn window, that requires a **Perl edit** to `#EmpCycle.pl`
variables `$BloodCoolDownTime` and `$EmpRepopTime`. lua-expert / perl-expert task.

### Finding 3: Vyzh`dra Chain — Server-Side Spawn Sequence

`#cursed_controller.pl` (162255) manages a multi-form boss sequence:
1. Entity-check loop every 60s: checks all 10 `#cursed_*` NPCs (162270-162279)
2. If all dead → spawns Glyphed (162261) or Runed (162253) serpent based on qglobal `glyphed_dead`
3. Signal 1 from Exiled death → spawns Exiled or Banished based on qglobal `exiled_dead`
4. Signal 2 from Exiled death → spawns Cursed (162206)
5. Signal 3 from Cursed death → qglobal `cursed_dead` (respawn timer)

**Protocol assessment:** Multi-form chain of 4-5 Vyzh`dra variants. All transitions
are `quest::spawn2` + qglobal checks. Client sees standard `NewSpawn_Struct` /
`DeleteSpawn_Struct`. Same pattern as Kerafyrm chain (Phase 4b). No protocol impact.

**HP scaling implication:** Cursed (162206), Exiled (NPC ID from scripts: 162232
"Exiled" reference in cursed_controller), Banished (162214), and their pre-boss
cursed_1-10 variants are all separate NPC IDs. Architect should enumerate all
IDs in the Vyzh`dra chain for the SQL UPDATE list.

### Finding 4: Shei Vinitras — Spawn-Swap with Periodic Add Wave

`#Shei_Vinitras_.lua` (non-aggro merchant form, NPC 179157) → death triggers
spawn of real Shei (179032) + 4 named adds. Real Shei then re-spawns those 4 adds
every 5 minutes via timer if they die.

**Protocol assessment:** Standard spawn-swap (same VS, Tunare patterns from
Phases 3/4a). The 5-min add-rewave is a server-side timer + entity_list presence
check — `NewSpawn_Struct` + `AddToHateList` (server AI action). No new opcodes.

**HP scaling implication:** Only the non-aggro merchant form (179157) is in the
boss catalog. The real boss form (179032) is a separate NPC ID — needs to be in
the UPDATE list. The 4 periodic adds (Diabo_Tatrua 179174, Tavuel_Tatrua 179181,
Thall_Tatrua 179164, Va_Tatrua 179173) are not in the audit catalog. Architect:
flag these as potential add-scaling candidates.

### Finding 5: Grieg's End — Dual-Guardian Entity-Check Gate

Grieg Veneficus (163075) is spawned only after both guardian NPCs 163045 and 163046
are dead AND event-control NPC 163097 is still present. Same entity-presence pattern
as VP door-gate (Phase 3) and Vulak summoning (Phase 4b). No protocol impact.

No `player.lua` / `player.pl` in griegsend. No zone-entry mechanics beyond
standard Grieg's Key (item check at door — client sees `OP_ClickDoor` /
`OP_MoveDoor` standard opcodes).

### Finding 6: Lord Inquisitor Seru — Timer-Based Swap from Placeholder

Non-targetable placeholder NPC (159691 in sseru — `#Lord_Inquisitor_Seru.pl`)
transitions to targetable real boss via a timer/engagement check. Same
timer-swap pattern as Velious Tunare (`#_Tunare.lua`, Phase 4a). Client sees:
`DeleteSpawn_Struct` for placeholder, `NewSpawn_Struct` for real boss. No new opcodes.

### Finding 7: Khati Sha the Twisted — Periodic Combat Adds

`Khati_Sha_the_Twisted.lua` (likely NPC 154145 in acrylia): on combat spawns 4×
Defiled Minion adds, then re-spawns them every 2 minutes via timer. Position
guard timer resets Khati if she leaves her chamber. Same periodic-add pattern
as Shei Vinitras real form.

**Protocol assessment:** Server-side timer spawns. Client sees `NewSpawn_Struct`
per add. No new opcodes.

### Finding 8: Burrower Beast (The Deep) — Wave Event, No DZ

The Burrower Beast encounter uses a proximity-triggered 8-wave add sequence
(rock burrowers → core burrowers → parasite larva → burrower parasite). The
event controller (164120) spawns waves on a repeating timer, success/failure
signals back to event-controller NPC (164098). No DZ, no expedition. Same
pattern as Ring War (Phase 4a) but simpler.

**Thought Horror Overfiend (164078):** No quest scripts found referencing this
NPC ID. No add-wave or event chain. Simple static spawn — pure SQL scaling.

### Finding 9: No HP-Percentage Event Hooks in Phase 5a

Zero `quest::setnexthpevent`, `eq.set_hp_event_by_number`, or `EVENT_HP`
usage across all Phase 5a zones. Contrast with Phase 3's Phara Dar which used
`quest::setnexthpevent(80/60/40/20)` add-wave triggers. Phase 5a has NO
HP-threshold scripted events. Boss HP can be freely reduced without affecting
any scripted thresholds.

### Finding 10: Doomshade (Umbral Plains) — Simple, No Script Concerns

Simple depop-timer script only. No add-waves, no spawn chain. Not in the
audit boss catalog. Architect should verify: is Doomshade (176111 per audit
lore section?) distinct from `#Netherbian_Swarmfiend` (L73, OOE)?

### Phase 5a Protocol Summary

| Concern | Source | Verdict |
|---------|--------|---------|
| HP/damage/respawn scaling (all ~30 bosses) | Phase 2-4b analysis applies | Server-side SQL only; client sees % HP |
| All Phase 5a zones — DZ/expedition | grep all zone scripts | Zero hits — all standard static zones |
| HP-percentage event hooks | grep all zone scripts | Zero — no EVENT_HP / setnexthpevent in any Phase 5a zone |
| Emperor Ssraeshza event chain (EmpCycle, Blood, Golem, adds) | ssratemple/#EmpCycle.pl + friends | Fully server-side: qglobals, unique_spawn, signalwith. No protocol impact. |
| EmpCycle respawn timers ($EmpRepopTime 3-5 days, $BloodCoolDownTime 3-4h) | ssratemple/#EmpCycle.pl | Perl LOCAL variables — NOT rule_values. Tuning requires perl-expert edit. |
| Vyzh`dra multi-form chain (Cursed/Exiled/Banished/Glyphed/Runed) | ssratemple/#cursed_controller.pl | Server-side qglobal + spawn2 chain. Same pattern as Kerafyrm. |
| Shei Vinitras spawn-swap + periodic adds | akheva/#Shei_Vinitras_.lua + #Shei_Vinitras.lua | Standard spawn-swap; add-rewave is server-side timer. |
| Grieg Veneficus dual-guardian gate | griegsend/163045.lua + 163046.lua | Entity-presence check; same as VP/Vulak. |
| Lord Inquisitor Seru placeholder swap | sseru/#Lord_Inquisitor_Seru.pl | Timer-swap; same as Tunare Phase 4a. |
| Khati Sha periodic combat adds | acrylia/Khati_Sha_the_Twisted.lua | Server-side timer; standard NewSpawn_Struct. |
| Burrower Beast wave event (The Deep) | thedeep/The_Burrower_Beast.pl | Proximity-triggered wave script; no DZ. |
| Thought Horror Overfiend (164078) | grep — no script | Simple static spawn. Pure SQL. |
| Doomshade (Umbral) | umbral/#Doomshade.lua | Simple depop-timer; no chain. |

**No Phase 5a changes require opcode additions, struct modifications, or Titanium
translation layer changes. Phase 5a is 100% server-side (SQL + optional Perl edit
for EmpCycle timers), same as Phases 2, 3, 4a, 4b.**

**One notable flag for architect:** EmpCycle `$EmpRepopTime` (3-5 days post-kill
respawn) and `$BloodCoolDownTime` (3-4h failure cooldown) are hardcoded Perl locals,
not SQL-tunable. If architect wants shorter post-kill window for Phase 5a small-group
cadence, a perl-expert edit is required — similar to Ring War's lua-expert wave timer
reduction in Phase 4a.

**Second flag:** Shei Vinitras real boss form (179032) is a DIFFERENT NPC ID from
the merchant form (179157) in the audit catalog. Both need to be in the SQL UPDATE
list. Same issue applies to any NPC with a placeholder + real form split (Emperor
pre-target 162065 is NOT the fight boss 162227 — pre-target should be excluded).

**Third flag:** Vyzh`dra chain has multiple NPC IDs beyond the audit's "162206" entry:
also Exiled (162232 in scripts), Banished (162214), Glyphed serpent (162261), Runed
serpent (162253). Most are intermediate forms or pre-cursed mobs, not the boss kill
target. Architect should confirm which IDs receive the boss-tier HP treatment vs. which
are pre-event mobs.

---

## Phase 5b: Vex Thal Protocol Consultation (2026-04-22)

**Scope:** Vex Thal proper (vexthal zone) — Aten Ha Ra encounter system, 13 inner
bosses (158006-158016), Akhevan Warders (158087-94), Va_Dyn_Khar (158081), ~80 Yaemiu
elite trash (158000-158086 range), Spirit of Akelha`Ra key mechanic (179144 in akheva),
13-shard VT key quest structure.

**Summary finding: Phase 5b is fully server-side. Zero client protocol impact.**
Same conclusion as Phases 2, 3, 4a, 4b, and 5a. **One DT spell found — see Flag A.**

### Files Examined

| File | What You Found |
|------|----------------|
| `akk-stack/server/quests/vexthal/player.lua` | Illegal-bind guard only (MovePC if bind == zone 158). No DZ/expedition. |
| `akk-stack/server/quests/vexthal/#Aten_Ha_Ra.pl` | Qglobal-gated respawn via `quest::setglobal("aten",1,3,"M$spawntime")` — 1.8h variance. EVENT_SPAWN 1s timer checks qglobal. EVENT_DEATH_COMPLETE sets qglobal. |
| `akk-stack/server/quests/vexthal/#Aten_Ha_Ra_.pl` | Non-aggro form (158096). 48-hour depop timer. Same death_complete → qglobal pattern as 158006. |
| `akk-stack/server/quests/vexthal/#Aten_Trigger.pl` | Entity-presence controller NPC. 60s poll loop: if no inner bosses (9 IDs 158007-158015) present → spawn non-aggro Aten (158096); elif Aten not spawned → spawn aggro Aten (158006). Same entity-check pattern as Vulak (Phase 4b). |
| `akk-stack/server/quests/vexthal/#Kaas_Thox_Xi_Ans_Dyek.pl` | On spawn: `quest::spawn2(158087,...)` × 2 — Akhevan Warder guards. On death_complete: `quest::depopall(158087)`. Pattern: boss summons guards on spawn, depops guards on death. |
| `akk-stack/server/quests/vexthal/#Diabo_Xi_Va.pl` | Same warder-control pattern — summons NPC 158088 × 5. |
| `akk-stack/server/quests/vexthal/#Diabo_Xi_Xin.pl` | Same warder-control pattern — summons NPC 158088 × 5. |
| `akk-stack/server/quests/vexthal/#Diabo_Xi_Xin_Thall.pl` | Same warder-control pattern — summons NPC 158089 × 7. |
| `akk-stack/server/quests/vexthal/#Thall_Xundraux_Diabo.pl` | Same warder-control pattern — summons NPC 158091 × 5. |
| `akk-stack/server/quests/vexthal/#Thall_Va_Kelun.pl` | Same warder-control pattern — summons NPC 158090 × 2. |
| `akk-stack/server/quests/vexthal/#Va_Xi_Aten_Ha_Ra.pl` | Same warder-control pattern — summons NPC 158094 × 14 (second floor area). On death_complete: depopall(158094). |
| `akk-stack/server/quests/vexthal/#Diablo_Xi_Va_Temariel.pl` | Same warder-control pattern — summons NPC 158091 × 5. |
| `akk-stack/server/quests/vexthal/158016.lua` | #Thall_Va_Xakra (south wing) — on combat, calls MoveTo() on 26 spawn-group IDs every 30s to assist. Same zone-aggro-move pattern as Phase 4a King Tormax adds. Server-side AI only. |
| `akk-stack/server/quests/vexthal/158125.lua` | #Thall_Va_Xakra (north wing, NPC 158125) — identical 27-spawn-group MoveTo assist pattern. |
| `akk-stack/server/quests/vexthal/akhevan_trigger.lua` | Proximity-trigger trap spawner (NPC 158468). On event_enter (non-GM): spawns random Yaemiu mob from tiered pool (Qua/Zov/Zun/Pli/Eom classes, 30 mob IDs) with 30-min depop. eq.set_proximity() for detection radius. No DZ. |
| `akk-stack/server/quests/vexthal/#Eom_Centien_Xakra.lua` | Simple 37-min depop timer. No add-wave, no chain. Representative of all named Yaemiu Xakra variants. |
| `akk-stack/server/quests/vexthal/#Pli_Thall_Xakra.lua` | Identical 37-min depop timer. Same pattern. |
| `akk-stack/server/quests/akheva/#The_Spirit_of_Akelha-Ra.lua` | NPC 179144 in akheva (NOT vexthal). event_trade with item 9963 → summons item 17323 (Shadowed Scepter Frame) + 20k XP. 4-min depop timer. Standard event_trade / SummonItem — no special protocol. |
| DB query: npc_types WHERE id 158000–158200 AND raid_target=1 | Full VT NPC catalog: 127 distinct raid_target=1 IDs. Inner bosses 158006-158016, 158125. Warders 158087-94 (NULL respawn = script-only). Va_Dyn_Khar 158081 (600k HP). Yaemiu trash 158000-158086 range. |
| DB query: npc_spells_entries for all VT boss spell lists | **CRITICAL: spell 1948 "Destroy" found in list 229** (NPC 158006 #Aten_Ha_Ra). DT-profile: mana=0, cast_time=0, effectid1=0 (SE_CurrentHP), effect_base_value1=-100,000. Same DT signature as spell 982 (Cazic Touch) and spell 2859 (Touch of Vinitras). recast_delay=-1, priority=35. |
| DZ/expedition grep — vexthal/ | Zero hits. vexthal is a standard static zone. |

### Finding 1: Vex Thal Zone Type — Standard Static Zone, No DZ

`vexthal/player.lua` contains only an illegal-bind guard with `MovePC()`. No `MovePCDynamicZone`, no `expedition` API, no `DynamicZone`, no `ServerOP_Expedition*` anywhere in the vexthal quest directory (full grep confirmed).

Config-expert's Phase 5a confirmation noted `dynamic_zones` table has 0 rows on this PEQ version. VT entry is via standard `ZoneChange_Struct` → `ZoneServerInfo_Struct` flow, identical to every prior phase.

**Protocol conclusion:** No DZ/expedition overhead. Same as all prior phases.

### Finding 2: Aten Ha Ra Encounter System — Qglobal + Entity-Check, Server-Side Only

The Aten Ha Ra encounter uses a three-NPC coordination system:

```
#Aten_Trigger (entity-presence controller, always up)
  ↓ 60s poll: checks 9 inner bosses (158007-158015) all absent?
  ↓ If all absent AND qglobal "aten" not set → spawn #Aten_Ha_Ra_ (158096, non-aggro)
  ↓ If any inner boss present AND #Aten_Ha_Ra not up → spawn #Aten_Ha_Ra (158006, aggro)
#Aten_Ha_Ra (158006) killed → qglobal "aten"=1 with M$spawntime variance (~1.8h)
#Aten_Ha_Ra (158006) EVENT_SPAWN → 1s timer checks qglobal; depops if qglobal set
#Aten_Ha_Ra_ (158096) killed → same qglobal set; 48h depop timer
```

**Protocol assessment:** Identical architecture to Phase 4b's `#Thylex_of_Veeshan.pl`
(entity-presence gate) + Phase 5a's `#Aten_Ha_Ra.pl` (qglobal respawn window). All
transitions are `quest::spawn2` + qglobal checks. Client sees `NewSpawn_Struct` /
`DeleteSpawn_Struct`. No new opcodes.

**HP scaling implication:** Both 158006 (#Aten_Ha_Ra, aggro form) and 158096 (#Aten_Ha_Ra_,
non-aggro / "destroy" form) have 1,901,500 HP. The entity-presence check is NPC-type-ID
based, not HP-based — scaling is safe for both forms.

**CRITICAL FLAG A — see Finding 5.**

### Finding 3: Warder-Control Pattern — Boss Summons Guards on Spawn, Depops on Death

Every VT inner boss (except Aten Ha Ra system and Thall Va Xakra) uses the same
warder-control pattern in its script:

- `EVENT_SPAWN` → `quest::spawn2(158087/88/89/90/91/94, ...)` × N (2-14 guards depending on boss)
- `EVENT_DEATH_COMPLETE` → `quest::depopall(158087/88/89/90/91/94)`

The Akhevan Warder NPC IDs (158087-94) all have `spawn2.respawntime = NULL` — they have
no independent spawn2 rows, existing solely as script-spawned guards.

**Protocol assessment:** This is the same `quest::spawn2` + `quest::depopall` pattern
confirmed safe in Phase 3 (VP door-gate) and Phase 4b (AoW chain). Client sees
`NewSpawn_Struct` per guard (on boss spawn) and `DeleteSpawn_Struct` per guard
(on boss death). No new opcodes.

**HP scaling implication for Akhevan Warders (158087-94):** Current HP is 901,000.
Since they have no spawn2 rows (NULL respawn), they cannot be scaled via the standard
`spawn2.respawntime` UPDATE path. HP UPDATE on `npc_types.hp` for these 8 IDs is safe
and will take effect on next repop/zone restart.

### Finding 4: Thall Va Xakra Zone-Aggro Assist — Server-Side AI Only

NPC 158016 (south) and NPC 158125 (north) both run Lua scripts that call `GetNPCBySpawnID()`
for 26-27 spawn group entries and invoke `MoveTo()` every 30 seconds when engaged. This
pulls trash mobs from across the wing to assist the boss.

**Protocol assessment:** Server-side `MoveTo()` pathfinding AI. Client sees normal
`PlayerPositionUpdateServer_Struct` packets as the mobs path toward the boss — standard
mob movement traffic. No special opcode. Same pattern as Phase 4a King Tormax's
`MoveTo()` on adds.

**HP scaling implication:** Scaling 158016 and 158125 HP is safe. The assist mechanic
checks spawn-group presence, not HP threshold.

### Finding 5: DEATH-TOUCH SPELL — Spell 1948 "Destroy" in List 229 (Aten Ha Ra)

**This is the critical protocol finding for Phase 5b.**

DB query of npc_spells_entries for all VT boss spell lists reveals:

```
npc_spells_id=229 (used by NPC 158006 #Aten_Ha_Ra):
  spellid=1948  "Destroy"  mana=0  cast_time=0  recast_delay=-1  priority=35
                effectid1=0 (SE_CurrentHP)  effect_base_value1=-100,000  targettype=4
```

Comparison against prior DT spells:

| Spell ID | Name | Value | Recast | Target | Used in Phase |
|----------|------|-------|--------|--------|---------------|
| 982 | Cazic Touch | -100,000 | 0 | Single (type 5) | Phase 2 — DELETED |
| 2859 | Touch of Vinitras | -20,000 | 120s | Single (type 5) | Phase 5a — DELETED |
| **1948** | **Destroy** | **-100,000** | **-1 (no limit)** | **AE/Group (type 4)** | **Phase 5b — TO FLAG** |

"Destroy" (spell 1948) is MORE dangerous than prior DTs: it is targettype=4, which
in EQEmu is PBAE (point-blank area effect on the caster's targets). Cazic Touch and
Touch of Vinitras were single-target (type 5). "Destroy" can potentially hit multiple
players simultaneously.

**Protocol assessment:** The DT kill is delivered as standard `CombatDamage_Struct` /
`Death_Struct` packets exactly as with Cazic Touch and Touch of Vinitras. No special
client opcode needed for DT removal. Removal is a single `DELETE` from `npc_spells_entries`
WHERE npc_spells_id=229 AND spellid=1948.

**Other spells in list 229 to PRESERVE:**
- spellid=2157 "Word of Command" (effectid1=21, type=AE charm) — Aten Ha Ra signature mechanic
- spellid=2164 "Silence of the Shadows" (effectid1=96, silence/stun) — signature
- spellid=2167 "Fling" (effectid1=0, -1 HP) — proximity knockback

**List 540 (#Aten_Ha_Ra_, NPC 158096) — CLEAN:** No spell 1948. Contains only 2157,
2164, 2167. No DT delete needed for the non-aggro form.

**Decision required from architect:** Delete spell 1948 from list 229 (same pattern
as Phase 2 Decision #16 Cazic Touch DELETE and Phase 5a Decision #16-pattern Touch of
Vinitras DELETE), or keep it as an Aten Ha Ra signature mechanic. Given that:
- "Destroy" is AE (not single-target), making it more punishing at small group scale
- Aten Ha Ra already has Word of Command (AE charm), Silence of the Shadows, and Fling
  as signature mechanics
- The PBAE DT would hit a 1-3 player group simultaneously (potentially wiping entire raid)
- Phase precedent strongly favors DELETE per Decisions #13 and #16

Architect recommendation: **DELETE spell 1948 from list 229.** One row.

### Finding 6: Yaemiu Trap Spawner — Proximity Event, No Protocol Concern

`akhevan_trigger.lua` (NPC 158468) uses `eq.set_proximity()` to detect zone entry
into trap areas. On enter, spawns a random Yaemiu mob from 30 IDs across five tiers
(Qua L55 / Zov L58 / Zun L61 / Pli L64 / Eom L66) with a 30-min depop timer.

**Protocol assessment:** `eq.set_proximity()` is server-side entity proximity detection —
same mechanism confirmed safe in Phase 4a (Ring War approach detection). Client sees
`NewSpawn_Struct` for the trap spawn. No special opcodes.

### Finding 7: Spirit of Akelha`Ra Key Mechanic — Standard EVENT_TRADE, No Protocol Concern

NPC 179144 (`#The_Spirit_of_Akelha-Ra`) lives in `akheva` (not vexthal). The shard
turn-in script checks `item_lib.check_turn_in(e.trade, {item1 = 9963})` and responds
with `e.other:SummonItem(17323)` — Shadowed Scepter Frame.

**Protocol assessment:** This is a standard `OP_TradeAccept` / `OP_ItemPacket` sequence.
`SummonItem()` sends `ItemPacket_Struct` with type `CharInventory` (0x69). No new opcodes.
The NPC's 1M HP (untouched per Decision #30 precedent) is cosmetic — client sees percentage
only via `MobHealth` uint8 percentage field.

**Phase 5b implication:** No HP scaling on 179144 per Decision #30 precedent. The shard
turn-in quest works regardless of the NPC's HP value.

### Finding 8: No HP-Percentage Event Hooks in Vex Thal

Full grep of vexthal quest directory for `setnexthpevent`, `set_hp_event_by_number`,
`EVENT_HP` returned zero results. Boss HP can be freely reduced without affecting any
scripted thresholds. Same finding as Phase 5a.

### Phase 5b Protocol Summary

| Concern | Source | Verdict |
|---------|--------|---------|
| vexthal zone type | vexthal/player.lua + config-expert DZ table (0 rows) | Standard static zone — no DZ/expedition |
| HP-percentage event hooks | grep vexthal scripts | Zero — boss HP freely scalable |
| Aten Ha Ra encounter system (158006/158096 + Aten_Trigger) | #Aten_Ha_Ra.pl, #Aten_Ha_Ra_.pl, #Aten_Trigger.pl | Qglobal + entity-check; all server-side; same as Phase 4b Vulak pattern |
| Warder-control pattern (all inner bosses 158007-158015, 158009) | All boss .pl scripts | quest::spawn2 guards on spawn, depopall on death; same as VP Phase 3 |
| Akhevan Warder respawn (158087-94) | DB query (NULL respawn) | Script-only spawns, no spawn2 rows; HP UPDATE on npc_types safe |
| Thall Va Xakra zone-aggro assist (158016, 158125) | 158016.lua, 158125.lua | Server-side MoveTo(); same as King Tormax adds Phase 4a |
| Proximity trap spawner (akhevan_trigger.lua) | akhevan_trigger.lua | eq.set_proximity() server-side; NewSpawn_Struct per trap; no DZ |
| Spirit of Akelha`Ra shard turn-in (179144) | akheva/#The_Spirit_of_Akelha-Ra.lua | Standard OP_TradeAccept / SummonItem — no new opcodes |
| **DT spell "Destroy" (1948) in list 229 (Aten Ha Ra 158006)** | npc_spells_entries DB query | **FLAG A: AE DT — DELETE recommended. One row. Same pattern as Phase 2 + 5a DT removals.** |
| List 540 (#Aten_Ha_Ra_ 158096) — DT check | DB query | Clean — no spell 1948. No action needed. |
| Fling spell 2167 (multiple VT lists) | DB query + spells_new | effectid1=0, value=-1 HP, targettype=2 (PBAE). Knockback utility, NOT a DT. |
| Yaemiu trash scaling (158000-158086 range) | DB query | All have spawn2.respawntime = 640 or 960s — standard SQL UPDATE path |
| Va_Dyn_Khar (158081) | DB query | spawn2.respawntime=960 — standard SQL UPDATE path |
| HP/damage scaling (all VT NPCs) | Phase 2-5a analysis applies | Server-side SQL only; client sees % HP |

**No Phase 5b changes require opcode additions, struct modifications, or Titanium
translation layer changes. Phase 5b is 100% server-side (SQL + 1 npc_spells_entries
DELETE for Aten Ha Ra DT), same as all prior phases.**

**Phase 5b Flags for Architect:**

**Flag A — CRITICAL DT:** Spell 1948 "Destroy" in npc_spells_id=229 (NPC 158006
#Aten_Ha_Ra). This is an AREA-EFFECT DT (targettype=4 PBAE, -100,000 HP, no recast
limit per recast_delay=-1). Protocol impact of removal: zero — same standard
CombatDamage_Struct / Death_Struct path as prior DT removals. Data-expert task:
DELETE FROM npc_spells_entries WHERE npc_spells_id=229 AND spellid=1948. Preserve
2157, 2164, 2167.

**Flag B — Aten Ha Ra dual-form (158006 vs 158096):** Same pattern as Phase 5a
Shei Vinitras dual-form (179032 vs 179157). Both forms have 1,901,500 HP. Both need
to be in the HP UPDATE list if architect wants to scale them equally. The non-aggro
form (158096) drops into role once inner bosses are killed — it is still a kill target.
List 540 (158096's spell list) is clean (no DT).

**Flag C — Warders script-only spawn:** Akhevan Warders (158087-94, 901k HP each)
have no spawn2 rows (NULL respawntime) — they exist only via boss script spawn2 calls.
HP UPDATE on npc_types.hp for these 8 IDs will take effect on next repop. No
spawn2.respawntime UPDATE possible or needed for warders.

**Flag D — Thall Va Xakra duplication:** Two NPC IDs for Thall Va Xakra: 158016
(south wing) and 158125 (north wing). Both have 900,000 HP. Both have spawn2 rows
with respawntime=640s. Both need to be in the SQL UPDATE list (same issue as
Phase 5a Shei dual-form and Akheva elite-named duplicate IDs).
