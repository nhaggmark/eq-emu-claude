# Raid Scaling Audit — Classic through Luclin

> **Feature branch:** `feature/raid-scaling`
> **Phase:** 1 (Audit — no code changes)
> **Authors:** game-designer (mechanics) + lore-master (quest progression)
> **Date:** 2026-04-21
> **Status:** In Progress

---

## Purpose

This document catalogs every raid encounter (boss or scripted event) and every
raid-tier quest chain across Classic, Kunark, Velious, and Luclin. For each
entry it records:

- Current state (stats, mechanics, progression gates)
- Whether the prior small-group-scaling pass (completed 2026-02-23) touched it
- The gap relative to this project's difficulty philosophy
- A recommended action

The audit is the Phase 1 deliverable. It is not a design or implementation
document — it is the evidence base the user will use to decide whether to
proceed with one sustained Phase 2-5 effort or split the era phases into
separate projects.

## Scope

- **In scope:** every raid boss in Classic, Kunark, Velious, Luclin zones;
  every raid-tier quest chain (Epic 1.0 for all 14 classes, Plane of Sky
  islands, VP key, Sleeper's Tomb key, Vex Thal shard quest, Coldain Ring War,
  Thurgadin/Kael/Skyshrine faction access, ToV key, Emperor Ssraeshza key,
  Seru key, etc.).
- **Out of scope:** trash and named mobs in raid zones (already scaled and
  feel right to the user per brief). Loot table redesign. New content.

## Difficulty Philosophy (from feature brief)

- Trash / named mobs: unchanged (already feel right).
- Raid bosses: slightly harder than a current scaled named mob — not
  overwhelmingly so.
- Tiered curve: early-era raids are mechanically harder (positioning, add
  management). Endgame raids are peak mastery (preparation and mistakes punish).
- Group composition assumption: 1 player + 5 companions (~6 effective bodies).
  Scaling must remain playable when a human or two joins.

---

## Prior Pass Summary (small-group-scaling, completed 2026-02-23)

The earlier project tuned overland and group content for 1-3 player play.
This audit must start from what it did and didn't do:

### What the prior pass TOUCHED at raid-tier

| Target | Prior pass action | Effect on raid bosses |
|--------|-------------------|-----------------------|
| `loottable_entries.probability` | `×1.5` (cap 100) for any loottable referenced by `rare_spawn = 1 OR raid_target = 1` | Raid-boss loot tables boosted — each kill is more likely to drop each table's rare item |
| `lootdrop_entries.chance` | `×1.5` (cap 25) for rare drops (chance < 20) in raid-boss-linked lootdrops | Rare raid-boss items drop more often |
| `spawn2.respawntime` | `×0.75` (floor 60s) for spawns linked to `rare_spawn = 1 OR raid_target = 1` NPCs | Raid bosses respawn ~25% faster than PEQ default (note: brief requests 6-24h; may still need further reduction) |
| `Zone:GlobalLootMultiplier` | 1 → 2 | All loot (including raid) has ~2x chance per roll |
| `Combat:MaxRampageTargets` | 3 → 2 | Raid-boss rampage hits at most 2 party members |
| `Combat:NPCFlurryChance` | 20 → 12 | Raid-boss flurries are less frequent |
| `NPC:StartEnrageValue` | 9 → 5 | Raid bosses enrage later (at 5% HP) |

### What the prior pass DID NOT TOUCH at raid-tier

| Target | Prior pass action | Effect on raid bosses |
|--------|-------------------|-----------------------|
| `npc_types.hp` | UPDATE ... WHERE `raid_target = 0` | **Raid-boss HP at default PEQ values** |
| `npc_types.mindmg` | UPDATE ... WHERE `raid_target = 0` | **Raid-boss min-damage at default** |
| `npc_types.maxdmg` | UPDATE ... WHERE `raid_target = 0` | **Raid-boss max-damage at default** |
| `npc_types.AC` | UPDATE ... WHERE `raid_target = 0` | **Raid-boss AC at default** |
| `npc_scale_global_base` type 2 | Comment: "Leave type 2 (raid) unchanged" | **Auto-scaled raid bosses use default baseline** |

**Quote from prior PRD (Area 6 — Raid Content Accessibility):** "No
special raid-specific rules are changed. The global NPC stat reduction
applies to raid targets too…" — *the final implementation
contradicted this*: the architect's SQL (tasks 8 and 9) explicitly
filtered on `raid_target = 0`, so raid bosses were excluded. This was
intentional per Area 6's tier analysis, which classified Nagafen/Vox/Trak/VS
as "Tier 2 — achievable by 2-3 geared players" but acknowledged Tier 3
(TOV/Sleeper/Emperor/VT/Sky) as "requires companion system — defer".

