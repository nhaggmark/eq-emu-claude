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

**Summary:** Classic raid content is small by count but includes four
distinct content groups: the two 55-cap dragons (Nagafen, Vox), the
elemental Planes (Fear, Hate, Sky), the dungeon mini-raids (Phinigel,
Zordak Ragefire, Hole), and a short tail of zone-specific raid rares.
HP values for the classic dragons and Sky/Hate gods cluster around
29k-35k — roughly 4x a scaled level-55 named (~8k HP post-prior-pass).
Cazic Thule is a dramatic outlier at 451k HP and the `a_dracoliche`
in Fear is 175k. The prior scaling pass did NOT touch boss HP, damage,
or AC, but DID increase loot probability / drop rates / spawn rate for
every boss listed below.

Elite-trash in raid zones (Plane of Fear ~91 NPCs, Plane of Hate ~28,
hateplaneb ~160+) is out of scope per the brief ("current named
difficulty feels good"). The PEQ `raid_target = 1` flag over-marks
them — they are listed here only when they are true encounter targets.

**Quest-chain cross-references:** Cleric epic requires `a_dracoliche`
in Fear. Ranger epic requires `Faydedar`. Rogue/Monk/Enchanter epics
require Plane of Sky progression and Noble Dojorn. See lore-master's
Classic quest-chain catalog below for full dependencies.

**Abbreviation key** (npcspecialattks letters):
S=Summon, E=Enrage, R=Rampage, F=Flurry, T=Triple-attack, Q=Quad,
U=UnSlowable, M=mez immune, C=charm immune, N=normal-weapon immune,
I=stun immune, D=dispel immune, f=flee-disabled.

---

### Lord Nagafen — soldungb (Nagafen's Lair)

- **NPC ID:** 32040
- **Level:** 55
- **Stats (current):** HP 32,000 / dmg 85-218 / AC 230 / MR 340 / CR 70 / FR 425
- **Special abilities:** SEQMCND (summon, enrage, quad, mez/charm/normal-weapon/disease immune); special_abilities flags include rampage (1), AE rampage (10), slow immune (13), etc.
- **Scripted behavior:** `akk-stack/server/quests/soldungb/Lord_Nagafen.pl` (Perl — legacy)
- **Adds / event mobs:** no scripted adds, but linked dragon followers in Nagafen's Lair
- **Respawn timer:** 194,400s (54h / ~2.25 days)
- **Prior-pass status:** Stats UNTOUCHED; loot probability boosted (×1.5), rare drops boosted (×1.5), respawn reduced by 25% (from 259,200 default → 194,400)
- **Gap vs. scaled-named baseline at L55:** ~3.9× HP (32k vs 8.1k), ~0.9× damage (85-218 vs 73-305 scaled named). Damage is already lower than a scaled named — only HP is the gap.
- **Recommended action:** Scale HP down 50-65% (target ~12-15k). Damage is fine. Reduce respawn further to 21,600s (6h) per brief's 6-24h target. Keep SEQMCND, consider lifting mez-immunity (M) to give enchanters a tool in small-group encounters — flag for user.
- **Notes:** Flame-themed, located deep in Nagafen's Lair past the fire-giant camps. Traditional "first raid" target for classic servers.

### Lady Vox — permafrost (Permafrost Caverns)

- **NPC ID:** 73057
- **Level:** 55
- **Stats (current):** HP 32,000 / dmg 85-218 / AC 230 / MR 340 / CR 1000 / FR 70
- **Special abilities:** SEQMCND (same flags as Nagafen)
- **Scripted behavior:** `akk-stack/server/quests/permafrost/Lady_Vox.pl` (Perl)
- **Respawn timer:** 194,400s (54h)
- **Prior-pass status:** Stats UNTOUCHED; loot/respawn same treatment as Nagafen
- **Gap vs. baseline at L55:** identical to Nagafen — ~3.9× HP, damage already low
- **Recommended action:** Same treatment as Nagafen — scale HP 50-65%, reduce respawn to 6h.
- **Notes:** Mirror of Nagafen — frost-themed. Same Classic-tier difficulty.

### Phinigel Autropos — kedge (Kedge Keep)

- **NPC ID:** 64001
- **Level:** 53
- **Stats (current):** HP 18,000 / dmg 61-156 / AC 222 / MR 100
- **Special abilities:** STMCD (summon, triple-attack, mez/charm/normal-weapon/disease immune)
- **Scripted behavior:** quest scripts in `akk-stack/server/quests/kedge/` (not yet verified)
- **Respawn timer:** unknown (requires follow-up — not in dumped data)
- **Prior-pass status:** Stats UNTOUCHED; loot/respawn boosted like other bosses
- **Gap vs. baseline at L53:** ~2.4× HP (18k vs ~7.5k scaled named at 53), damage already within named range
- **Recommended action:** Already close to target — minimal HP reduction needed (~25%). The bigger challenge is underwater combat mechanics, which is a player-side issue not a scaling one.
- **Notes:** Unique encounter (underwater, reached via Sirens Grotto drainage). Named tier rather than boss tier in effective difficulty — arguably should become a named mob.

### Cazic Thule — fearplane (Plane of Fear)

- **NPC ID:** 72003
- **Level:** 70
- **Stats (current):** HP 451,000 / dmg 223-603 / AC 504 / MR 155 / CR 100 / FR 380
- **Special abilities:** SERQUMCNIDfW (summon, enrage, rampage, quad, unslowable, mez/charm/normal/stun/dispel/flee-disabled, AE-rampage-weapon). special_abilities includes `1,10^7` = rampage 10 hits × 7 targets
- **Scripted behavior:** extensive Lua in `akk-stack/server/quests/fearplane/Cazic_Thule.lua` (likely includes Mortal Coil / summon mechanics)
- **Respawn timer:** 259,200s (72h / 3 days)
- **Prior-pass status:** Stats UNTOUCHED; loot/respawn boosted
- **Gap vs. baseline at L70:** At level 70 in Classic era this is already anomalous — Classic was capped at 50, Kunark at 60, and Luclin introduced 65. Level 70 Classic is a PEQ-era decision. Scaled-named L70 baseline is ~30k HP; Cazic is 15× that.
- **Recommended action:** Major scale-down — target 80-120k HP (3-5× scaled named at L60-65). Lift rampage 10×7 to something tractable for small groups (rampage 3×2). Preserve summon + enrage as signature mechanics. Consider dropping to level 65 since Classic era cap is not 70.
- **Notes:** End-boss of Plane of Fear. Hard walled for any small group at current stats. Requires coordinated review with lore-master (CT is lore-central).

### a_dracoliche — fearplane (Plane of Fear)

- **NPC ID:** 72090
- **Level:** 58
- **Stats (current):** HP 175,000 / dmg 177-595 / AC 516 / MR 220 / FR 175
- **Special abilities:** SFUMCND (summon, flurry, unslowable, mez/charm/normal/disease immune)
- **Scripted behavior:** `akk-stack/server/quests/fearplane/a_dracoliche.lua`
- **Respawn timer:** 194,400s (54h)
- **Prior-pass status:** Stats UNTOUCHED
- **Gap vs. baseline at L58:** ~22× HP (175k vs ~8k scaled named)
- **Recommended action:** Scale HP down to 35-50k (4-6× scaled named), keep abilities. Flurry + unslowable makes this a legitimate tank-check encounter even at reduced HP.
- **Notes:** Critical quest dependency — **Cleric Epic 1.0 step 5** requires the Soulfire quest that involves a dragon bone from this mob. Also dropped items feed Wizard Epic.

### Dread — fearplane (Plane of Fear)

- **NPC ID:** 72000
- **Level:** 55
- **Stats:** HP 32,500 / dmg 168-453 / AC 397 / MR 185 / CR 435 / FR 435
- **Special abilities:** ESMCNDTf (enrage, summon, mez/charm/normal/disease/triple immune, flee-disabled)
- **Scripted behavior:** `akk-stack/server/quests/fearplane/Dread.lua`
- **Respawn:** 194,400s (54h)
- **Prior-pass:** UNTOUCHED
- **Gap:** ~4× HP; damage is higher than scaled-named (168-453 vs 73-305 at 55)
- **Recommended:** Scale HP 30-40% down (target ~20k). Damage is already at "slightly harder than named" level — leave or trim ~10%. Respawn to 6h.
- **Notes:** One of three Plane of Fear Nightmare Knights (Dread / Terror / Fright).

### Terror — fearplane

- **NPC ID:** 72002 / **Level:** 55 / **HP:** 32,500 / **dmg:** 168-453 / **AC:** 397
- **npcspecialattks:** FSEMCNUDT (flurry + rest of Dread's set)
- **Scripted:** `akk-stack/server/quests/fearplane/Terror.lua`
- **Gap/Action:** same as Dread; additional flurry makes this the most dangerous of the three — consider trimming flurry chance via per-NPC tuning or by scaling down damage spread.

### Fright — fearplane

- **NPC ID:** 72004 / **Level:** 55 / **HP:** 32,500 / **dmg:** 168-453 / **AC:** 397
- **npcspecialattks:** SEMCNDTf
- **Scripted:** `akk-stack/server/quests/fearplane/Fright.lua`
- **Gap/Action:** same treatment as Dread/Terror.

### The Tempest Reaver — fearplane

- **NPC ID:** 72012 / **Level:** 55 / **HP:** 35,000 / **dmg:** 74-150 / **AC:** 397 / **MR:** 95
- **npcspecialattks:** UMIf (unslowable, mez immune, stun immune, flee-disabled)
- **Respawn:** 32,400s (9h) — lowest in Fear, fits brief's 6-24h already
- **Prior-pass:** UNTOUCHED
- **Gap:** ~4.4× HP but damage 74-150 is BELOW scaled named (73-305) at L55 — an outlier
- **Recommended:** HP scale 30-40%. No damage change (already low). Respawn already fits.
- **Notes:** Tagged "#" — script-spawned only. Event trigger for a Fear storm event.

### Wraith of a Shissar — fearplane

- **NPC ID:** 72001 / **Level:** 55 / **HP:** 25,000 / **dmg:** 71-295 / **AC:** 397
- **npcspecialattks:** T (triple attack only — softer than other Fear bosses)
- **Respawn:** 210,924s (~58.6h)
- **Prior-pass:** UNTOUCHED
- **Gap:** ~3× HP; damage in range of scaled-named
- **Recommended:** HP scale 30%. Respawn to 6h.
- **Notes:** Lore figure (Shissar race nod) — consult lore-master before mechanical changes.

---

### Innoruuk — hateplane (old Plane of Hate)

- **NPC ID:** 76007
- **Level:** 55
- **Stats (current):** HP 33,349 / dmg 260-379 / AC 397 / MR/CR/FR all 22 (!)
- **Special abilities:** FSREUMCND (flurry, summon, rampage, enrage, unslowable, mez/charm/normal/disease immune)
- **Scripted behavior:** presumably script-spawned at end of Hate
- **Respawn timer:** 194,400s (54h)
- **Prior-pass status:** UNTOUCHED
- **Gap vs. baseline at L55:** ~4× HP (33k vs 8k); damage 260-379 is ~3.5× scaled-named max (305) on the upper end. Very low resists (22 across MR/CR/FR) — already small-group-friendly vs. spell damage.
- **Recommended action:** HP scale 40% (target ~20k). Damage scale to 150-300 range. Reduce respawn to 6h.
- **Notes:** Titular Plane of Hate god. Two versions exist in database: id=76007 (classic Hate layout, L55 33k HP) and id=186158 in hateplaneb (revamp layout). **User decision needed: which Hate version is live on the server?** — flag for consolidation.

### Maestro of Rancor — hateplane

- **NPC ID:** 76011
- **Level:** 53 / **HP:** 16,228 (unusually low for a named raid god)
- **dmg:** 160-254 / **AC:** 383 / **MR:** 21
- **npcspecialattks:** f (flee-disabled only)
- **Prior-pass:** UNTOUCHED
- **Gap:** ~2× HP — already very close to scaled-named tier
- **Recommended:** Minimal change — consider no HP scale, or 10% cut. Arguably should be reclassified as a named rather than a boss.

### Hand of the Maestro — hateplane

- **NPC ID:** 76015 / **Level:** 51 / **HP:** 10,870 / **dmg:** 120-304 / **AC:** 369
- **Recommended:** Event mob — leave. Already in scaled-named range.

### Hate council — High Priest M`kari / Avatar of Abhorrence / Master of Spite / Mistress of Scorn / Grandmaster R`Tal

- **NPC IDs:** 76042, 76043, 76044, 76045, 76017
- **Level:** 58 / **HP:** 29,305 / **dmg:** 81-228 (except R`Tal 133-336) / **AC:** 242 or 419
- **Respawn:** 1,440s (24 min) — very short, these are mini-encounter bosses
- **Prior-pass:** UNTOUCHED
- **Gap:** ~3.5× HP; damage already in named range
- **Recommended:** HP scale 30%, respawn already acceptable. Treat as "mini-boss" tier — hardest of them (R`Tal) at slightly higher difficulty.
- **Notes:** Five-member council — each drops a distinct piece of Ghoulbane / lore item. Epic-adjacent for Paladin/SK.

### hateplaneb (Revamp Plane of Hate) — 23 boss-tier NPCs

> **This is the post-Velious revamped Hate layout.** It contains 170
> `raid_target` NPCs but only 23 are at true-boss HP (25k-35k). Counts
> by level: L55=5, L56=2, L58=3, L60=2, L63=6, L64=3, L65=6. Most are
> scripted via `akk-stack/server/quests/hateplaneb/encounters/`.
>
> **Flag for user decision:** is the server running Classic Plane of
> Hate (hateplane) or the revamp (hateplaneb)? If both are active,
> which is the intended 1-3 player target? The revamp has a richer
> encounter list but much higher trash density.
>
> Individual entries for the 23 hateplaneb bosses will be appended
> during consolidation once the Classic-vs-revamp decision is made.
> See the raw data in `claude/tmp/raid-scaling/` if needed.

---

### Plane of Sky — airplane

Plane of Sky is an 8-island progression (one boss per island, with
"key" or "quest mob" required to advance). The `raid_target = 1`
NPCs in airplane:

### The Spiroc Lord — airplane (Island 8 / final)

- **NPC ID:** 71012 / **Level:** 63 / **HP:** 32,000 / **dmg:** 135-363 / **AC:** 345 / **MR:** 435
- **npcspecialattks:** SERFT (summon, enrage, rampage, flurry, triple-attack)
- **Respawn:** 10,800s (3h) — already short
- **Scripted:** `akk-stack/server/quests/airplane/The_Spiroc_Lord.lua`
- **Gap:** ~3× HP over scaled-named at L60; damage in named range
- **Recommended:** HP scale 30% (target ~22k). Respawn already acceptable.
- **Notes:** Final Sky island boss. Rampage + flurry makes for real add-management challenge — keep abilities, trim HP only.

### Noble Dojorn — airplane (quest mob, unique — Rogue / Monk epic)

- **NPC ID:** 71057 / **Level:** 60 / **HP:** 32,000 / **dmg:** 98-326 / **AC:** 345 / **MR:** 430
- **npcspecialattks:** S (summon only)
- **Respawn:** 194,400s (54h) — very long, quest-gating
- **Scripted:** `akk-stack/server/quests/airplane/Noble_Dojorn.lua`
- **Prior-pass:** UNTOUCHED (stats); respawn reduced 25%
- **Gap:** ~3× HP
- **Recommended:** HP scale 30% (target ~22k). Respawn to 6h — currently the long timer gates any repeated attempts.
- **Notes:** **Quest critical** — Rogue Epic 1.0 (Ragebringer) requires items from Sky Island 8. Monk Epic requires Ton Po / Noble Dojorn chain. Lore-master confirm scope.

### Gorgalosk — airplane (island 7)

- **NPC ID:** 71021 / **Level:** 60 / **HP:** 29,000 / **dmg:** 107-392 / **AC:** 345 / **MR:** 500
- **npcspecialattks:** EF (enrage + flurry)
- **Respawn:** 10,830s (3h)
- **Gap:** ~3× HP; damage upper bound (392) above scaled named
- **Recommended:** HP scale 30%, damage trim 15%.

### Eye of Veeshan — airplane (island 8 sub-boss)

- **NPC ID:** 71065 / **Level:** 70 / **HP:** 32,000 / **dmg:** 87-201 / **AC:** 345 / **MR:** 475
- **npcspecialattks:** S (summon)
- **Respawn:** 21,600s (6h)
- **Gap:** damage below scaled-named, HP ~5× named at L60 but mob is L70
- **Recommended:** Minimal change — already feels like a mini-boss. Consider HP cut 20%. Flag level 70 as over-era (Sky is Classic era; L70 here is PEQ content creep).

### a thunder spirit princess — airplane (island 5)

- **NPC ID:** 71032 / **Level:** 53 / **HP:** 20,000 / **dmg:** 86-276
- **Respawn:** 10,800s (3h)
- **Gap:** ~2.4× HP
- **Recommended:** Already close to named tier — minimal change (10-15% HP cut).

**Sky summary note:** The 8-island progression itself is a major small-
group blocker — each island has a "key drop" from a group-level mob
to access the next island, and there are island time-out mechanics
where failing to kill within a window boots you back. These are
PROGRESSION issues rather than boss-stat issues. Lore-master's Classic
quest chain catalog will cover the island-chain progression in detail.

---

### Outdoor / miscellaneous Classic raid bosses

### Zordak Ragefire — soldungb (old classic)

- **NPC ID:** 32038 / **Level:** 60 / **HP:** 9,500 / **dmg:** 92-213
- **Respawn:** unknown
- **Gap:** HP is BELOW scaled-named at L60 (16,200) — this is either a bug/stub or an intentional "group-level raid mob"
- **Recommended:** If active on server, this is trivial for small group already. Likely superseded by id=91090 (Zordakalicus_Ragefire) in skyfire/skyfire raid event. Flag for investigation — one of the two IDs may be the legacy classic entry and obsolete.
- **Notes:** Originally the gnome-targeted event dragon. Lore-master to confirm era canonical form.

### Zordakalicus Ragefire — skyfire / event

- **NPC ID:** 91090 / **Level:** 60 / **HP:** 33,000 / **dmg:** 106-315 / **AC:** 254 / **MR:** 230
- **npcspecialattks:** SRQMCNIDf
- **Gap:** ~2× HP, damage in named range
- **Recommended:** Minimal HP cut (15-25%). Technically a Kunark-zone encounter but lore-attached to Classic Soldunga event.

### Phantasmal Overlord / #a_Thul_Tae_Ew_High_Priest — cazicthule (Lost Temple)

- **NPC ID:** 48041 / **Level:** 60 / **HP:** 50,000 / **dmg:** 89-241 / **AC:** 250
- **Respawn:** 194,400s (54h)
- **Gap:** ~6× HP, damage in named range
- **Recommended:** HP scale 50% (target ~25k). Respawn to 6-12h.
- **Notes:** Guards inner Cazic-Thule temple. Quest target for Cazic Quarter access.

### Guardian of the Seal — hole

- **NPC ID:** 39115 / **Level:** 70 / **HP:** 124,000 / **dmg:** 300-900 / **AC:** 504
- **npcspecialattks:** SERTQMCNDf
- **Respawn:** 156,240s (~43.4h)
- **Gap:** Level 70 in Classic zone (The Hole is Classic-era but post-cataclysm). ~4× scaled-named HP at L70
- **Recommended:** HP scale 30%. Respawn to 12h.
- **Notes:** "The Hole" is post-cataclysm Erudin ruins. Requires Warrens key to access. Quest target for some Erudin content.

### Fuzz Selppa — tox

- **NPC ID:** 38171 / **Level:** 50 / **HP:** 200,000 / **dmg:** 80-604
- **Respawn:** 900s (15 min) — very short
- **Gap:** ~30× HP over scaled-named at L50 (6k)
- **Recommended:** Likely an event / anniversary mob. Investigate before scaling — possibly out-of-era. Flag for user review.

### Haele Straedhon — sro

- **NPC ID:** 35063 / **Level:** 65 / **HP:** 502,500 / **dmg:** 959-4,253
- **Respawn:** 900s
- **Gap:** Enormous — damage max 4,253 is a one-shot for any small group
- **Recommended:** **OUT OF ERA / event content** — this is a Bloodmoon or Hate revamp event trigger. Do not scale without confirming era legitimacy.

### Taskmaster Mirot — lfaydark

- **NPC ID:** 57150 / **Level:** 65 / **HP:** 300,000 / **dmg:** 193-496
- **Respawn:** 5,400s (1.5h)
- **Gap:** Level 65 boss in classic Lesser Faydark — likely a post-Velious revamp add
- **Recommended:** Investigate era legitimacy. If in-era, scale HP 70-80%.

### Sasha the Seer — commons

- **NPC ID:** 21162 / **Level:** 80 / **HP:** 500,000 / **dmg:** 960-1,204
- **OUT OF ERA** — level 80 is post-Luclin. Expansion lock should prevent. No action.

### Legendary Behemoth / Legendary Hill Giant — steamfont / commons

- **NPC IDs:** 56182 (L72 400k HP), 21163 (L72 230k HP)
- **OUT OF ERA** — post-Luclin Legends-of-Norrath anniversary content. No action.

### Kithicor Halloween-event NPCs — kithicor

- **NPC IDs:** 20259 (##Eve_Hallows), 20260 (##Jack_Lanturn), 20263 (##Tricksy_Treetor), 20279 (Old_Man_Draykey), 20285 (Crazy_Charlie), 19151 (Laryen_Lycanthrope rivervale)
- **All level 70, HP 800k-10M** — Halloween / seasonal event content
- **Recommended:** Out of scope for raid scaling — they appear only during event windows.

### Kithicor "Night Crew" bosses — kithicor

- **NPC IDs:** 20054 Coercer_Q`ioul, 20055 Advisor_C`zatl, 20061 Brigadier_G`tav, 20062 Ioltos_V`ghera, 20063 Tasi_V`ghera, 20064 War_Priestess_T`zan
- **Levels:** 54-59 / **HP:** 12-27k / **dmg:** 58-181
- **Gap:** 1.5-3× scaled-named tier; close to named difficulty
- **Recommended:** These are the undead Heart of Kithicor encounter bosses. Close to named-tier already — minimal action needed (10-20% HP cut). Possibly reclassify as named rather than raid.

### GM / testing dummies

- `arena` training dummies (ids 77002, 77003), `cshome` hundred/thousand HP-labeled mobs (ids 26032-26043) — **ignore** (GM testing rigs, 900M+ HP).

---

### Classic boss catalog — summary table

| Boss | Zone | ID | L | HP | dmg | Prior-pass | Recommended HP cut | Respawn target |
|------|------|----|----|-----|-----|------------|-------------------|----------------|
| Lord Nagafen | soldungb | 32040 | 55 | 32,000 | 85-218 | UNTOUCHED | 50-65% (→12-15k) | 6h |
| Lady Vox | permafrost | 73057 | 55 | 32,000 | 85-218 | UNTOUCHED | 50-65% | 6h |
| Phinigel Autropos | kedge | 64001 | 53 | 18,000 | 61-156 | UNTOUCHED | 25% | 6h |
| Cazic Thule | fearplane | 72003 | 70 | 451,000 | 223-603 | UNTOUCHED | 75-80% (→80-120k) | 12h |
| a_dracoliche | fearplane | 72090 | 58 | 175,000 | 177-595 | UNTOUCHED | 70-80% (→35-50k) | 6h |
| Dread / Terror / Fright | fearplane | 72000/72002/72004 | 55 | 32,500 | 168-453 | UNTOUCHED | 30-40% (→20k) | 6h |
| The Tempest Reaver | fearplane | 72012 | 55 | 35,000 | 74-150 | UNTOUCHED | 30-40% | already 9h |
| Wraith of a Shissar | fearplane | 72001 | 55 | 25,000 | 71-295 | UNTOUCHED | 30% | 6h |
| Innoruuk (hateplane) | hateplane | 76007 | 55 | 33,349 | 260-379 | UNTOUCHED | 40% (→20k) + dmg trim | 6h |
| Maestro of Rancor | hateplane | 76011 | 53 | 16,228 | 160-254 | UNTOUCHED | 10% or none | 6h |
| Hand of the Maestro | hateplane | 76015 | 51 | 10,870 | 120-304 | UNTOUCHED | none | 6h |
| Hate Council (×5) | hateplane | 76017/42/43/44/45 | 58 | 29,305 | 81-228 | UNTOUCHED | 30% | already 24min (keep) |
| hateplaneb revamp bosses | hateplaneb | 23 IDs | 55-65 | 25-35k | varies | UNTOUCHED | TBD pending user decision | TBD |
| The Spiroc Lord | airplane | 71012 | 63 | 32,000 | 135-363 | UNTOUCHED | 30% | already 3h |
| Noble Dojorn | airplane | 71057 | 60 | 32,000 | 98-326 | UNTOUCHED | 30% | 6h |
| Gorgalosk | airplane | 71021 | 60 | 29,000 | 107-392 | UNTOUCHED | 30% + dmg trim 15% | already 3h |
| Eye of Veeshan | airplane | 71065 | 70 | 32,000 | 87-201 | UNTOUCHED | 20% | already 6h |
| a thunder spirit princess | airplane | 71032 | 53 | 20,000 | 86-276 | UNTOUCHED | 10-15% | 3h |
| Zordakalicus Ragefire | skyfire | 91090 | 60 | 33,000 | 106-315 | UNTOUCHED | 15-25% | TBD |
| a_Thul_Tae_Ew_High_Priest | cazicthule | 48041 | 60 | 50,000 | 89-241 | UNTOUCHED | 50% | 6-12h |
| Guardian of the Seal | hole | 39115 | 70 | 124,000 | 300-900 | UNTOUCHED | 30% | 12h |

**Classic true-boss count (in-era, excluding Halloween/event/GM/legendary):** ~30 encounters. hateplaneb adds 23 more IF the revamp is the active version.

**Classic scaling-gap summary:** The core Classic raid (Nagafen, Vox, Sky, Fear, Hate) was designed around 32k HP / ~200-400 damage — only ~4x a scaled named. The gap is manageable: most entries need a 30-50% HP cut and a respawn reduction. Two outliers (Cazic Thule at 451k, Dracoliche at 175k) need deeper cuts. Damage values are broadly already in line with named-tier — the primary lever is HP, not damage.

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
