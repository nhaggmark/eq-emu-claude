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

- [ ] Await architect task assignments from architecture.md
- [ ] If Phase 2 yields any scripted quest behavior questions (PoSky
  event scripts, lua/perl quest mechanics), loop in lua-expert or
  perl-expert as appropriate
- [ ] Q13 (Enraged Golem + 9 other NPCs not in raid_target=1 queries)
  is an architect task — no protocol impact, but if any have special
  abilities requiring removal, same server-side-only conclusion applies

---

## Context for Next Agent

Protocol-agent has completed Stage 1 consultation for Phase 2 Classic
raids. Core finding: **all Phase 2 changes (HP/damage scaling, death-touch
removal, respawn timer changes) are purely server-side and have zero client
protocol impact.** The Titanium client does not cache NPC stat values,
does not have a dedicated death-touch opcode, and has no client state tied
to respawn timers.

Key source refs:
- `CombatDamage_Struct` at eq_packet_structs.h:1335 — standard hit packet,
  death-touch removal just means this packet stops being sent with lethal values
- `MobHealth` at eq_packet_structs.h:1487 — HP percentage only, no absolute values
- `Death_Struct` at eq_packet_structs.h:1367 — same packet used for all kills

If future phases (Kunark VP scripts, Velious Ring War, VT key event) involve
scripted encounters with custom packet behavior, re-consult before those phases.