### Interaction with the companion system

The companion system (signature feature) is now live. The prior pass
deferred raid accessibility to "when companions exist". This project
is the follow-through: with a 1 player + 5 companion group now a
reality, raid content needs to be tuned to match.

### Scaled-named baseline (reference)

After the prior pass, a level-60 named mob using `npc_scale_global_base`
has approximately: HP 8,100 / damage 56-319 / AC 230. This is the
reference point the difficulty philosophy says bosses should be
"slightly harder than". Raid-tier baseline (type 2) at level 60 is
HP 450,813 / damage 185-740 / AC 476 — roughly **55x the HP** of a
scaled named. That ratio is the gap.

---

## Audit methodology

### Identifying raid encounters

The `raid_target = 1` flag in `npc_types` is necessary but NOT sufficient.
PEQ uses the flag for two purposes:

1. **True raid bosses** (Nagafen, Vox, VP dragons, Emperor Ssraeshza, etc.)
2. **Raid-zone trash** — entire populations of Plane of Fear, Plane of Hate,
   Plane of Growth, Sleeper's Tomb, Vex Thal, and Temple of Veeshan are
   flagged `raid_target = 1` so they bypass normal immunity/scaling paths.

Example: Plane of Fear has 97 `raid_target = 1` NPCs but only ~6 are true
bosses (Cazic Thule, The Tempest Reaver, Dread/Fright/Terror, Wraith of a
Shissar, a Dracoliche). The remaining 91 are shiverbacks, scarelings,
amygdalans, and other trash.

**Classification within this audit:**

- **BOSS** — primary raid encounter, loot-dropping, lore-significant.
  The target of scaling changes.
- **EVENT MOB** — scripted event trigger or required sub-encounter
  (e.g. Sleeper warders, Emperor's guards). May need scaling.
- **ELITE TRASH** — `raid_target = 1` used for mechanical reasons only.
  Already covered by prior scaling pass logic (trash difficulty is
  out of scope per brief) — listed for completeness, no action required.

### Fabled / anniversary NPCs

PEQ contains `#The_Fabled_*` NPCs at levels 70-75. These are post-Luclin
"Legends of Norrath" anniversary content. The server era-lock
(`Expansion:CurrentExpansion = 3`) should prevent them from spawning,
but they are flagged where they appear and recommended `NO ACTION —
OUT OF ERA`.

### Data sources used

- `peq` database via `docker exec akk-stack-mariadb-1 mysql`
- `akk-stack/server/quests/` for scripted boss behaviors
- everquest.fandom.com/wiki/ for lore + quest progression
- everquest.allakhazam.com for quest walkthroughs
- Prior project at `/mnt/d/Dev/eq/claude/tmp/raid-scaling/prior-*.md`

---

## Per-Boss Entry Template

```
### <Boss Name> — <short_name> (<expansion>)

- **NPC ID(s):** <id> (plus era-variant IDs if multiple exist)
- **Level:** <level>
- **Stats (current):** HP <hp> / dmg <mindmg>-<maxdmg> / AC <ac> / MR <mr>
- **Special abilities:** <special_abilities flags> / <npcspecialattks>
- **Scripted behavior:** <file path under akk-stack/server/quests/ if any>
- **Adds / event mobs:** <linked NPCs if this is a multi-phase encounter>
- **Respawn timer:** <current respawntime in seconds and hours>
- **Prior-pass status:** Scaled / Partially scaled (loot/respawn only) / Untouched / Special case
- **Gap vs. scaled-named baseline at this level:** <x× HP, y× damage>
- **Recommended action:** <no change / scale down HP+damage / rework mechanics / flag for deeper review>
- **Notes:** <anything else — era variants, known broken mechanics, etc.>
```

## Per-Quest-Chain Entry Template (lore-master)

```
### <Quest / Chain Name>

- **Class / scope:** <class if epic, or "general raid access">
- **Era:** Classic / Kunark / Velious / Luclin (or multi-era)
- **Zones:** <list>
- **Turn-in NPCs:** <list with NPC IDs if known>
- **Raid encounters required:** <list — cross-link to boss entries above>
- **Non-encounter blockers:**
  - Rare-spawn ground-spawns / PH chains
  - Faction grinds (which factions, approx. hours for solo)
  - Group-required turn-ins or event triggers
- **Progression path:** <what gates what>
- **Small-group blockers:** <specific issues for 1p + 5 companions>
- **Recommended action:** <no change / scaling-dependent / quest-script tweak / special handling>
- **Lore continuity notes:** <any scaling changes that would conflict with lore>
```

---

## Classic (expansion 0)

### Classic raid boss catalog

> Populated by task #3 (game-designer).

### Classic raid quest chains

> Populated by task #7 (lore-master). Includes: Epic 1.0 Classic-phase
> steps for all 14 classes, Plane of Sky key/island progression,
> any miscellaneous Classic-era raid access.

---

## Kunark (expansion 1)

### Kunark raid boss catalog

> Populated by task #4 (game-designer).

### Kunark raid quest chains

> Populated by task #8 (lore-master). Includes: Epic 1.0 Kunark-phase
> steps (most epics cluster heavily here — Sebilite Scale, Faydedar,
> Venril Sathir, Trakanon, etc.), Veeshan's Peak key quest, Emerald
> Jungle / Skyfire hand quest chain.

---

## Velious (expansion 2)

### Velious raid boss catalog

> Populated by task #5 (game-designer). **Flag for user:** Temple of
> Veeshan has 110 `raid_target = 1` NPCs and Plane of Growth has 99
> — most are elite trash, but true boss counts are still large. May
> recommend splitting Velious into its own sub-phase.

### Velious raid quest chains

> Populated by task #9 (lore-master). Includes: Coldain Ring War,
> Coldain Shawl 8 + Prayer Shawl, Thurgadin/Kael/Skyshrine faction
> access, ToV key quest, Sleeper's Tomb key, Ring of Scale faction,
> Avatar of War trigger, Ancient dragons quests.

---

## Luclin (expansion 3)

### Luclin raid boss catalog

> Populated by task #6 (game-designer).

### Luclin raid quest chains

> Populated by task #10 (lore-master). Includes: Vex Thal shard quest
> (13 shards from Luclin raid targets), Emperor Ssraeshza key, Seru /
> Sanctus Seru access, Fungus Grove progression, any Luclin-era Epic
> 1.0 steps.

---

## Cross-reference Matrix (populated at consolidation — task #11)

### Raw boss counts by zone / era

| Era | Zone | `raid_target = 1` NPCs (raw) | Est. true bosses | Gap status |
|-----|------|------------------------------|------------------|------------|
| Classic | fearplane | 97 | ~6 | |
| Classic | hateplaneb | 170 | ~6 | |
| Classic | hateplane | 34 | ~3 | |
| Classic | airplane | 5 | 4 | |
| Classic | soldungb | 1 | 1 (Nagafen) | |
| Classic | permafrost | 1 | 1 (Vox) | |
| Classic | (other outdoor) | ~27 scattered | varies | |
| Kunark | veeshan | 13 | 7-8 | |
| Kunark | sebilis | 2 | 1 (Trakanon) | |
| Kunark | karnor | 2 | 1 (VS) | |
| Kunark | chardok | 4 | 3 (royals) | |
| Kunark | citymist | 2 | varies | |
| Kunark | charasis | 1 | 1 (Drusella) | |
| Kunark | (outdoor dragons) | 4 | 4 (Gorenaire, Severilous, Talendor, Faydedar) | |
| Velious | templeveeshan | 110 | 12-15 | |
| Velious | growthplane | 99 | ~4-6 | |
| Velious | sleeper | 80 | ~7 (6 warders + Sleeper + Master) | |
| Velious | westwastes | 40 | varies | |
| Velious | skyshrine | 6 | 6 | |
| Velious | kael | 4 | 4 (AoW, Tormax, etc.) | |
| Velious | mischiefplane | 3 | 3 | |
| Velious | necropolis | 2 | 2 | |
| Velious | (other) | ~17 scattered | varies | |
| Luclin | vexthal | 89 | ~8-12 | |
| Luclin | ssratemple | 25 | 4-6 | |
| Luclin | akheva | 8 | 3-4 | |
| Luclin | sseru | 5 | 1-2 (Seru) | |
| Luclin | griegsend | 5 | 2 | |
| Luclin | umbral | 4 | varies | |
| Luclin | (other) | ~8 scattered | varies | |

### Quest-chain dependency graph

> Populated at consolidation. Shows which quest chains share boss
> encounters (e.g. multiple epics rely on Faydedar; VT shards draw
> from many zones).

---

## Headline Findings (populated at consolidation — task #11)

> Will summarize:
> 1. Total true-boss count per era with scaling-gap size
> 2. Worst-offender encounters (biggest gap vs. target)
> 3. Progression choke-points that gate multiple chains
> 4. Phase-split recommendation for the user decision gate

---

## Recommended User Decisions (populated at consolidation — task #11)

> Will list concrete questions for the user before Phase 2 begins.
