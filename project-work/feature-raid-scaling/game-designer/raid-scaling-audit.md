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

> **Status:** Lore-master's canonical catalog delivered 2026-04-22. See
> full per-class walkthrough at
> `/mnt/d/Dev/eq/claude/project-work/feature-raid-scaling/lore-master/epics.md`.
> This section is a SUMMARY of lore-master's findings plus
> project-critical blockers for the architect. The game-designer's
> original fallback entries (beneath this summary) are preserved as
> scaffolding but SUPERSEDED where they conflict with lore-master's
> canonical sources.

#### Key project-critical findings from lore-master review

**Pain score distribution (14 epics + Plane of Sky):**
- **RED (structural small-group blocker):** Bard, Cleric, Druid,
  Magician, Ranger, Rogue, Shadow Knight, Warrior, Wizard (9 of 14)
- **YELLOW (hard but doable):** Enchanter, Monk, Necromancer, Paladin
  (4 of 14)
- **GREEN (small-group friendly):** Shaman (1 of 14)
- **Plane of Sky:** Islands 1-3 GREEN, Island 4 YELLOW/RED, Islands
  5-8 RED (death touch mechanics throughout)

**Newly identified blockers NOT captured in the game-designer fallback
or in the boss catalog — these require architect attention:**

1. **Plane of Sky Islands 4-8 use DEATH TOUCH mechanics** — Keeper of
   Souls (Island 4) death touches every 30s. Spiroc Lord (Island 5)
   and Queen Bee (Island 6) also death touch. **This is a mechanic
   the boss catalog did not surface.** Death touch in vanilla EQ is
   instant-kill regardless of HP/AC — scaling HP alone does not fix
   these encounters. **Critical architect question:** can the server
   modify death touch to be a very high but survivable hit (e.g.
   convert to damage shield / percentage-based damage), or does the
   project accept that PoSky Islands 4-8 remain unreachable for
   small groups without a mechanic rewrite?

2. **Enraged Golem in Plane of Fear (Wizard Epic): level 65, 150K+ HP**
   — this was NOT in the boss-catalog because it is spawned from
   an interaction with a "broken golem" (rare spawn, 8hr respawn)
   and not in the spawnentry table. **Boss catalog should be
   amended to include this.** Wizard epic is unreachable without it.

3. **Triggered Trakanon in Old Sebilis (Bard Epic):** spawned by
   giving items to "an Undead Bard". Scripted private spawn that
   hits like Trakanon. Boss catalog covered Sebilis-Trakanon
   (id 89154) but did NOT capture this triggered-spawn variant.

4. **Vilnius the Small (W. Karana, Rogue Epic):** nighttime-only
   ultra-rare spawn via specific PH chain (kill brigands → "a brigand"
   PH spawns → leave alive → 11pm game-time Vilnius appears in its
   place). Described as "game-stopping bottleneck." Not a raid boss
   — a QUEST BLOCKER. Scaling changes can't fix rare-spawn mechanics;
   architect may need to consider a spawn-rate tweak for small-group
   accessibility.

5. **Class-specific skill requirements that block 1-player servers:**
   - **Rogue pickpocket** (Founy Jestands N.Kaladim, Tani N'Mar
     Neriak): Rogue epic literally cannot start without a Rogue
     character present. 1-player server with non-Rogue main is
     blocked. Companions cannot pickpocket.
   - **Enchanter charm** (3rd Piece of Staff, multiple gem turn-ins
     via charmed NPCs): Enchanter epic 3rd piece is class-gated.
   - **Druid/Ranger "Firefly Globe"** (Dance of Fireflies, night-only):
     required for Venril Sathir remains-to-spirit transition. If
     your party lacks a Druid or Ranger, the Druid/Ranger epic
     stalls at step 10 for 20 hours + a night cycle.
   **Flag for user:** Should 1-player servers have class-gated epic
   steps unblocked (e.g. merchant-buyable items, companion-triggered
   interactions), or is this accepted as "you can't do every class's
   epic on one character"?

6. **Shaman epic is unexpectedly GREEN** — only green epic. The
   linear Truespirit faction is tedious but not blocking. Good
   showcase quest for early Phase 2 testing.

7. **Ranger/Druid epics share ~15 steps.** Cleansed Spirit of
   Antonica/Faydwer/Kunark chain is identical. Scaling work for
   one benefits the other. Architect implementation efficiency
   opportunity.

8. **Linear faction mechanics:** Shaman (Truespirit) AND Shadow
   Knight (Truespirit from different starting point) both require
   LINEAR faction progression with no shortcuts. Miss a step and
   you may need troubleshooting. This is quest-script behavior,
   not scaling — architect to note.

9. **Plane of Hate is a shared requirement for 7 of 14 epics:**
   Bard (Shattered Emerald), Enchanter (Forsaken Revenant),
   Magician (Magi P'Tasa), Paladin (Thought Destroyer), Ranger
   (Shattered Emerald / Master of Spite), Rogue (Book of Souls
   ground spawn), Shadow Knight (ashenbone drake decrepit hide).
   **PoHate layout decision (user decision C: classic hateplane vs
   revamp hateplaneb) affects 7 epics simultaneously.** Whichever
   layout is live needs verified drop sources for these items.

10. **Plane of Fear is a shared requirement for 6 of 14 epics:**
    Bard (Amygdalan Tendril), Cleric (dracoliche), Enchanter
    (Wraith of Shissar), Necromancer (Slime Blood of Cazic-Thule),
    Shadow Knight (Soul Leech from Cazic/Dread/Fright/Terror),
    Shaman (Iksar broodling), Warrior (Ball of Everliving Golem —
    2-3 DAY respawn, uncommon drop), Wizard (Enraged Golem 150k HP).

**Cross-epic shared raid-boss dependencies (high-leverage scaling
targets):**

| Boss | Epic count | Scaling priority |
|------|-----------|------------------|
| Phinigel Autropos (Kedge) | 4 (Bard, Magician, Rogue, Wizard) | HIGH — 12hr respawn + uncommon drops = multi-session farming per epic |
| Lhranc (City of Mist) | 2 (Paladin, Shadow Knight) | MEDIUM — shared final boss with 32k HP, 500 lifetap |
| Plane of Fear god tier (Dread/Fright/Terror/Cazic-Thule) | 3 (Necromancer, Shadow Knight, Warrior) | HIGH — Ball of Everliving Golem is the worst drop rate + respawn combo |
| Plane of Sky Island 4 (Keeper of Souls) | 2 (Necromancer Cape, Ranger essence tamer) | CRITICAL — death touch, blocks Islands 5-8 too |
| Plane of Sky Island 5 (Spiroc Lord) | 1 (Warrior Spiroc Wingblade) | CRITICAL — death touch |
| Venril Sathir | 3 (Druid + Ranger triggered form, Wizard standard form) | HIGH — 20hr wait mechanic + rare drop |
| Overking Bathezid (Chardok) | 1 (Cleric) | HIGH — lvl 63 ~2-group, blocks entire Cleric epic |
| Ixiblat Fer (Burning Woods) | 1 (Cleric) | HIGH — lvl 62 32k HP 575/hit, blocks entire Cleric epic |

**Raid encounter ID additions for boss catalog:**
The boss catalog covered most of these but several spawned/triggered
encounters from lore-master's catalog are not in `raid_target = 1`
and should be reviewed for scaling independently:
- **Enraged Golem (Plane of Fear, Wizard epic):** lvl 65, 150k HP —
  NOT in boss catalog, needs identification + scaling
- **Triggered Trakanon (Old Sebilis, Bard epic):** private spawn,
  separate from id 89154
- **Xenevorash (Lake of Ill Omen, Monk epic):** 32k HP, 500/hit,
  12s PBAE stun — NOT in boss catalog, needs identification
- **Renux Herkanor (Steamfont, Rogue epic):** spawned encounter
- **General V'ghera (Kithicor, Rogue epic):** cabin-assist 500+/hit
- **Thrackin Griften (W. Karana, Enchanter epic):** spawned 20k HP
- **Vessel Drozlin (East Cabilis sewers, Enchanter):** lvl 60 18k HP
- **Caradon + Kyrenna (The Hole, Shadow Knight):** 8hr+ respawn
- **Mummy of Glohnor (The Hole, Shadow Knight):** lvl 56
- **Tortured Soul (Lake Rathetear, Necromancer):** triggered

**Action for architect:** Query the database for these specific
named NPCs and cross-reference against the boss catalog. Several
have scaling gaps comparable to catalog-covered bosses and
require the same treatment.

---

#### Full per-class walkthrough

For complete per-step walkthroughs, raid-encounter lists, non-
encounter blockers, cross-chain gating, and pain scoring, see the
lore-master's canonical document at
`lore-master/epics.md`.

---

#### (Preserved: Game-designer's original fallback summary, now superseded by lore-master catalog above)

> The following entries were the game-designer's first-pass fallback
> summaries from public-domain EQ knowledge before lore-master's
> canonical catalog arrived. They are preserved for historical
> continuity but **the lore-master document supersedes them** where
> conflicts exist. The architect should primarily reference the
> findings block above and the `lore-master/epics.md` file.

**Scope:** The "Classic-phase" steps of all 14 class Epic 1.0 quests
(many epics span all 4 eras — this subsection lists the
Classic-phase-only steps), plus Plane of Sky island progression,
plus Cazic-Thule access (Lost Temple) as a Classic-specific
raid-access chain.

---

#### Plane of Sky — key + 8-island progression

- **Class/scope:** General raid access; prerequisite for Rogue Epic
  (Ragebringer), Monk Epic (Celestial Fists), Enchanter Epic
  (Staff of the Serpent), Warrior Epic (Jagged Blade of War) end
  steps, and multiple class-specific ground-spawn/quest items.
- **Era:** Classic
- **Zones:** Plane of Sky (`airplane`) — accessed from Plane of Fear
  or Plane of Hate (via Alternate Planes portal)
- **Turn-in NPCs:** Key Master (airplane)
- **Raid encounters required:**
  - Island-by-island progression; each island has a "key drop" from
    a raid mob required to access the next
  - Island 1: Spiroc banishers (trash)
  - Island 2: Noble Dojorn (boss) — **key for 3**
  - Island 3: a_thunder_spirit_princess — **key for 4**
  - Island 4-7: mid-tier island bosses (Overseer of Air etc.)
  - Island 7: Gorgalosk (boss)
  - Island 8: Eye of Veeshan + **The Spiroc Lord** (final)
- **Non-encounter blockers:** Island 8 has a traditional "event
  timeout" — failing to kill within a window resets progress
- **Small-group blockers:** Island 8's patrolling Spiroc guardians
  make focused fights difficult; island timing mechanic can
  soft-lock a small group
- **Recommended action:** Boss stats scaled per audit boss-catalog.
  Verify no island-timer mechanic prevents small-group pace —
  architect to check quest script `airplane/`. If timer exists and
  is tight, recommend extending for small groups.
- **Lore continuity:** Lore-master to confirm — Plane of Sky is
  Veeshan's dragon-aligned plane, post-death dragons ascend here.

#### Plane of Fear — Cazic Thule access

- **Class/scope:** General raid access; Cleric Epic (Soulfire) step
  5 requires `a_dracoliche` kill and bone component
- **Era:** Classic
- **Zones:** Plane of Fear (`fearplane`)
- **Turn-in NPCs:** n/a for access; the zone is level-gated only
- **Raid encounters required:**
  - Cazic Thule (end boss, requires traversing through Dread/
    Fright/Terror and the Dracoliche)
- **Non-encounter blockers:** Plane of Fear trash (shiverbacks,
  scarelings, amygdalans) was handled by prior pass
- **Small-group blockers:** Cazic Thule's rampage 10×7 is impossible
  without audit-recommended trim. Dracoliche's flurry+unslowable
  requires tanking strategy — audit recommends stat cut but
  preserves mechanics.
- **Recommended action:** Addressed by boss-catalog scaling.

#### Plane of Hate — Council + Innoruuk

- **Class/scope:** General raid access; Necromancer Epic
  (Scythe of the Shadowed Soul) steps require Hate drops; SK Epic
  (Innoruuk's Curse) requires multiple Hate components.
- **Era:** Classic
- **Zones:** Plane of Hate (classic `hateplane` OR revamped
  `hateplaneb` — user decision pending)
- **Raid encounters required (classic layout):**
  - Hate council (5 mini-bosses): High Priest M`kari, Avatar of
    Abhorrence, Master of Spite, Mistress of Scorn, Grandmaster
    R`Tal
  - Maestro of Rancor + Hand of the Maestro (upper tier)
  - Innoruuk (end boss)
- **Small-group blockers:** Innoruuk's flurry+rampage+enrage at
  current stats. Maestro already near-named-tier.
- **Recommended action:** Boss-catalog scaling covers stats. User
  decision on classic vs revamp Hate.

#### Cazic-Thule (Lost Temple) — Thul Tae Ew High Priest

- **Class/scope:** Inner-temple access for Cazic Quarter;
  prerequisite for some Shadowknight and Cleric quest lines
- **Era:** Classic
- **Zones:** Cazic Thule (`cazicthule`), deep temple
- **Raid encounters:** Thul Tae Ew High Priest (50k HP, L60,
  inner sanctum)
- **Small-group blockers:** Deep-zone pathing with many Thul
  Tae Ew spawns; current audit-recommended 50% HP cut makes
  the Priest himself tractable.

---

#### Class Epic 1.0 — Classic-phase steps

Most Epic 1.0s span Classic + Kunark (some also Velious). The
Classic-phase steps typically involve ground spawns, drops from
Classic named, and (for some classes) a raid-tier kill. Listed
alphabetically:

**Bard Epic 1.0 — Singing Steel Breastplate → Singing Short Sword of the Ykesha**
- Classic steps involve dropped instrument pieces (Classic dungeons)
- No Classic raid-tier kill required
- Raid steps start in Kunark

**Cleric Epic 1.0 — Water Sprinkler of Nem Ankh (Soulfire)**
- Classic raid step: **Water Sprinkler of Nem Ankh** path requires
  **a_dracoliche** bone drop (Plane of Fear)
- Also requires a ghoul hero drop and multiple specific items
- Cross-references boss-catalog: a_dracoliche (fearplane, 72090)

**Druid Epic 1.0 — Nature Walker's Scimitar** _(corrected 2026-04-22 per lore-master review)_
- Classic raid step: **none** — Phinigel Autropos is NOT required
  for Druid epic (earlier audit draft had this as "lore-master
  confirm" — lore-master has now confirmed it's unnecessary)
- Kunark raid step: **Faydedar** (Timorous Deep) — primary raid
  dependency
- Cross-references: Faydedar (timorous, 96089)

**Enchanter Epic 1.0 — Staff of the Serpent**
- Classic raid step: Plane of Sky island 8 (Noble Dojorn) drop
  required (Serpent's Spine)
- Kunark raid step: pieces from multiple Kunark dragons
- Cross-references: Noble Dojorn (airplane, 71057)

**Magician Epic 1.0 — Orb of Mastery**
- Classic step: Plane of Air / various dragons for elemental
  components
- Heavily Kunark-centric; Faydedar and outdoor dragons required
- No Classic-specific raid kill — most Classic-phase is
  instance/quest NPCs

**Monk Epic 1.0 — Celestial Fists**
- Classic raid step: Plane of Sky / Ton Po quest chain
- Often Noble Dojorn + Ton Po (Sky or Skyfire) drops
- Cross-references: Noble Dojorn (airplane, 71057), Ton Po (airplane)

**Necromancer Epic 1.0 — Scythe of the Shadowed Soul**
- Classic raid step: Plane of Hate drops (Innoruuk, Master of
  Spite component)
- Kunark raid step: Venril Sathir kill (Karnor's)
- Cross-references: Innoruuk (hateplane, 76007), Venril Sathir
  (karnor, 102112)

**Paladin Epic 1.0 — Soulfire / Fiery Avenger**
- Classic raid step: none specifically — but Hate Council drops
  may be required for some steps
- Lore-master to verify — possibly requires Mistress of Scorn
  drop

**Ranger Epic 1.0 — Earthcaller**
- Classic steps: ground spawns in outdoor Classic zones
- Kunark raid step: **Faydedar** (primary requirement, Timorous Deep)
- Cross-references: Faydedar (timorous, 96089)

**Rogue Epic 1.0 — Ragebringer**
- Classic raid step: **Plane of Sky island 8 drops** (Noble Dojorn,
  Overseer of Air)
- Kunark raid step: Chardok royals + outdoor dragons
- Cross-references: Noble Dojorn (airplane), Overking Bathezid
  (chardok, 103056)

**Shadow Knight Epic 1.0 — Innoruuk's Curse**
- Classic raid step: **Hate multi-kill** (Innoruuk + council)
- Kunark raid step: Venril Sathir, Chardok
- Cross-references: Innoruuk (hateplane, 76007), VS (karnor, 102112)

**Shaman Epic 1.0 — Spear of Fate**
- Classic step: ground spawns
- Kunark raid step: Faydedar + outdoor dragons
- Cross-references: Faydedar (timorous, 96089)

**Warrior Epic 1.0 — Jagged Blade of War** _(corrected 2026-04-22 per lore-master review)_
- Classic raid step: **Spiroc Lord** (Plane of Sky, Island 5) for Spiroc Wingblade drop + **Hand of the Maestro** (Plane of Hate) for component
- Kunark raid step: **Queen Velazul Di\`Zok** (Chardok) for Ancient Blade; plus Green Dragon Scales (Severilous or Hoshkar) + Red Dragon Scales (Nagafen or Talendor or Echo of Nortlav)
- Velious raid step: **NONE** — Warrior epic completes in Classic + Kunark
- Cross-references: Spiroc Lord (airplane, 71012), Queen Velazul (chardok, 103055), Severilous (emeraldjungle, 94009), Talendor (skyfire, 91093)

**Wizard Epic 1.0 — Staff of the Four**
- Classic raid step: possibly a Dracoliche drop component
- Kunark raid step: Chardok royals + Phase Spider Queen
- Cross-references: Dracoliche (fearplane, 72090)

---

#### Classic quest chain summary

- **~14 class epics** all involve Classic-era components; most
  have NO Classic raid step (they start raid-tier in Kunark).
  The Classic raid-kill requirements are concentrated on:
  **Plane of Sky + Plane of Hate + Plane of Fear.**
- **Plane of Sky is the densest quest-dependency node in Classic**
  — Rogue, Monk, Enchanter, and partial Wizard epics all pull
  from Sky. Island 8 bosses (Noble Dojorn, Overseer, Spiroc Lord)
  are the critical bottleneck.
- **Plane of Fear** (for Cleric epic dracoliche step) is a
  straightforward walk-in raid — audit boss-catalog scaling
  makes it tractable.
- **Plane of Hate** (for Necro + SK epics) depends on
  user decision between classic layout and revamp layout.
- **Cazic-Thule (Lost Temple) inner sanctum** is a minor
  access point — not a hard quest-chain dependency.

**Classic quest-chain blockers for small group (once boss scaling is applied):**
- Plane of Sky island-timer mechanics (if any remain) need
  verification for small-group viability
- Noble Dojorn's 54h respawn needs audit's reduction to 6h to
  allow multi-attempt practice for Rogue/Monk/Enchanter epic
  chains
- No hard quest blockers expected post-scaling — Classic is the
  era where companion-system + stat-scaling alone should unblock
  all raid quest steps

---

## Kunark (expansion 1)

### Kunark raid boss catalog

**Summary:** Kunark adds 14 true-boss encounters in in-era content:
four outdoor dragons (Gorenaire, Severilous, Talendor, Faydedar), three
end-dungeon bosses (Trakanon, Venril Sathir, Drusella Sathir), three
Chardok royals (Overking Bathezid, Queen Velazul, Prince Selrach), two
City of Mist encounters (Kilidna, Lhranc), and **seven Veeshan's Peak
dragons** (Druushk, Hoshkar, Nexona, Phara Dar, Silverwing, Xygoz,
Guardian of Veeshan).

**Two tiers of stats co-exist in Veeshan's Peak.** For each of the six
VP dragons (not GoV) there are two NPC IDs: a "classic-era" variant at
level 65-67 with 144-192k HP, and a "revamp" variant at level 70 with
454-814k HP. **Quest scripts reference the level-70 revamp variants**
(`akk-stack/server/quests/veeshan/108040.pl` through `108053.pl`) —
confirming the revamp IDs are the active content on this server.
**User decision needed:** swap VP encounters to the classic-era variants
(lower HP, era-appropriate) OR scale the revamp variants down? The
classic variants are still 4-6× a scaled named so they need scaling
too, but starting from 150k is more tractable than 600k.

**Damage outliers:** Kilidna (citymist) has max damage 4,600 — a one-shot
for any small-group tank at current tuning. VP revamp dragons hit
1,295-2,475 max — also one-shots. These are the highest priority
damage trims even more than HP.

**Scaling gap overview:** The outdoor dragons (Gorenaire, Severilous,
Talendor, Faydedar) and Chardok royals are at 22-34k HP (similar to
Classic dragons) — close to target, need ~30-40% HP cut. VP dragons
(revamp variant) and Kilidna are massively over-tuned for small group
at current stats — need 80%+ HP cut plus aggressive damage trimming.

**Quest-chain cross-references:** Kunark is the heaviest epic-content
era. Faydedar, Trakanon, Venril Sathir, the Chardok royals, and
multiple VP dragons are required for Epic 1.0 chains across 8+
classes. See lore-master's Kunark quest-chain catalog.

---

### Gorenaire — dreadlands

- **NPC ID:** 86014
- **Level:** 60
- **Stats:** HP 32,000 / dmg 139-500 / AC 254 / MR 350
- **npcspecialattks:** SETMCNIDf (summon, enrage, triple, mez/charm/normal/stun/dispel-immune, flee-disabled)
- **Respawn:** 194,400s (54h)
- **Prior-pass:** UNTOUCHED (stats); loot and respawn boosted
- **Gap vs. L60 scaled-named (HP 16.2k):** ~2× HP; damage max 500 is 15% above scaled-named
- **Recommended action:** HP cut 30% (→22k). Damage max trim 20% (→400). Respawn to 6h.
- **Notes:** Outdoor cold dragon — shared epic node (Druid, Shaman, Magician). Low-add environment already, mostly a solo-dragon encounter at current mechanics.

### Severilous — emeraldjungle

- **NPC ID:** 94009
- **Level:** 60 / **HP:** 32,000 / **dmg:** 139-500 / **AC:** 254 / **MR:** 325
- **npcspecialattks:** SEMCNDf
- **Respawn:** 194,400s (54h)
- **Gap:** identical to Gorenaire
- **Recommended:** Same as Gorenaire — HP -30%, damage trim, respawn to 6h.
- **Notes:** Outdoor disease dragon — shared epic node.

### Talendor — skyfire

- **NPC ID:** 91093
- **Level:** 60 / **HP:** 32,000 / **dmg:** 139-500 / **AC:** 254 / **MR:** 455
- **npcspecialattks:** SETMCNIDf
- **Respawn:** 194,400s (54h)
- **Gap:** identical to Gorenaire/Severilous
- **Recommended:** Same as Gorenaire.
- **Notes:** Outdoor fire dragon. High MR (455) is specifically a wall against magic-dps small groups — lore-master to confirm if lowering MR to ~300 violates era flavor.

### Faydedar — timorous

- **NPC ID:** 96089
- **Level:** 55 / **HP:** 32,000 / **dmg:** 103-236 / **AC:** 234 / **MR:** 425
- **npcspecialattks:** SERMCNIDf
- **Respawn:** 194,400s (54h)
- **Prior-pass:** UNTOUCHED (stats)
- **Gap:** ~4× HP scaled-named at L55 (8.1k); damage in named range
- **Recommended:** HP cut 40% (→19k). Damage unchanged. MR trim to ~300. Respawn to 6h.
- **Notes:** **CRITICAL quest node** — Ranger Epic 1.0 + multiple other class epics require Faydedar kill. Lore-master to list all dependent chains. Also 2nd variant `#Faydedar` id=96073 exists (32k HP L55 — likely a script-spawned quest-step copy).

### Trakanon — sebilis

- **NPC ID:** 89154
- **Level:** 65
- **Stats:** HP 32,000 / dmg 144-630 / AC 315 / MR 340
- **npcspecialattks:** SERFMCNDf (summon, enrage, rampage, flurry, mez/charm/normal/disease-immune, flee-disabled)
- **Respawn:** 194,400s (54h)
- **Prior-pass:** UNTOUCHED
- **Gap at L65 (scaled-named ~22k):** ~1.5× HP; damage max 630 above named (711 scaled) — damage is fine
- **Recommended action:** HP cut 30% (→22k). Rampage+flurry both active = risky for small group — consider reducing flurry chance via special_abilities. Respawn to 6h.
- **Notes:** Sebilis deep-zone boss. Disease debuff mechanic ("Trakanon's Touch") should be preserved — makes him a prep fight. Quest node for Cleric Epic (Soulfire), Warrior Epic, and others.

### Venril Sathir — karnor

- **NPC ID:** 102112 (`#Venril_Sathir` — script-spawned)
- **Level:** 55 / **HP:** 22,000 / **dmg:** 180-404 / **AC:** 234 / **MR:** 360
- **npcspecialattks:** SRMCNIDf (summon, rampage, mez/charm/normal/stun/dispel, flee-disabled)
- **Respawn:** 194,400s (where spawnentry exists — but VS is triggered)
- **Gap at L55:** ~2.7× HP over scaled-named; damage max 404 above named (305) — mild over
- **Recommended:** HP cut 25% (→16.5k). Damage max trim 10%. Keep rampage — signature.
- **Notes:** **CRITICAL quest node** — Karnor's Castle end boss, required for Cleric, SK, Necromancer, and multiple other epics. Lich-form transition is a scripted mechanic in `akk-stack/server/quests/karnor/`. Preserve the two-form transition; scale HP of each form.

### Drusella Sathir — charasis (Howling Stones)

- **NPC ID:** 105153 / **Level:** 55 / **HP:** 15,750 / **dmg:** 51-310 / **AC:** 234
- **npcspecialattks:** f (flee-disabled only)
- **Respawn:** 194,400s
- **Gap:** ~2× HP — already close to named tier
- **Recommended:** No HP change or 10% cut. Already group-tier difficulty. Respawn to 6h.
- **Notes:** Venril's daughter — thematic pair with VS. Named-adjacent difficulty in practice.

### Overking Bathezid — chardok

- **NPC ID:** 103056 / **Level:** 65 / **HP:** 34,500 / **dmg:** 92-320 / **AC:** 344 / **MR:** 185
- **npcspecialattks:** SEQMCNIDf
- **Respawn:** 5,400s (1.5h) — already short
- **Gap at L65:** ~1.6× HP; damage in named range
- **Recommended:** HP cut 25% (→26k). Damage unchanged. Respawn already fits.
- **Notes:** Throne-room boss of Chardok. Part of "royal court" Chardok raid. Low MR (185) = vulnerable to casters. Lore-master confirm: is he the final Chardok boss in our era? (Chardok-B revamp is post-Luclin.)

### Queen Velazul Di`zok — chardok

- **NPC ID:** 103055 / **Level:** 62 / **HP:** 30,000 / **dmg:** 68-220
- **npcspecialattks:** SETUMCNIDf (summon, enrage, triple, unslowable, mez/charm/normal/stun/dispel-immune, flee-disabled)
- **Respawn:** 5,400s
- **Gap:** ~1.5× HP, damage already low
- **Recommended:** HP cut 20% (→24k). Damage unchanged. Respawn fits.

### Prince Selrach Di`zok — chardok

- **NPC ID:** 103080 / **Level:** 61 / **HP:** 25,000 / **dmg:** 79-250
- **npcspecialattks:** SETMCNIDf
- **Gap:** ~1.3× HP
- **Recommended:** No HP change, or 10% cut. Nearly named-tier already.
- **Notes:** Chardok royals are three-boss sequential fight. Tuning should preserve Overking > Queen > Prince difficulty curve.

### Kilidna — citymist

- **NPC ID:** 90186 / **Level:** 60 / **HP:** 100,000 / **dmg:** 700-4,600 / **AC:** 437 / **MR:** 100
- **npcspecialattks:** STNIDf
- **Respawn:** 5,400s
- **Gap:** ~6× HP and **damage is catastrophic** — 4,600 max is a one-shot on any small-group tank
- **Recommended action:** HP cut 70% (→30k). **Damage cut 75%** (max 1,000). This is the clearest "needs rework" entry — damage ranges should sit well below 1k for any encounter small-group should attempt. Respawn to 6h.
- **Notes:** Rare-spawn Yolinn boss in City of Mist. Lore-master: is this the matriarch of the iksar lich cult? Mechanics should preserve tough fight but not one-shot gimmick.

### Lhranc — citymist

- **NPC ID:** 90093 / **Level:** 60 / **HP:** 19,000 / **dmg:** 120-305
- **Respawn:** 49,215s (~14h)
- **Gap:** ~1.2× HP
- **Recommended:** Minimal change — already near named tier. Respawn already in brief's 6-24h target.

---

### Veeshan's Peak — seven dragons (revamp variants)

All VP entries are the **level 70 revamp variants** (quest scripts target
these IDs). Listed in order of current HP. All have respawn ~270-290k
seconds (~75-80h).

### Xygoz — veeshan

- **NPC ID:** 108053 / **Level:** 70 / **HP:** 814,000 / **dmg:** 480-2,266 / **AC:** 508
- **npcspecialattks:** SEFQUMCNIDf (summon, enrage, flurry, quad, unslowable, mez/charm/normal/stun/dispel-immune, flee-disabled)
- **Respawn:** 271,232s (~75h)
- **Prior-pass:** UNTOUCHED
- **Gap:** at L70 scaled-named ~30k HP; Xygoz is **27× scaled-named HP** and damage 2,266 = one-shot tank
- **Recommended:** HP cut 85% (→120k). Damage max cut 60% (→900). Respawn to 12h. Consider dropping to level 67 to align with Kunark era.

### Nexona — veeshan

- **NPC ID:** 108047 / **Level:** 70 / **HP:** 800,000 / **dmg:** 385-2,475 / **AC:** 508
- **npcspecialattks:** SEFQMCNIDf
- **Respawn:** 269,232s
- **Recommended:** HP cut 85% (→120k). Damage max cut 60% (→1000). Respawn 12h.
- **Notes:** Ranger and Druid epic dragon — important quest node. Poison/disease theme.

### Phara Dar — veeshan

- **NPC ID:** 108048 / **Level:** 70 / **HP:** 681,000 / **dmg:** 1,032-1,621 / **AC:** 508
- **npcspecialattks:** SEFTQMCNIDf
- **Respawn:** 291,232s
- **Recommended:** HP cut 82% (→120k). Damage min-max cut 55% (→450-750). Respawn 12h.
- **Notes:** Final dragon in VP rotation (traditional order). Consort of Hoshkar.

### Guardian of Veeshan — veeshan

- **NPC ID:** 108042 / **Level:** 70 / **HP:** 600,000 / **dmg:** 380-1,273 / **AC:** 508
- **npcspecialattks:** SERFTUMCNIDfm — m = M? (triple unique — AE rampage weapon immune?)
- **Respawn:** 164,895s (~46h)
- **Recommended:** HP cut 80% (→120k). Damage trim 40% (→230-750). Respawn 12h.
- **Notes:** Mini-boss in VP. Sometimes called "the Warden" in lore.

### Hoshkar — veeshan

- **NPC ID:** 108043 / **Level:** 70 / **HP:** 536,000 / **dmg:** 406-1,603 / **AC:** 508
- **Respawn:** 290,001s
- **Recommended:** HP cut 80% (→110k). Damage max cut 50% (→800). Respawn 12h.

### Druushk — veeshan

- **NPC ID:** 108040 / **Level:** 70 / **HP:** 470,000 / **dmg:** 370-1,567 / **AC:** 508
- **npcspecialattks:** SEFTQMCNIDf
- **Respawn:** 291,232s
- **Recommended:** HP cut 80% (→95k). Damage max cut 50% (→780). Respawn 12h.

### Silverwing — veeshan

- **NPC ID:** 108050 / **Level:** 70 / **HP:** 454,000 / **dmg:** 554-1,295 / **AC:** 508
- **Recommended:** HP cut 80% (→90k). Damage min-max cut 40-50%. Respawn 12h.

**VP summary:** All seven VP dragons have the same `AC 508` / level 70
/ SEFQM-family immunities. They form a flat difficulty tier — the
current stat spread (454k-814k HP) gives the impression of
progression but on small-group time-to-kill the differences vanish.
**Recommended unified target:** 100-120k HP across all seven, damage
caps in the 700-1,000 range. Gate progression via quest requirements
instead of stat walls. **User flag:** alternatively, keep the level
65-67 "classic-era" variants (already 144-192k HP) and scrap the
revamp variants — this would require quest-script updates.

---

### Kunark boss catalog — summary table

| Boss | Zone | ID | L | HP | dmg | Prior-pass | Recommended HP cut | Respawn target |
|------|------|----|----|-----|-----|------------|-------------------|----------------|
| Gorenaire | dreadlands | 86014 | 60 | 32k | 139-500 | UNTOUCHED | 30% (→22k) + dmg trim | 6h |
| Severilous | emeraldjungle | 94009 | 60 | 32k | 139-500 | UNTOUCHED | 30% | 6h |
| Talendor | skyfire | 91093 | 60 | 32k | 139-500 | UNTOUCHED | 30% | 6h |
| Faydedar | timorous | 96089 | 55 | 32k | 103-236 | UNTOUCHED | 40% (→19k) | 6h |
| Trakanon | sebilis | 89154 | 65 | 32k | 144-630 | UNTOUCHED | 30% + flurry trim | 6h |
| Venril Sathir | karnor | 102112 | 55 | 22k | 180-404 | UNTOUCHED | 25% (→16.5k) | 6h |
| Drusella Sathir | charasis | 105153 | 55 | 15.75k | 51-310 | UNTOUCHED | 10% or none | 6h |
| Overking Bathezid | chardok | 103056 | 65 | 34.5k | 92-320 | UNTOUCHED | 25% | already 1.5h |
| Queen Velazul | chardok | 103055 | 62 | 30k | 68-220 | UNTOUCHED | 20% | already 1.5h |
| Prince Selrach | chardok | 103080 | 61 | 25k | 79-250 | UNTOUCHED | 10% or none | already 1.5h |
| Kilidna | citymist | 90186 | 60 | 100k | 700-4,600 | UNTOUCHED | **70% HP + 75% dmg** | 6h |
| Lhranc | citymist | 90093 | 60 | 19k | 120-305 | UNTOUCHED | none | already ~14h |
| Xygoz | veeshan | 108053 | 70 | 814k | 480-2,266 | UNTOUCHED | 85% (→120k) + 60% dmg | 12h |
| Nexona | veeshan | 108047 | 70 | 800k | 385-2,475 | UNTOUCHED | 85% + 60% dmg | 12h |
| Phara Dar | veeshan | 108048 | 70 | 681k | 1,032-1,621 | UNTOUCHED | 82% + 55% dmg | 12h |
| Guardian of Veeshan | veeshan | 108042 | 70 | 600k | 380-1,273 | UNTOUCHED | 80% + 40% dmg | 12h |
| Hoshkar | veeshan | 108043 | 70 | 536k | 406-1,603 | UNTOUCHED | 80% + 50% dmg | 12h |
| Druushk | veeshan | 108040 | 70 | 470k | 370-1,567 | UNTOUCHED | 80% + 50% dmg | 12h |
| Silverwing | veeshan | 108050 | 70 | 454k | 554-1,295 | UNTOUCHED | 80% + 40-50% dmg | 12h |

**Kunark true-boss count (in-era, excluding Fabled and post-Luclin content):** 19 encounters (13 dungeon/outdoor + 6-7 VP dragons + Guardian of Veeshan).

**Kunark scaling-gap summary:** Two distinct gap profiles:
- **Outdoor dragons + Chardok royals + Trak/VS/Drusella:** gap is moderate (1.5-4× HP). 20-40% HP cuts bring them in line. Damage mostly fine.
- **VP dragons (revamp variants) + Kilidna:** gap is extreme (6-27× HP, damage often one-shots). 75-85% HP cuts plus 40-75% damage cuts required. **These are the highest-priority Kunark fixes and alone might justify a dedicated Kunark sub-phase.**

### Kunark raid quest chains

> **Status:** Lore-master's canonical catalog delivered 2026-04-22. See
> full walkthrough at
> `/mnt/d/Dev/eq/claude/project-work/feature-raid-scaling/lore-master/kunark-chains.md`.
> This section summarizes lore-master's findings and highlights
> project-critical additions for the architect. The game-designer's
> original fallback (preserved below) is SUPERSEDED where it conflicts.

#### Key project-critical findings from lore-master Kunark review

**Two additional duplicate-ID pairs confirmed via db query:**

1. **Trakanon has TWO NPC IDs — both need scaling.**
   - **id 89154 `Trakanon`** (raid_target=1, L65, 32,000 HP, SERFMCNDf) —
     standard Old Sebilis boss. Drops Trakanon's Tooth (VP key). Already
     in boss catalog.
   - **id 89181 `#Trakanon`** (raid_target=0, L65, **16,000 HP**, SMCNIDf) —
     script-spawned via An Undead Bard (id 89168) handoff. Drops Undead
     Dragongut Strings for Bard Epic. NOT in boss catalog because
     raid_target=0. **HP is already half the standard Trakanon** — close
     to scaled-named tier — architect: minimal or no HP cut, but apply
     damage trims consistent with standard Trakanon to keep the two
     variants comparable.

2. **Venril Sathir has TWO RAID-TIER NPC IDs + 3 support NPCs** (already
   surfaced in Classic addenda but re-confirmed here as quest-dependency).
   - **id 102112 `#Venril_Sathir`** (raid_target=1, 22k HP) — triggered
     raid form for Druid/Ranger epic (Paw of Opolla + Spiroc Feather).
   - **id 102126 `Venril_Sathir`** (raid_target=0, 11k HP, SRUMCNIDf) —
     the Wizard-epic standard form (Gnarled Staff). Lore-master
     originally described this as ~18k HP but db query shows 11k.
     **Db value is authoritative.**
   - Support: 102099 remains, 102123 spirit, 105182 Charasis variant.

**Kunark pain-score distribution (14 epics):**
- **RED (blocker):** Bard (triggered Trak), Cleric (Overking Bathezid
  L63), Druid (triggered VS + faction), Magician (Magi P`Tasa PoHate),
  Ranger (triggered VS + faction), Shaman (Truespirit faction — linear/
  non-repeatable), Warrior (Queen Velazul + Severilous/Talendor). **7 of 14.**
- **YELLOW:** Enchanter (Tangrin + Iksar faction), Monk (Chardok rare +
  PoSky-era blocker), Necromancer (Mak'ha + planar), Paladin (Lhranc +
  CoM navigation), Rogue (KC rare), SK (Lhranc + PoHate). Wizard
  (Y-R — VS lifetap risk, PoFear Enraged Golem). **7 of 14.**
- **GREEN:** none (Kunark has zero pain-score-GREEN epic phases).

**Newly surfaced or re-emphasized blockers:**

3. **Truespirit faction is a STRUCTURAL hard gate for 3 classes**
   (Druid, Ranger, Shaman — especially Shaman which is almost entirely
   Truespirit-gated). Linear, non-repeatable. No amount of boss
   scaling fixes this. Architect: script review required before
   Phase 4 — any dialogue trigger bug permanently bricks these epics.

4. **Keepers of the Art faction grind is ~3,000 Batwing turn-ins
   (~6 hours solo)** — required for Druid/Ranger epics before the
   Kunark raid steps even start. Boss scaling doesn't help.

5. **Iksar faction gate for non-Iksar races** blocks VP key sub-quest
   B (Medallion of Obulus), Enchanter epic, and Necromancer epic.
   Faction grind ~6 hrs OR Iksar illusion item required.

6. **Necromancer PoSky Island 1 destructive turn-in:** giving Tome
   of Instruction to Thunder Spirit Princess DESPAWNS her, breaking
   PoSky Island 1 for any other player in that instance. **Flag for
   architect:** on a 1-3 player server this is not a multi-player
   grief concern, but it permanently removes progression for the
   Necro player's own PoSky key chain until respawn. Script-script
   interaction to verify.

7. **Kilidna is NOT a required epic kill** — she is a NAVIGATION
   HAZARD on the path to Lhranc in City of Mist. Her 4,600 max damage
   means small groups can't safely path past without careful route
   planning. **Audit's Kilidna damage cut recommendation (75% dmg
   cut to ~1,000) is actually about zone traversal safety, not about
   direct kills.** Architect: preserve this rationale in implementation
   notes.

8. **Skyfire "hand quest" clarification:** NOT a standalone quest
   chain. It refers to the Jennus Lyklobar step within Magician
   Epic (assembles Element of Fire from 4 pre-collected items). The
   Skyfire zone itself requires no raid kill for any epic other than
   Warrior (Talendor for Red Dragon Scales) and Zordakalicus Ragefire
   (optional Cleric epic path).

9. **VP Key quest structural flow (new detail for audit):**
   ```
   VP Key = Medallion of Jarsath (3 ground/named pieces, Swamp/FV/LakIO)
        + Medallion of Obulus (3 pieces, Iksar-faction-gated)
        + Medallion of Kylong (3 pieces — Chardok gems + KC rare + Kaesora)
        + Trakanon's Tooth (standard Trakanon raid kill)
   → combined + given to Emperor Ganak (id 95034, L60 16k HP, TT zone)
   → Key of Veeshan received
   ```
   Nine named/ground-spawn pieces across 6 zones plus one full raid
   boss. Rare-spawn timers (~8h each) mean VP key takes multiple
   days solo even with all pieces available.

10. **Sebilis Key (Trakanon Idol) is the easiest Kunark key:** two
    froglok named kills in Lake of Ill Omen (not raid), given to
    Emperor Ganak. GREEN pain score. No faction gate, no raid.

11. **Lhranc dual-epic duplication possibility:** if a small group
    has both Paladin and SK characters, Lhranc must be killed twice
    (different component items, different outcomes — Heart of the
    Innocent vs Lhranc's Token). 13hr+ respawn means two-week
    campaign for both epics on same character/group.

**Cross-class shared dependencies (Kunark):**

| Boss / NPC | Zone | Classes affected | Notes |
|-----------|------|------------------|-------|
| Trakanon (standard 89154) | Old Sebilis | ALL VP-requiring epics | Tooth drop = VP key prerequisite, effectively ~8 epics need him eventually |
| Venril Sathir (triggered 102112) | Karnor's Castle | Druid + Ranger | Single-kill shareable between the two epics |
| Venril Sathir (standard 102126) | Karnor's Castle | Wizard | Separate NPC, separate kill |
| Queen Velazul Di`Zok | Chardok | Warrior + VP key Medallion of Kylong | Double-duty |
| Overking Bathezid | Chardok | Cleric | L63 functional raid — Chardok royal area |
| Chardok royals (Queen + Overking + Prince Selrach) | Chardok | 5 epics + VP key | Same picklock-access wing — plan multi-epic visit |
| Lhranc | City of Mist | Paladin + SK | Same NPC, different items |
| Faydedar (standard 96089 + weak #Faydedar 96073) | Timorous Deep | Druid + Ranger | Dolgin Codslayer trigger |

**Boss catalog amendments needed:**
- Add The Tangrin (id 78070, already covered in Classic-addenda block)
- Add Venril Sathir 102126 + 105182 (already covered in Classic-addenda)
- Add Faydedar 96073 alternate (already covered)
- Add `#Trakanon` id 89181 (triggered Bard-epic variant)
- An Undead Bard (id 89168) is the spawner NPC — not a scaling target

---

#### Full Kunark catalog

See `lore-master/kunark-chains.md` for complete walkthrough of VP key,
Sebilis key, Skyfire clarification, and per-class Kunark-phase steps
with tables, raid encounter matrix, and non-combat blockers summary.

---

#### (Preserved: Game-designer's original Kunark fallback summary, now superseded by lore-master catalog above)

**Scope:** The "Kunark-phase" of Epic 1.0 for all classes (most
epics cluster heavily in Kunark — this is where the raid-tier
kill component is concentrated), plus Veeshan's Peak key quest,
plus any Kunark-specific raid-access progression.

---

#### Veeshan's Peak key quest

- **Class/scope:** General raid access — VP is a post-endgame
  zone within Kunark
- **Era:** Kunark
- **Zones:** Emerald Jungle, Skyfire Mountains, Dreadlands, The
  Overthere, Lake of Ill Omen, Trakanon's Teeth, Sebilis (entry)
- **Turn-in NPCs:** Yendalor (Emerald Jungle), Jaled Dar (Nedaria's
  Landing — post-Velious lore; may not be present in era)
- **Raid encounters required:**
  - Gorenaire (Dreadlands) — "tear" drop
  - Severilous (Emerald Jungle) — "claw" drop
  - Talendor (Skyfire) — "scale" drop
  - Faydedar (Timorous Deep) — "fang" drop
  - **Trakanon** (Sebilis end-boss) — key component
- **Non-encounter blockers:**
  - Skyfire "Hand of the Master" quest chain prereqs
  - Faction requirements (Emerald Jungle druids vs dragons)
  - Multiple ground spawns in Skyfire canyon
- **Progression path:** Kill all 5 outdoor dragons + Trakanon +
  combine with hand/jewel drops → VP key
- **Small-group blockers:**
  - All 5 outdoor dragons tractable with audit scaling (most need
    ~30% HP cut only)
  - Trakanon 30% HP cut + flurry trim makes Sebilis endgame
    viable
  - VP key ground-spawn rares (Jade/Ruby/Sapphire Shards per
    traditional chain) — need to verify these are obtainable
    solo by small group
- **Recommended action:** No changes needed beyond audit boss-
  catalog stat cuts. Flag for lore-master: verify "Jaled Dar" is
  accessible in era (Nedaria's Landing is OoT expansion content).

#### Emerald Jungle — Severilous + Hand of the Master chain

- **Class/scope:** Monk Epic (Celestial Fists — Ton Po chain);
  VP key step; general raid access
- **Era:** Kunark
- **Zones:** Emerald Jungle, Skyfire Mountains
- **Raid encounters required:**
  - Severilous (Emerald Jungle outdoor)
  - Zordakalicus Ragefire (Skyfire event) — optional for some chains
- **Recommended action:** Audit boss-catalog covers Severilous and
  Ragefire.

---

#### Class Epic 1.0 — Kunark-phase raid steps

**Bard Epic 1.0 — Singing Short Sword of the Ykesha**
- Kunark raid steps:
  - **Faydedar** (Timorous Deep) — scale drop
  - **Trakanon** (Sebilis) — tooth drop
  - Possibly Chardok or Howling Stones drops for sub-components
- Small-group viability: OK post-scaling

**Cleric Epic 1.0 — Water Sprinkler of Nem Ankh**
- Kunark raid steps:
  - **Trakanon** — primary raid component
  - Severilous — possibly (for "healer" class variant path)
- Small-group viability: Very good — Trakanon's damage is fine
  as-is

**Druid Epic 1.0 — Nature Walker's Scimitar**
- Kunark raid steps:
  - **Faydedar** — primary (signature druid epic target)
- Small-group viability: Excellent — outdoor dragon, no adds

**Enchanter Epic 1.0 — Staff of the Serpent**
- Kunark raid steps: Chardok royals for certain components
- Small-group viability: Overking Bathezid + Queen Velazul +
  Prince Selrach are a well-scaled trio post-audit cuts

**Magician Epic 1.0 — Orb of Mastery**
- Kunark raid steps:
  - Faydedar for elemental water component
  - Chardok royals for earth/air components
- Small-group viability: good

**Monk Epic 1.0 — Celestial Fists**
- Kunark raid steps:
  - "Hand of the Master" chain involves Skyfire + Chardok trip
  - Ton Po / Skyfire
- Small-group viability: good post-scaling

**Necromancer Epic 1.0 — Scythe of the Shadowed Soul**
- Kunark raid steps:
  - **Venril Sathir** (Karnor's) — primary raid kill
  - Specific Kunark components
- Small-group viability: VS 25% HP cut + damage trim → tractable

**Paladin Epic 1.0 — Soulfire / Fiery Avenger**
- Kunark raid steps:
  - Components from Chardok royals (Queen Velazul)
  - Specific dragon components
- Small-group viability: good

**Ranger Epic 1.0 — Earthcaller**
- Kunark raid steps:
  - **Faydedar** (primary) — requires coordination with multiple
    outdoor dragons' hand drops

**Rogue Epic 1.0 — Ragebringer**
- Kunark raid steps:
  - **Chardok Overking Bathezid** drop
  - **Charasis (Howling Stones)** Drusella Sathir drop
  - Multiple ground-spawn dagger pieces in Kunark outdoor zones
- Small-group viability: good — Chardok royals and Drusella are
  both low-gap

**Shadow Knight Epic 1.0 — Innoruuk's Curse**
- Kunark raid steps:
  - **Venril Sathir** — primary Kunark raid target
- Small-group viability: good

**Shaman Epic 1.0 — Spear of Fate**
- Kunark raid steps:
  - **Faydedar** component
  - Chardok components
- Small-group viability: excellent

**Warrior Epic 1.0 — Jagged Blade of War** _(corrected 2026-04-22 per lore-master review)_
- Kunark raid steps:
  - **Trakanon** component
  - Outdoor dragon component
  - Chardok
- Small-group viability: Trakanon + outdoor dragons both
  audit-friendly

**Wizard Epic 1.0 — Staff of the Four**
- Kunark raid steps:
  - Chardok Prince Selrach + royals
  - Specific magic school components
- Small-group viability: good

---

#### Kunark quest chain summary

- **Kunark is the heaviest Epic 1.0 raid-quest era.** Most classes
  have their single required raid-kill in Kunark. Shared
  dependencies across multiple epics:
  - **Faydedar (timorous, 96089):** Druid, Ranger, Shaman,
    Magician, Bard — **at least 5 class epics require Faydedar**
  - **Trakanon (sebilis, 89154):** Cleric, Warrior, Bard — **3+
    class epics**
  - **Venril Sathir (karnor, 102112):** Necromancer, SK — **2+
    class epics**
  - **Chardok royals (chardok, 103055/56/80):** Enchanter,
    Magician, Paladin, Rogue, Wizard — **5+ class epics**
  - **Outdoor dragons (Gorenaire, Severilous, Talendor):**
    required for VP key, which indirectly blocks Warrior, Paladin,
    SK epic late steps
- **Kunark quest chains are generally the BEST-behaving for small
  group** — most raid targets are one-pull outdoor dragons at
  manageable stats after audit cuts (20-40% HP). No add-heavy
  scripted event wipes.
- **Sole high-priority scaling concern:** VP dragons
  (Druushk, Hoshkar, Nexona, Phara Dar, Silverwing, Xygoz +
  Guardian) — the audit recommends 80-85% HP cuts and significant
  damage trims because these are catastrophic at current stats.
- **Kilidna (citymist)** damage 4,600 max requires aggressive
  trim for any small-group attempt.

**No hard quest blockers beyond boss-stats are expected after
audit implementation for Kunark.** All ground spawns, faction
grinds, and rare-drop components are obtainable solo by a
companion-supported small group.

---

## Velious (expansion 2)

### Velious raid boss catalog

**Summary:** Velious is the largest single-era raid cluster in the game.
True-boss count (in-era, excluding Fabled and pre-raid-tier elite trash)
is approximately **60-65 encounters** across:

- **Temple of Veeshan (ToV):** 16 dragon lords (Vulak`Aerr at top, plus
  Lords/Ladies/named dragons below) + ~12 mid-tier named dragons (Midayor
  cluster) + ~20 elite-tier defenders (out of scope — trash)
- **Sleeper's Tomb:** 13 encounter bosses (5 Ancients, 4 Warders, plus
  gatekeepers) — **excluding The Sleeper event itself**
- **Kael Drakkel:** 4 primary bosses (King Tormax, Avatar of War, Statue
  of Rallos Zek, Derakor the Vindicator)
- **Skyshrine:** Lord Yelinak + 4 Crusaders (Charayan, Susarrak, Grendish,
  Jortreva)
- **Plane of Growth:** 7-8 encounters (Tunare, Guardian of Tunare, Ail
  the Elder, Treah Greenroot, Rumbleroot, Fayl Everstrong, Guardian of
  Takish)
- **Western Wastes:** ~20 outdoor dragons — a mix of 30k-100k HP
  encounters. True boss tier is Klandicar, Sontalak, Melalafen, Harla
  Dar, Mraaka (65-100k); remainder are "named+ tier".
- **Other zones:** Velketor the Sorcerer, Kelorek`Dar (Cobaltscar),
  Narandi the Wretched (Great Divide), Zlandicar (Dragon Necropolis),
  Dain Frostreaver IV (Icewell Keep / thurgadinb), Wuoshi (Wakening
  Lands), Mischief Plane trio (Bristlebane, All-Seeing Eye, Mischievous
  Jester), Siren's Grotto (Faleniel, Wygrish)

**Flag for user (major decision):** Velious scope alone may justify a
dedicated sub-phase. Recommended split options:
- **Option A — single Phase 4:** tackle all ~65 encounters together
- **Option B — Phase 4a/4b:** 4a = Kael + Skyshrine + Growth + outdoor
  (~35 encounters), 4b = ToV + Sleeper + Necropolis (~30 encounters
  at higher HP)
- **Option C — Phase 4-only-tier:** skip ToV/Sleeper entirely and
  accept they're end-game "wait until fully geared" content

**Scaling gap overview:** Velious is the era where most content uses
the auto-scale baseline (type 2, level 60 = 450k HP). Average ToV
boss = 380k HP, average Sleeper ancient = 350k HP. A scaled-named at
L65-66 is 22-24k HP. Gaps are therefore 15-20× for ToV and 15× for
Sleeper. Post-scaling target: ~80-120k HP for endgame-tier (ToV,
Sleeper, Vulak, Avatar of War), ~40-60k for mid-tier (Kael,
Skyshrine, Growth, Western Wastes bosses), ~25-35k for outdoor mini-
raids.

**Damage outliers:** Lord Vyemm (max 1,200), Vulak`Aerr (max 1,400),
Avatar of War (max 1,154), Dagarn (max 755 with 900 AC so he's
tankable), Gozzrem/Telkorenar (max 480 low!). Sir_Elmonious_Falmont
(max 3,667 — OUT OF ERA, probably event).

---

### Kael Drakkel — kael

| Boss | ID | L | HP | dmg | Abilities | Respawn | Gap | Recommended |
|------|----|----|-----|-----|-----------|---------|-----|-------------|
| The Avatar of War | 113457 | 70 | 900,000 | 299-1,154 | SERQUMCNIDf + rampage 6×6 | — | ~30× | HP → 120k (-87%), dmg → 200-700 (-40%), respawn 12h |
| King Tormax | 113215 | 70 | 452,000 | 195-575 | SERQUMCNDf | 259,200s (72h) | ~15× | HP → 100k (-78%), dmg unchanged, respawn 12h |
| Statue of Rallos Zek | 113071 | 59 | 400,750 | 245-1,100 | SERQMCNIDf | 194,400s | ~20× | HP → 50k (-87%), dmg → 150-500 (-55%), respawn 12h |
| Derakor the Vindicator | 113118 | 70 | 180,000 | 225-700 | SERQUMCNDf | 43,200s (12h) | ~6× | HP → 60k (-67%), dmg trim 20%, respawn already fits |

**Kael notes:** Avatar of War is the deepest raid-quest node — required
for at least 3 class epics (Warrior, SK, Paladin) and Kael dragon
faction. Respawn of 72h on Tormax is the longest of any Velious raid
— suggest 12h. Statue of Rallos Zek is the Kael "trigger" event —
usually a scripted fight with adds.

---

### Skyshrine — skyshrine

| Boss | ID | L | HP | dmg | Abilities | Respawn | Recommended |
|------|----|----|-----|-----|-----------|---------|-------------|
| Lord Yelinak (main) | 114106 | 70 | 500,000 | 204-804 | SEFQUMCNIDf | 259,200s | HP → 110k (-78%), respawn 12h |
| Lord Yelinak (variant) | 114618 | 70 | 297,000 | 204-804 | SEFQUMCNIDf | 259,200s | Duplicate ID — one likely deprecated. Flag for user. |
| Charayan the Crusader | 114242 | 70 | 233,000 | 125-410 | SERQMCNIDf | 640s (11m) | HP → 50k (-78%), respawn ok or boost to 1h |
| Susarrak the Crusader | 114243 | 70 | 233,000 | 125-410 | SERQMCNIDf | 640s | Same as Charayan |
| Grendish the Crusader | 114245 | 70 | 233,000 | 125-410 | SERQMCNIDf | 640s | Same |
| Jortreva the Crusader | 114246 | 70 | 233,000 | 125-410 | (no specials) | 640s | Same. Note: missing immunity flags — odd, may be bug |

**Skyshrine notes:** The four Crusaders are a group fight (ring +
chamber). 11-minute respawn on Crusaders is already fast enough. Yelinak
is the dragon-throne boss — Ring of Scale faction's living high-priest
(in PEQ — lore-master confirm: historically Yelinak is Ring's leader,
killable only via faction hostility path). Two Yelinak IDs exist
(114106 main vs 114618 variant) — one likely a quest-spawned copy.

---

### Plane of Growth — growthplane

| Boss | ID | L | HP | dmg | Abilities | Respawn | Recommended |
|------|----|----|-----|-----|-----------|---------|-------------|
| #_Tunare | 127001 | 66 | 530,000 | 166-926 | f | 259,200s | HP → 150k (-72%), respawn 12h — final boss |
| Guardian of Tunare | 127007 | 60 | 310,000 | 92-187 | m (AE rampage weapon) | 64,800s | HP → 80k (-74%), already ~18h respawn |
| Guardian of Tunare (dup) | 127106 | 60 | 310,000 | 92-187 | — | 64,800s | Duplicate — same recommendations |
| Ail the Elder | 127020 | 60 | 215,000 | 130-700 | SREMCNUTD | 64,800s | HP → 60k (-72%), damage trim 20% |
| Rumbleroot | 127019 | 60 | 193,000 | 130-700 | FSREMCNUID | 64,800s | HP → 55k (-72%), damage trim 20% |
| Treah Greenroot | 127021 | 60 | 191,000 | 130-700 | FSREMCNUID | 64,800s | HP → 55k, damage trim 20% |
| Guardian of Takish | 127035 | 70 | 200,000 | 96-210 | FSREMCNUIQDm | 86,400s | HP → 60k (-70%), damage fine |
| Fayl Everstrong | 127018 | 60 | 150,000 | 130-700 | SREMCNUID | 64,800s | HP → 45k (-70%) |
| Prince Thirneg | 127096 | 65 | 69,719 | 82-196 | (none) | — | Already mid-tier — HP trim 15% |
| 2x a_thifling_focuser | 127005/6 | 65 | 1,000,000 | 100-233 | SEMCNID | 64,800s | **SPECIAL** — these are "focus the energy of the plane" event triggers, likely not normal kills. Investigate before scaling. |
| a_warm_light | 127004 | 1 | 1,000,000 | 2-9 | W (weapon ranged) | 64,800s | **EVENT TRIGGER** — level 1 but 1M HP. Interactive mob, not a kill. Skip. |

**Growth notes:** "a_warm_light" and "a_thifling_focuser" are likely
event-control NPCs (trigger Tunare spawn). Lore-master to confirm the
Plane of Growth progression ritual. Tunare is the "goddess of Growth"
— her fight is traditionally scripted with adds spawning from
focusers.

---

### Temple of Veeshan — templeveeshan

**16 dragon lords (true bosses):**

| Boss | ID | L | HP | dmg | Abilities | Recommended HP | Recommended dmg |
|------|----|----|-----|-----|-----------|----------------|-----------------|
| Lord Koi`Doken | 124103 | 66 | 580,000 | 215-690 | SREMCNITDf | 130k (-78%) | 180-500 (-28%) |
| Lady Nevederia | 124076 | 66 | 525,000 | 189-892 | SERTMCNIDf | 120k (-77%) | 160-600 (-33%) |
| Lord Kreizenn | 124074 | 66 | 465,000 | 209-950 | SETMCNIDUf | 110k (-76%) | 180-600 (-37%) |
| Lord Feshlak | 124008 | 66 | 455,000 | 238-960 | SERTMCNIDf | 110k (-76%) | 200-600 (-37%) |
| Cekenar | 124071 | 66 | 425,000 | 225-700 | SRETMCNDf | 100k (-76%) | 200-500 (-28%) |
| Aaryonar | 124010 | 66 | 390,000 | 235-900 | SEQMCNIDf | 95k (-76%) | 200-550 (-38%) |
| Dozekar the Cursed | 124037 | 66 | 386,500 | 235-900 | SEQMCNIDf | 95k (-76%) | 200-550 (-38%) |
| Lady Mirenilla | 124077 | 66 | 380,000 | 285-950 | SERTMCNIDf | 95k (-75%) | 220-600 (-36%) |
| Lord Vyemm | 124017 | 66 | 350,000 | 250-1,200 | SERTMCNIDf | 90k (-74%) | 200-700 (-41%) |
| Lendiniara the Keeper | 124020 | 66 | 320,000 | 215-652 | SERQUMCNIDf | 80k (-75%) | 180-500 (-23%) |
| Dagarn the Destroyer | 124011 | 70 | 300,000 | 280-755 | SERQMCNIDf | 80k (-73%) | damage fine |
| Telkorenar | 124104 | 66 | 280,000 | 195-480 | SERTUMCNIDf | 75k (-73%) | damage fine |
| Gozzrem | 124105 | 66 | 280,000 | 195-480 | SERTMCNIDUf | 75k (-73%) | damage fine |
| Ikatiar the Venom | 124001 | 66 | 250,000 | 275-750 | SERTUMCNIDf | 65k (-74%) | 220-550 (-27%) |
| Jorlleag | 124072 | 66 | 250,000 | 213-916 | SETMCNIDf | 65k (-74%) | 200-600 (-35%) |
| Eashen of the Sky | 124004 | 66 | 240,000 | 275-750 | SEFTUMCNIDf | 65k (-73%) | 220-550 (-27%) |

**Plus: Vulak`Aerr (script-spawned, not in spawnentry):** id=124155,
L70, HP 890,000, dmg 355-1,400, AC 950, MR 80 — **the ToV pinnacle
boss.** Recommend HP → 150k (-83%), damage → 250-800 (-43%). Respawn
not shown (event-gated). **Vulak requires a specific summoning event
from the six altars** (traditional: kill specific dragon lords to
activate altars, then trigger Vulak). Scaling must preserve that
progression chain.

**ToV tier notes:**
- All have respawn 259,200s (72h) — brief wants 6-24h, suggest 12h.
- AC 484-570 on all — consistent.
- MR mostly 180-225 (1 exception: Lord Vyemm MR=1,000 — magic wall).
- Lord Vyemm's MR=1,000 and special_abilities list 42 (whatever that
  flag is) marks him as the "no-magic-dps" ToV boss. This is lore-
  canonical (Vyemm is guardian against magic) — preserve the gimmick.

**12 mid-tier ToV named (level 60-65, 101-140k HP):** Midayor,
Grozzmel, Ymmeln, Krigara, Lepethida, Essedera, Tavekalem, Casalen,
Cyndor Lightningfang, Yrrindor Emerald Claw, Zlexak, Sevalak,
Malteor Flamecaller, Zyerek Onyxblood, Kalkar of the Maelstrom,
Vyldin Flamereaver. Plus defender-class mobs (Emerald/Sky/Onyx/Lava
Defenders) at 120k. **Recommended:** HP cut 60-70% → 40-50k each,
damage already mostly in named range — minor trim. Respawn 259k →
12h for named, 16k-65k (already short) ok for defenders.

**ELITE TRASH in ToV (out of scope):** ~20 drakes, wyverns, racnar,
dancers at 50-75k HP. Already handled — these sit between named and
boss tier and the brief explicitly said "current named difficulty
feels good". No action needed unless the Lord Kreizenn-tier scaling
makes them feel wrong.

---

### Sleeper's Tomb — sleeper

| Boss | ID | L | HP | dmg | Recommended HP | Notes |
|------|----|----|-----|-----|----------------|-------|
| Zeixshi-Kar the Ancient | 128044 | 70 | 377,000 | 372-929 | 90k (-76%) | One of 5 Ancients; scripted Warder-trigger |
| The Final Arbiter (main) | 128143 | 70 | 357,000 | 292-629 | 85k (-76%) | Sleeper-event-adjacent scripted boss |
| Kildrukaun the Ancient | 128041 | 70 | 352,000 | 284-705 | 85k (-76%) | Ancient |
| Vyskudra the Ancient | 128042 | 70 | 352,000 | 284-789 | 85k (-76%) | Ancient |
| Tjudawos the Ancient | 128043 | 70 | 352,000 | 292-767 | 85k (-76%) | Ancient |
| The Progenitor (main) | 128144 | 70 | 327,000 | 204-619 | 80k (-75%) | Sleeper event boss |
| Master of the Guard (main) | 128145 | 69 | 326,500 | 157-432 | 80k (-75%) | Gatekeeper |
| Milas An`Rev | 128040 | 67 | 210,000 | 162-447 | 60k (-71%) | Mid-tier boss |
| Hraashna the Warder | 128093 | 70 | 200,000 | 137-509 | 60k (-70%) | Warder (1 of 4) |
| Nanzata the Warder | 128090 | 70 | 200,000 | 115-442 | 60k | Warder |
| Tukaarak the Warder | 128092 | 70 | 200,000 | 126-405 | 60k | Warder |
| Ventani the Warder | 128091 | 70 | 200,000 | 136-415 | 60k | Warder |
| The Final Arbiter (alt) | 128045 | 70 | 200,000 | 166-460 | 60k (-70%) | Variant |

**Sleeper's Tomb special cases:**
- **#Kerafyrm / #The_Sleeper (id 128089, 128094, 128095):** level 99,
  3,500,000 HP, dmg 2,000-7,003 — this is the **AWAKENED SLEEPER**
  post-event. Not intended as a kill target. **Out of scope.** If
  scaling raid content is the goal, the Sleeper-wake event itself
  (the traditional "unkillable world event") should remain untouched
  or be handled as a narrative event rather than a scaling target.
- **Respawns:** all Warders/Ancients at 259,200s (72h) — suggest 24h
  for Ancients (the 4 Warders + 4 Ancients + Final Arbiter is the
  full-rotation raid; long respawn preserves "weekly raid" feel).
- **Event trash** (Drakonine Caretakers/Defenders at 100-150k, plus
  40+ smaller Drakonine variants at 31-70k): out of scope — these
  are raid-zone trash, not true bosses. Note that their HP is in
  "elite named" range already.

**Kerafyrm/Sleeper trigger summary:** The Sleeper event is a LORE-
cataclysmic event (traditional servers: once triggered, The Awakened
Sleeper roams Norrath killing everything until world restart). Not a
scaling target. Lore-master to document event status for the project.

---

### Outdoor / misc Velious encounters

| Boss | Zone | ID | L | HP | dmg | Recommended |
|------|------|----|----|-----|-----|-------------|
| Velketor the Sorcerer | velketor | 112025 | 66 | 201,500 | 185-850 | HP → 60k (-70%), dmg trim 20% |
| Lord Doljonijiarnimorinar | velketor | 112049 | 65 | 147,000 | 195-480 | HP → 45k (-69%), respawn 12h |
| Kelorek`Dar | cobaltscar | 117073 | 65 | 100,000 | 63-219 | HP → 35k (-65%), damage already low |
| Narandi the Wretched | greatdivide | 118145 | 65 | 150,000 | 195-480 | HP → 45k (-70%), respawn 208h (!!) — reduce to 24h |
| Taskmaster Abyott | greatdivide | 118088 | 62 | 72,000 | 88-278 | HP → 30k, damage fine |
| Dain Frostreaver IV | thurgadinb | 129003 | 70 | 352,000 | 160-350 | HP → 80k (-77%), damage fine. **Faction-gated** — see Coldain Ring War |
| Chamberlain Krystorf | thurgadinb | 129028 | 60 | 80,000 | 125-315 | HP → 30k (-63%) |
| Zlandicar | necropolis | 123115 | 70 | 110,000 | 157-366 | HP → 35k (-68%), damage already low. Respawn 12h |
| Jaled Dar's Shade | necropolis | 123011 | 70 | 3,002,000 | 250-900 | **SPECIAL — 3M HP is probably an event timer-check mob.** Investigate before scaling. |
| Wuoshi | wakening | 119112 | 64 | 46,000 | 204-584 | Named-tier already — 10-20% HP trim |
| Scout Leader Plavo | wakening | 57156 | 70 | 300,000 | 193-496 | OUT-OF-ERA check — ID 57156 is a Lesser Faydark range, likely revamp content. Flag for user |
| Lantaric`Dar | wakening | 119165 | 70 | 800,000 | 0-4 | **EVENT MOB** — 0-4 damage = passive event trigger. Skip scaling. |
| Lodizal | iceclad | 110099 | 60 | 40,561 | 110-300 | Named-tier — HP trim 20%. Quest giver (Velious Shawl) |
| Corudoth | iceclad | 110037 | 5 | 60,000 | 10-64 | ODDITY — level 5 with 60k HP. Investigate. |
| Melalafen | westwastes | 120126 | 65 | 70,000 | 192-504 | HP trim 20% |
| Sontalak | westwastes | 120005 | 70 | 97,500 | 140-425 | HP → 40k (-59%). Ring-of-Scale-hostile dragon |
| Klandicar | westwastes | 120084 | 70 | 97,500 | 198-540 | HP → 40k (-59%). Ring-of-Scale-friendly dragon (faction implication — see lore) |
| Harla Dar | westwastes | 120057 | 66 | 65,000 | 96-305 | HP → 28k (-57%), already near named tier |
| #Mraaka | westwastes | 120064 | 66 | 60,000 | 149-320 | HP trim 30% |
| (~15 other WW dragons) | westwastes | — | 51-62 | 24-50k | — | Most in named-tier range; no action or minor trim. See Classic west-wastes dragon cluster. |
| Velious Siren bosses | sirens | 125070/72 | 68-70 | 200-300k | 380-1,900 | Faleniel (300k dmg 380-1900) and Wygrish (200k dmg 587-1575) — HP trim 70%, dmg trim 50% |
| Sir Elmonious Falmont | westwastes | 120133 | 70 | 400,000 | 500-3,667 | **OUT-OF-ERA check** — damage 3,667 = PoP tier. Likely event or revamp content. |
| a_warm_light / a_thifling_focuser | growthplane | — | 1/65 | 1M | varies | **EVENT TRIGGERS — not scaling targets** |
| The Seventh Hammer | varies | 201500 | 73 | 1.2M | 360-1196 | **OUT-OF-ERA** — level 73 is post-Luclin |
| Legendary Velious Dragon | eastwastes | 116607 | 72 | 312,500 | 225-1,504 | **OUT-OF-ERA** — LoN anniversary |
| #An Egg Hunter | eastwastes | 116605 | 75 | 981,589 | — | **OUT-OF-ERA** |

---

### Mischief Plane — mischiefplane

| Boss | ID | L | HP | dmg | Notes |
|------|----|----|-----|-----|-------|
| #Bristlebane | 126160 | 75 | 1,000,000 | 680-1,904 | **Level 75 = post-era / LoN tier. Out of scope.** |
| All-Seeing Eye | 126374 | 75 | 709,000 | 350-1,300 | Out of era |
| #the Mischievous Jester | 126012 | 70 | 200,000 | 235-1,431 | Era-boundary — if active, HP → 60k, dmg trim 50% |

Mischief Plane in PEQ is post-Luclin Plane of Mischief revamp. Likely
all three entries are out-of-era. **Flag for user: is Mischief Plane
intended to be in-scope?**

---

### Velious boss catalog — headline metrics

- **In-era true-boss count:** 60-65 (of which ~30 in ToV+Sleeper)
- **Average HP gap for endgame tier (ToV, Sleeper, Vulak, AoW):** 15-25× scaled-named
- **Average HP gap for mid-tier (Kael, Skyshrine, Growth, Velketor, outdoor):** 6-15×
- **Average HP gap for outdoor named-adjacent (West Wastes dragons):** 2-4×
- **Number of special-case entries** (events, triggers, out-of-era, duplicates): ~15
- **Respawn issues:** most are at 72h (259k seconds) — every bracketed boss needs reduction to 12h (43.2k) per brief. A few already at 12h or shorter; 3 are at 208h+ (!).

**Velious scaling-gap summary:** Velious is the era where the gap is
widest AND where post-Velious content-creep (Fabled, LoN, revamps) most
pollutes the raid_target pool. Careful filtering is mandatory — the
raw count of 362 raid_target NPCs in Velious zones reduces to 60-65
true in-era bosses, which is still the largest era block.

**Strong recommendation:** Velious warrants its own dedicated sub-
phase (Option B split). Temple of Veeshan alone has 16 dragon lords
that need individual tuning verification because scripted lore abilities
(Lord Vyemm's magic wall, Aaryonar's specific breath) need to be
preserved. Sleeper's Tomb has 13 more. That's ~30 endgame encounters
just in two zones.

### Velious raid quest chains

> **Status:** Lore-master's canonical catalog delivered 2026-04-22. See
> full walkthrough at
> `/mnt/d/Dev/eq/claude/project-work/feature-raid-scaling/lore-master/velious-chains.md`.
> This section summarizes lore-master's findings and highlights
> project-critical additions for the architect. The game-designer's
> original fallback (preserved below) is SUPERSEDED where it conflicts.

#### Key project-critical findings from lore-master Velious review

**1. Epic 1.0 has NO Velious-phase steps.** All 14 class Epic 1.0
chains complete in Classic + Kunark. Velious quest progression is
its own ecosystem (Coldain Rings, Kael/ToV/ST access, Halls of
Testing) that does NOT cross over into epic dependency. Implication:
Velious raid-scaling can proceed independently of epic-related
tuning decisions.

**2. The Coldain Ring 10 "Ring War" is the single most structurally
difficult Velious quest event for small groups.**
- Script file exists: `akk-stack/server/quests/greatdivide/encounters/ring_war.lua`
- Event structure: 3 rounds × 7 waves = **21 waves** before final boss (Narandi) spawns
- Wave composition includes Kromrif Generals (13k HP), Warriors,
  Veterans (42.5k HP), Warlords (20k HP), and High Priests of Zek
  (50k HP each). Cumulative wave HP exceeds 500k+ per round.
- **Scaling Narandi alone does NOT solve this — the waves gate the
  encounter.** A 1-player + 5-companion group at current small-group
  DPS throughput cannot sustain enough damage to clear 21 waves in
  the event's time window.
- **Failure cascades** if dwarf NPC armies are killed by wave mobs.
- **Architect must investigate the ring_war.lua script** to
  determine: (a) are wave counts hardcoded? (b) can wave-mob HP be
  reduced for small-group play without breaking event triggers?
  (c) is the 30-minute timer hardcoded? This is a script-level
  problem, not a boss-stat problem.

**3. Ring 8 failure resets entire ring chain (Rings 1-7) to zero.**
Chief Ry`Gorr 4-minute kill window during the fort-war event. Miss
it and restart from Ring 1. **Critical UX concern for small group
— this is punishing for a solo player.** Architect may want to
flag the failure-reset behavior for user decision (accept-as-is
vs. soften reset to "try again" without full chain restart).

**4. Three-faction mutual-exclusivity constraint.** Coldain vs
Kromzek (Kael) vs Claws of Veeshan (Skyshrine/ToV). Player can
fully ally at most 2 of 3. Implications for small-group server:
- Coldain Ring chain REQUIRES Coldain faction (hostile to Kael)
- Thurgadin armor chain REQUIRES Coldain
- Halls of Testing REQUIRES Claws of Veeshan (hostile to Coldain raiding)
- Avatar of War / Kael progression neutral-to-hostile to CoV
- **No small group can pursue ALL Velious quest chains on one
  character** without faction-reset GM interventions. This is
  lore-canonical (Velious was designed as faction-warfare content).
  Flag for user: preserve as-is, or soften via faction items?

**5. Sleeper's Tomb key — every path requires a raid boss kill.**
Six distinct key paths (Sontalak, Lendiniara, Klandicar, Yelinak,
Zlandicar, or Shard of Hsagra from Kael bosses) — ALL are raid
tier. There is no non-raid path to the Sleeper's Tomb. Additionally,
**awakening the Sleeper is a permanent server state change** —
once the 4 Warders are killed, Kerafyrm rampages through Velious
zones and cannot be undone without GM intervention. Lore flag for
user (open question #10 already captures this).

**6. Boss catalog addenda for Velious quest-critical encounters:**

- **Idol of Rallos Zek (id 113341, L66, 650,000 HP, raid_target=1,
  SERTMCNIDf)** — MISSING from Velious boss catalog. Central link
  in Kael Avatar of War spawn chain: Statue (113071) → Idol (113341)
  → Avatar of War (113457). Without Idol scaled, the Avatar chain
  is broken. **Add to Velious boss catalog at ~25x gap, recommend
  HP cut to 130k (-80%), damage cut to 200-700 (-37%), respawn 12h.**
- **Statue of Rallos Zek (id 113071, L59, 400,750 HP)** — already
  in catalog; re-flagged as Kael spawn-chain prerequisite.
- **Avatar of War (id 113457, L70, 900,000 HP)** — already in
  catalog. **Note:** community sources (Allakhazam, P99) state 1.7M
  HP — this reflects live-server post-PoP values. PEQ db value of
  900k is authoritative and already matches the boss catalog.
- **Doldigun Steinwielder** exists as 2 IDs: 113440 (L55 2,500 HP
  standard) and 113508 (L60 6,250 HP `#` variant, likely Ring 9
  traitor target). Low HP, not boss-tier. No catalog update needed.
- **Peffin Ambersnow** (id 116107, L50, 6,000 HP) — only 6k HP,
  not raid-tier. Difficulty is the invisible + 5-perma-rooted-guards
  mechanic, NOT boss stats. Scaling can't fix this; architect to
  review the guard-spawn script if small-group accessibility is
  desired.
- **Sontalak / Klandicar (97.5k HP) / Zlandicar (110k HP)** — all
  already in Velious boss catalog. HP values are significantly
  LOWER than lore-master's community-source estimates (200-300k).
  **PEQ has already pre-scaled these dragons** — they are closer
  to mid-boss tier than endgame. Current audit recommendations
  (cut 59-68% to ~35-45k) still apply.

**7. Dragon Necropolis (DN) new intel:**
- **Jaled Dar's shade (id 123011, L70, 3,002,000 HP, dmg 250-900)**
  is the Sleeper's Tomb key turn-in NPC at Necropolis coords
  +1590, -120. My boss catalog flagged this as "SPECIAL — probably
  event-timer mob, investigate" — lore-master confirms he's the
  **quest-turn-in NPC**, not a kill target. Don't scale him down;
  leave the 3M HP as "uncombattable" design (turn-in only). Remove
  his scaling-target tag from any implementation UPDATE.

**8. Halls of Testing = the Dozekar/Lendiniara/Gozzrem/Telkorenar
quest hub** — all ToV bosses already in boss catalog. The quest
structure adds: these fights need to happen MULTIPLE times per
player because gem drops are unpredictable. Architect: ensure
respawn cut is aggressive enough (12h per boss catalog) to allow
realistic multi-clear sessions.

**9. ToV Key clarification — zone entry is UNKEYED.** Entry is
at Western Wastes (+700, +700) behind Sontalak. Level 46+ check.
Items called "Key of Veeshan" dropping from King Tormax / Yelinak /
Dain Frostreaver IV are for internal ToV progression (mold access,
Halls of Testing pre-reqs), not for zone entry. **Architect:
verify in DB whether any quest script actually enforces an internal
ToV key check, or if the "keys" are just armor-mold quest items.**

**10. Kael Thurgadin armor molds conflict:** Coldain-aligned players
need molds from the King Tormax area of Kael — but as Coldain
allies, they are hostile to Kromzek. Mold farming becomes a sneak-
in-kill-sneak-out operation. Expected but worth documenting.

**Velious pain-score distribution (7 quest chains):**
- **RED:** Coldain Ring 10 War Event, Halls of Testing, Sleeper's
  Tomb Key, Avatar of War chain, all Warder-related content. **5 of 7.**
- **YELLOW:** Ring 4-9 individual steps (progression reset risk),
  Kael King Tormax + Derakor, Skyshrine armor chain. **2 of 7.**
- **GREEN:** Rings 1-3, Sebilis-parallel simple turn-ins. None of
  the raid-tier chains are GREEN.

**Velious needs architect-level script review beyond boss-stats
alone:**
- `akk-stack/server/quests/greatdivide/encounters/ring_war.lua` (Ring 10 wave structure)
- `akk-stack/server/quests/eastwastes/#Peffin_Ambersnow.pl` (guard spawn mechanic for Ring 9)
- `akk-stack/server/quests/kael/` (Avatar of War spawn chain trigger logic)
- Ring 8 fort-war trigger scripts (failure-reset behavior)

---

#### Full Velious catalog

See `lore-master/velious-chains.md` for complete walkthrough of
Coldain Rings 1-10, Kael raid progression, ToV access and Halls
of Testing, Sleeper's Tomb key, faction system, and cross-reference
matrix.

---

#### (Preserved: Game-designer's original Velious fallback summary, now superseded by lore-master catalog above)

**Scope:** Velious is the single most faction-intensive expansion.
Raid-quest progression covers: Coldain Ring War (10-ring quest +
Prayer Shawl + Shawl 8), Ring of Scale / Claws of Veeshan faction
progression (for Kael/ToV/Skyshrine access), ToV key quest, Sleeper's
Tomb key quest (multi-raid), plus Velious-phase steps of Epic 1.0s
that extend into this era (mainly Warrior, Paladin, SK).

---

#### Coldain Ring War (+ Shawl 8 + Prayer Shawl)

- **Class/scope:** General faction access to Coldain-friendly paths;
  Thurgadin access; prereq for ToV key for many players; Shaman
  Epic 1.0 late steps; class-neutral rewards
- **Era:** Velious
- **Zones:** The Great Divide, Icewell Keep (`thurgadinb`), Eastern
  Wastes
- **Turn-in NPCs:** Dain Frostreaver IV (thurgadinb, 129003)
- **Raid encounters required:**
  - Coldain Shawl 8 requires the **Coldain Prayer Shawl event** —
    a triggered multi-wave event defending Coldain against a
    Kromrif giant invasion
  - Ring War itself is a 10-ring quest chain ending in a full raid
    event — typically 20-40 player
- **Non-encounter blockers:**
  - Requires Ring 5 reward (for Ring War participation eligibility)
  - Progressive Coldain faction — hours of giant kills
- **Small-group blockers:**
  - The Prayer Shawl event has mechanic-scripted add waves that
    may be tuned for raid-size groups. Needs verification.
  - Ring War's final event scripts spawn 30+ giants; small group
    with companions may or may not handle this — event script
    review required
- **Recommended action:**
  - Audit covers Dain Frostreaver IV stats (HP → 80k).
  - **Critical:** architect should review
    `akk-stack/server/quests/thurgadina/` and
    `akk-stack/server/quests/thurgadinb/` for Ring War + Prayer
    Shawl event scripts. If wave-count is hard-coded, may need
    reduction or adaptive scaling for small group.
  - Flag to user: Coldain Ring War is traditionally a guild-
    defining event — may warrant keeping at high difficulty even
    for 1-3 players (wishful-rewarding challenge).

#### Thurgadin / Kael / Skyshrine faction access

- **Class/scope:** General raid access; required for Kael (AoW,
  Tormax), ToV (all 16+ dragon lords), Skyshrine (Yelinak,
  Crusaders)
- **Era:** Velious
- **Zones:** Great Divide, Eastern Wastes, Kael, Skyshrine, Western
  Wastes
- **Non-encounter blockers:**
  - Coldain / Claws of Veeshan / Ring of Scale faction grinds
  - Class-race restrictions (some classes can't get positive faction
    with both Kael and Skyshrine simultaneously)
- **Recommended action:**
  - Audit boss-catalog covers stats.
  - **Critical:** user decision needed on faction-grind time for
    small group. Current Velious faction grinds are weeks of
    outdoor-giant killing — considerably longer for solo than
    6-player group because kill rate is much lower. Consider
    prior-pass's `Zone:GlobalLootMultiplier=2` helping faction
    hit rates (already live).

#### Claws of Veeshan faction access (ToV + Skyshrine)

**CORRECTED 2026-04-22 per lore-master review.** There is NO "ToV key
quest" — the game-designer's original entry was a factual error.
Temple of Veeshan entry is **open to any L46+ character with Claws
of Veeshan faction**; no key item, no turn-in NPC, no quest chain
gates entry. The references to "keys dropping from Tormax/Yelinak/
Dain" in community sources describe **Sleeper's Tomb key talismans**,
not ToV entry keys — those dragons drop Shard of Hsagra's Talisman
(alternate path to Sleeper's Tomb key), not a ToV key.

- **Class/scope:** General access to ToV (for Halls of Testing quest
  chain) and Skyshrine. Factional gate, not a key quest.
- **Era:** Velious
- **Zones:** Skyshrine, Temple of Veeshan, Western Wastes, Eastern
  Wastes (for CoV faction grinding)
- **Access mechanism:** Positive Claws of Veeshan faction required to
  survive ToV West Wing and Skyshrine. CoV faction is earned by:
  killing Kromrif giants (Eastern Wastes, Kael), killing Ring of Scale
  dragons (Western Wastes, per Velious lore — note this is the
  Velious "Ring of Scale" dragon faction, not the post-Luclin PoP
  faction), and CoV-related quest turn-ins.
- **Non-encounter blockers:** Faction grind time — may be tens of hours
  for a small-group player to go from neutral to Ally CoV. Additionally,
  CoV faction is mutually exclusive with full Coldain and Kromzek
  alliances (3-way faction constraint).
- **Small-group blockers:** No raid kill required for ToV entry. Main
  blocker is faction-grind time. Halls of Testing quest chain inside
  ToV East Wing requires killing Dozekar the Cursed and named drakes —
  those are raid-tier and covered by boss-catalog scaling.
- **Recommended action:** No change needed for ToV entry (no key to
  modify). Architect to flag faction-grind time as a user decision
  (accept as-is, or accelerate via turn-in item changes).

#### Sleeper's Tomb key quest _(verified 2026-04-22 per lore-master review)_

- **Class/scope:** Sleeper's Tomb access; prereq for 4-Warder
  events and the Sleeper-awake event
- **Era:** Velious
- **Turn-in NPC:** Jaled Dar's shade (Dragon Necropolis, id 123011 —
  see boss-catalog addenda: intentional 3M HP uncombattable
  quest-NPC, NOT a kill target)
- **Raid encounters required:** ONE talisman from any of the First
  Brood dragons, OR Shard of Hsagra's Talisman combined from multiple
  Kael sources:
  - **Klandicar** (Western Wastes, id 120084, 97.5k HP → 40k
    post-audit) — lowest-HP-gap path, recommended for small group
  - **Sontalak** (Western Wastes, id 120005, 97.5k HP → 40k
    post-audit) — tied for lowest-gap path
  - **Zlandicar** (Dragon Necropolis, id 123115, 110k HP → 35k
    post-audit) — also low-gap
  - **Lord Yelinak** (Skyshrine, id 114106, 500k HP → 110k
    post-audit) — requires CoV faction for approach
  - **Lendiniara the Keeper** (Temple of Veeshan, id 124020, 320k
    HP → 80k post-audit) — requires CoV faction for ToV entry
  - **Shard of Hsagra's Talisman** (alt path) — from Derakor the
    Vindicator, King Tormax, Statue of Rallos Zek (all Kael), OR
    Velketor the Sorcerer (velketor zone)
- **Progression path:** Kill ONE eligible dragon → talisman → turn
  in to Jaled Dar's shade → Key of Sleeper's Tomb. NO multi-kill
  requirement.
- **Small-group blockers:** None beyond standard raid-boss scaling
  for whichever path is chosen. The recommended minimum-pain path
  (Klandicar or Sontalak at ~40k HP post-audit) is tractable for
  1 player + 5 companions.
  - Sleeper's Tomb inner-guard mechanic (if any)
- **Recommended action:** Boss scaling + lore-master to verify
  which ToV bosses specifically drop key.

#### Coldain Prayer Shawl + Tranquil Staff (class-specific Velious raid quests)

- **Class/scope:** Cleric/Druid/Shaman have late-epic enhancement
  quests using Coldain Shawl chain for items like Tranquil Staff;
  Bard has Velious-specific quest items
- Velious-specific epic-enhancement paths exist for
  Druid/Shaman/Ranger — typically involve Coldain faction turn-ins
- **Recommended action:** Check quest scripts for hard turn-in
  gates that require 6-player check-sums (ancient cases where a
  "place item X, kill mob Y simultaneously" mechanic exists).

#### Avatar of War / Kael Arena progression _(corrected 2026-04-22 per lore-master review)_

- **Class/scope:** General Velious raid access / endgame loot (NOT a
  class-epic requirement — Warrior, Paladin, and SK epics all complete
  in Classic + Kunark and do NOT require AoW).
- **Zones:** Kael Drakkel arena
- **Spawn chain:** Statue of Rallos Zek (113071) → kill spawns Idol
  of Rallos Zek (113341) → kill spawns Avatar of War (113457). All
  three are in the boss catalog.
- **Small-group blockers:** AoW at 900k HP + rampage 6×6 = current
  wall. Audit recommends 87% HP cut + rampage 3×3.
- **Recommended action:** Addressed by boss-catalog scaling. No
  quest-chain obligation to kill — skip if the small group prefers
  other Kael content (King Tormax, Derakor, Thurgadin armor molds).

---

#### Velious-phase of Epic 1.0

Most Epic 1.0s COMPLETE in Kunark or have their Velious steps as
quality-of-life rewards (not raid-tier). The Velious-required raid
steps are specific:

**Warrior Epic 1.0 — Jagged Blade of War** — **NO Velious step** _(corrected 2026-04-22 per lore-master review)_
- Warrior epic completes fully in Classic + Kunark. No Avatar of War
  dependency. No Ring of Scale dependency. Remove from AoW + Vindicator
  dependent-chain lists in the dependency matrix.

**Paladin Epic 1.0 — Fiery Defender** — **NO Velious step** _(corrected 2026-04-22 per lore-master review)_
- Paladin epic completes fully in Classic (Lhranc in City of Mist +
  Thought Destroyer in Plane of Hate + Keeper of the Tombs in The Hole
  + Kirak Vil in Nektulos Forest). No Avatar of War dependency.
  Remove from AoW dependent-chain lists.

**Shadow Knight Epic 1.0 — Innoruuk's Curse** — **NO Velious step** _(corrected 2026-04-22 per lore-master review)_
- SK epic completes fully in Classic + Kunark (Cazic-Thule/Dread/
  Fright/Terror in PoFear for Soul Leech + Lhranc in City of Mist for
  Innoruuk's Curse final + Ashenbone Drake in PoHate for Decrepit Hide).
  No ToV dragon dependency. No Aaryonar or Dozekar requirement.
  Remove from AoW / Aaryonar / Dozekar dependent-chain lists.

**Druid / Shaman / Cleric Velious enhancement paths**
- Late-epic class-specific enhancement via Coldain Prayer Shawl
  chain — generally no raid-tier kill, faction-only

---

#### Velious quest chain summary

- **Velious is the most progression-complex era.** Three distinct
  access chains (Thurgadin/Kael/Skyshrine faction), three distinct
  key quests (ToV, Sleeper's, Veeshan's Peak if counted as
  Kunark-Velious hybrid), and an iconic Ring War event.
- **Faction grinds are the biggest small-group friction point** —
  not boss stats. A solo player grinding Coldain faction from
  neutral takes many hours of frost-giant-kill cycles in Great
  Divide. The prior-pass's `GlobalLootMultiplier=2` helps
  moderately but doesn't fundamentally change the time-wall.
- **Ring War event is the single most scripted raid event** in
  in-era content. Architect MUST audit the Ring War script
  (`akk-stack/server/quests/thurgadina/` or `eastwastes/`) for
  hard-coded wave counts and small-group viability. May require
  companion-count adaptive scaling.
- **Shared-dependency bosses across multiple Velious chains:**
  - **Avatar of War (kael, 113457):** Warrior + Paladin + SK Epic +
    ToV key component (for some chains)
  - **King Tormax (kael, 113215):** ToV key + Coldain faction
    progression nemesis
  - **Dain Frostreaver IV (thurgadinb, 129003):** Coldain Ring War
    quest giver + Shawl 8 + Prayer Shawl
  - **Aaryonar + Dozekar (ToV):** Sleeper's Tomb key + SK/Paladin
    epic components (for some chains)

**Velious quest-chain blockers BEYOND boss-stat scaling:**
- Faction grind time — needs user decision
- Ring War + Prayer Shawl event scripts — architect script review required
- Possible hard-coded "kill count" checks in Velious scripts that
  assume raid group size

---

## Luclin (expansion 3)

### Luclin raid boss catalog

**Summary:** Luclin is mechanically the "endgame wall" of the in-era
scope. True-boss HP pools are the largest in the game — several bosses
exceed 1 million HP, peaking at Aten Ha Ra at 1,901,500 HP. The
Luclin raid landscape has four distinct clusters:

- **Vex Thal (vexthal):** 9 top-tier bosses (Aten Ha Ra line, Diabo
  trio, Thall Va tier), plus ~80 mid-elite Yaemiu mobs (55-100k HP —
  "elite trash" in scale, out of boss-scope). **The densest raid cluster
  in the game.**
- **Ssraeshza Temple (ssratemple):** Emperor Ssraeshza + High Priest of
  Ssraeshza + Xerkizh the Creator (trio of 806k-1.25M HP bosses), plus
  multiple Rhag-named mid bosses (Arch Lich Rhag`Zadune, Rhag`Zhezum,
  Rhag`Mozdezh), plus Taskmaster tier (6 at 50k HP — elite named).
- **Akheva Ruins (akheva):** Vyzh`dra the Cursed (900k), The Itraer
  Vius (601k), Shar Vinitras (460.9k), Shei Vinitras (400k), The
  Insanity Crawler (401k), The Va`Dyn (250k), Xaui Tatrua (70k).
- **Sanctus Seru (sseru) + Katta Castellum (katta):** Lord Inquisitor
  Seru (1.2M) + 4 Praesertum (150-250k), Lcea Katta (401k), Nathyn
  Illuminious (430k) — the Seru/Katta faction-war bosses.
- **Other zones:** Grieg's End (Grieg Veneficus 475k + 2 others),
  Acrylia Caverns (evolved burrower 300k), The Deep (Thought Horror
  Overfiend 807k), Umbral Plains (Zelnithak 251k, Rumblecrush 150k,
  Netherbian Swarmfiend 600k — but this is L73 OOE), Echo Caverns
  (General Blaystich 60k — edge case).

**In-era true-boss count:** ~25-30 encounters. Excluding OOE and
event mobs, the target count is ~25 bosses + ~5 quest/event triggers.

**Scaling gap overview:** Luclin is where the gap is extreme AND
where the signature feature has the greatest user impact. Aten Ha Ra
at 1.9M HP is **63× scaled-named at L66 (30k)** — the single largest
gap in the game. Even mid-tier Vex Thal bosses at 1-1.5M HP are
35-50×. On the optimistic end, Rumblecrush and Zelnithak (150-250k)
are 5-8× — manageable.

**Damage outliers:** Vex Thal top-tier damage max values: Aten Ha Ra
1,054, Kaas Thox Xi Aten Ha Ra 1,650, Diabo Xi Va Temariel 1,400,
Va Xi Aten Ha Ra 1,254, Thall Va Kelun 1,000, Diabo Xi Xin 1,200.
Emperor Ssraeshza 904 max. Lord Inquisitor Seru 915 max. These are
one-shot danger values for small-group tanks at current tuning.

**Progression context (to be fleshed by lore-master in Task #10):**
Vex Thal is the single most progression-locked zone in the game.
Entry requires **the 10-shard-plus-Emperor Vex Thal key quest (see lore-master correction)**, with shards
dropping from almost every other Luclin raid boss. Scaling Luclin
without addressing the VT key blockers will not unblock VT for a
small group. Emperor Ssraeshza key is similarly multi-raid gated.

---

### Vex Thal — vexthal (9 top-tier bosses)

| Boss | ID | L | HP | dmg | Abilities | Respawn | Recommended HP |
|------|----|----|-----|-----|-----------|---------|----------------|
| Aten Ha Ra (main) | 158096 | 66 | 1,901,500 | 294-1,054 | SERTQMCNIDf | 468,720s (130h) | **180k (-91%)**, respawn 24h |
| Aten Ha Ra (variant) | 158006 | 66 | 1,901,500 | 294-1,054 | (same) | — | Duplicate — flag for user |
| Kaas Thox Xi Aten Ha Ra | 158007 | 66 | 1,900,000 | 320-1,650 | SERQMCNIDf | 468,720s | **160k (-92%)** + damage trim 50% (max 800) |
| Thall Va Kelun | 158008 | 66 | 1,825,000 | 240-1,000 | SRQMCNIDf | 468,720s | **150k (-92%)** + damage trim 40% (max 600) |
| Diabo Xi Va Temariel | 158010 | 66 | 1,706,000 | 165-1,400 | SRFMCNIDf | 468,720s | **140k (-92%)** + damage trim 45% (max 770) |
| Va Xi Aten Ha Ra | 158009 | 66 | 1,601,500 | 304-1,254 | SERQMCNIDf | 468,720s | **130k (-92%)** + damage trim 40% (max 750) |
| Diabo Xi Xin Thall | 158012 | 66 | 1,501,500 | 180-750 | SRTMCNIDfU | 468,720s | **125k (-92%)** damage ok |
| Thall Xundraux Diabo | 158011 | 66 | 1,475,000 | 274-654 | SERFQUMCNIDf | 468,720s | **120k (-92%)** damage ok |
| Kaas Thox Xi Ans Dyek | 158013 | 66 | 1,201,500 | 270-650 | SEFQUMCNIDf | 468,720s | **100k (-92%)** damage ok |
| Diabo Xi Xin | 158015 | 66 | 1,106,500 | 250-1,200 | SERMCNIDf | 468,720s | **90k (-92%)** + damage trim 45% (max 650) |
| Diabo Xi Va | 158014 | 66 | 1,050,000 | 274-654 | SRFUMCNIDf | 468,720s | **85k (-92%)** damage ok |
| Thall Va Xakra (2 copies) | 158016/125 | 60 | 900,000 | 285-950 | SERMCNIDf | 140,616s (39h) | **80k (-91%)** + damage trim 25% (max 700) |
| Va Dyn Khar | 158081 | 66 | 600,000 | 265-455 | SEMCNIf | 21,600s | **60k (-90%)**, respawn already short |

**Vex Thal + Yaemiu elite trash:** ~80 Yaemiu-pattern mobs at
55-100k HP (naming patterns: Eom / Pli / Zov / Qua / Zun / Kaas / Thall
with suffixes like Liako, Senshali, Centien, Thall, Va, Zethon,
Xakra). These are elite-trash (not boss-tier), but at 55-100k HP they
represent the **toughest elite named tier in the game**. Out of
scope per brief (brief says "named difficulty feels good"), but the
user should be aware these will STILL be much harder than a scaled
L66 named — on a scaled-named baseline at L66 of ~30k HP, these
sit at 2-3x. **Flag for user:** does "trash/named already feels right"
include these Vex Thal Yaemiu mobs, or do they need scaling too?

**Vex Thal respawn:** All top-tier bosses at 468,720s (130h / 5.4
days) — MUST be reduced to 24h per brief. This alone makes VT vastly
more tractable for small group.

---

### Ssraeshza Temple — ssratemple

| Boss | ID | L | HP | dmg | Abilities | Respawn | Recommended |
|------|----|----|-----|-----|-----------|---------|-------------|
| Emperor Ssraeshza | 162227 | 66 | 1,250,500 | 283-904 | SERQMCNIDfWO | — (event-gated) | HP → 120k (-90%), damage trim 30% (max 620) |
| High Priest of Ssraeshza | 162076 | 66 | 941,000 | 277-722 | SERTUMCNIDf | 259,200s (72h) | HP → 90k (-90%), respawn 12h |
| Xerkizh the Creator | 162190 | 66 | 806,516 | 275-674 | STMCNDf | 259,200s | HP → 80k (-90%), respawn 12h |
| Arch Lich Rhag`Zadune | 162177 | 64 | 790,000 | 275-664 | SERUMCNIDf | — | HP → 75k (-90%), respawn 12h |
| Rhag`Mozdezh | 162192 | 63 | 226,000 | 270-574 | — | — | HP → 60k (-73%) |
| Rhag`Zhezum | 162178 | 63 | 201,000 | 168-310 | SERTUMCNIDf | 194,400s | HP → 55k (-73%), respawn 12h |
| General Kizuhx | 162066 | 53 | 250,000 | 168-510 | SERFUMCD | 1,080s (18m) | HP → 60k (-76%), respawn ok |
| Arbiter Korazhk | 162191 | 55 | 205,000 | 168-510 | UCDf | 1,080s | HP → 55k (-73%) |
| Advisor Zekuzh | 162067 | 53 | 150,000 | 163-410 | MCNIDfU | 1,080s | HP → 45k (-70%) |
| Rhozth Ssrakezh | 162258 | 60 | 119,000 | 142-523 | — | — | HP → 40k (-66%) |
| Rhozth Ssravizh | 162089 | 60 | 105,200 | 142-284 | — | — | HP → 38k (-64%) |
| 6× Taskmaster | 162011/13/21/24/59/60 | 60 | 50,200 | 142-454 | — | — | Already elite-named tier — minor trim or none |

**Ssraeshza progression:** Emperor Ssraeshza is the zone endboss.
Traditional access: kill High Priest to reveal key, then kill
Emperor. The Rhag lich line (Zadune top, Zhezum/Mozdezh below) is a
separate progression track — Rhag`Zadune is likely tied to Luclin
shard quest for VT key.

---

### Akheva Ruins — akheva

| Boss | ID | L | HP | dmg | Abilities | Respawn | Recommended |
|------|----|----|-----|-----|-----------|---------|-------------|
| Vyzh`dra the Cursed | 162206 | 66 | 900,000 | 271-588 | SFQMCNIDf | — | HP → 90k (-90%) |
| The Itraer Vius | 179037 | 63 | 601,000 | 220-600 | SERUMCNIDf | 210,924s (58h) | HP → 80k (-87%), respawn 12h |
| Shar Vinitras | 179134 | 63 | 460,900 | 250-1,010 | SETMCDf | 10,800s (3h) | HP → 70k (-85%), damage trim 40% (max 600), respawn fine |
| Shei Vinitras | 179157 | 65 | 400,000 | 145-400 | f | 194,474s | HP → 60k (-85%), respawn 12h |
| The Insanity Crawler | 179180 | 63 | 401,000 | 174-573 | SQCNDf | 210,924s | HP → 60k (-85%), respawn 12h |
| The Va`Dyn | 179178 | 63 | 250,000 | 240-525 | SEFQMCNIDf | 194,400s | HP → 50k (-80%), respawn 12h |
| Sheleric Vis | 179133 | 61 | 116,000 | 176-746 | — | — | HP → 40k (-66%), damage trim 20% |
| Xaui Tatrua | 179044 | 60 | 70,000 | 110-376 | f | — | HP trim 25% (→50k) |

**Akheva notes:** Vyzh`dra is likely split into "the Cursed" (main
boss, id 162206) and "the Exiled" variant — user decision. The
Itraer Vius is a major event boss. Note Vyzh`dra the Cursed is in
`ssratemple` zone space by ID but lore is Akheva — investigate. The
Insanity Crawler is likely the Nexus event (Shadowhaven connection).

---

### Sanctus Seru / Katta Castellum — sseru, katta

| Boss | ID | L | HP | dmg | Abilities | Respawn | Recommended |
|------|----|----|-----|-----|-----------|---------|-------------|
| Lord Inquisitor Seru | 159691 | 66 | 1,201,500 | 339-915 | SEFQMCNIDfO | 259,200s | HP → 120k (-90%), damage trim 30%, respawn 12h |
| Praesertum Vantorus | 159113 | 66 | 250,000 | 130-510 | SFQMCD | 259,200s | HP → 55k (-78%), respawn 12h |
| Praesertum Rhugol | 159112 | 66 | 200,000 | 125-500 | SQMCD | 259,200s | HP → 50k (-75%) |
| Praesertum Bikun | 159115 | 66 | 160,000 | 147-500 | SQMCD | 259,200s | HP → 45k (-72%) |
| Praesertum Matpa | 159114 | 66 | 150,000 | 147-418 | STMCD | 259,200s | HP → 45k (-70%) |
| Lcea Katta | 160375 | 60 | 401,200 | 238-827 | SQMCNDf | 258,750s | HP → 80k (-80%), damage trim 25% |
| Nathyn Illuminious | 160135 | 64 | 430,000 | 195-575 | f | 194,400s | HP → 80k (-81%), respawn 12h |

**Seru/Katta context:** Lord Inquisitor Seru is the final boss of
Sanctus Seru. Lcea Katta is the final boss of Katta Castellum —
these represent the two sides of a faction war (pro-Seru vs pro-
Katta citizens). Faction-gated — flag for lore-master Task #10.

**Note:** Bella Helsin (160177) and Heracus Helsin (160178) at L1
1M HP are **event-control NPCs** (likely rebellion-event triggers).
Skip scaling.

---

### Grieg's End — griegsend

| Boss | ID | L | HP | dmg | Notes |
|------|----|----|-----|-----|-------|
| Grieg Veneficus | 163075 | 65 | 475,500 | 214-632 | SQMCNDWf. Main boss. HP → 80k (-83%), respawn — |
| Servitor of Luclin | 163013 | 65 | 120,021 | 152-365 | HP → 40k (-67%) |
| Praetorian Myral | 163078 | 60 | 95,051 | 47-241 | HP → 35k (-63%), damage already low |
| a_shrouded_minion | 163051 | **75** | 200,875 | 529-2,049 | **OUT OF ERA (L75)** — LoN tier |
| an_ancient_necromantic_shade | 163052 | **80** | 1,007,200 | 666-2,509 | **OUT OF ERA (L80)** |

**Grieg's End warning:** Mixed era content — the shrouded minion /
necromantic shade are LoN-era anniversary additions. Filter to in-
era only.

---

### Other Luclin raids

| Boss | Zone | ID | L | HP | dmg | Recommended |
|------|------|----|----|-----|-----|-------------|
| Khati Sha the Twisted | grimling? | 154145 | 68 | 475,000 | 400-1,004 | HP → 90k (-81%), damage trim 25% |
| an evolved burrower | acrylia | 154142 | 63 | 300,750 | 200-693 | HP → 60k (-80%), respawn 27h (reduce) |
| Thought Horror Overfiend | thedeep | 164078 | 63 | 807,000 | 282-776 | HP → 90k (-89%), respawn 12h |
| Zelnithak | umbral | 176089 | 60 | 251,000 | 115-400 | HP → 60k (-76%), damage fine |
| Rumblecrush | umbral | 176002 | 66 | 150,000 | 226-720 | HP → 45k (-70%), damage trim 20% |
| #Netherbian Swarmfiend | umbral | 176111 | **73** | 600,000 | 370-1,700 | **OUT OF ERA (L73)** |
| General Jared Blaystich | echo | 153095 | 55 | 60,000 | 78-254 | Already elite-named. Minor trim or none. |

**Umbral Keymaster (176110)** at L1 / 99,999,999 HP / dmg 7,999-10,003
is an **event-control NPC** (likely instance key gate). Skip scaling.

**Arena training dummy / cshome "Five/Ten/…/One_Hundred_Fifty"
style dummies / ssratemple `keycheck` (162269) at 999,999,999 HP**
are all **GM test rigs or instance gates**. Skip.

**Fabled-filtered:** 8 `#The_Fabled_*` NPCs across Luclin zones are
OUT OF ERA and excluded from this audit.

---

### Luclin boss catalog — summary table (high-level only)

| Cluster | True-boss count | HP range | Gap range | Priority |
|---------|-----------------|----------|-----------|----------|
| Vex Thal top-tier | 9-11 | 900k-1.9M | 30-63× | **Highest** |
| Vex Thal Yaemiu elite | ~80 (trash) | 55-100k | 2-3× | Flag for user |
| Ssraeshza Temple | 6 | 790k-1.25M | 25-42× | High |
| Ssraeshza Temple mid | ~12 | 50-250k | 2-8× | Medium |
| Akheva Ruins | 6-8 | 250-900k | 8-30× | High |
| Sanctus Seru + Katta | 6-7 | 150k-1.2M | 5-40× | High |
| Grieg's End (in-era) | 3 | 95-475k | 3-16× | Medium |
| Umbral / Acrylia / Deep | 4 | 150-807k | 5-27× | Medium |

**Luclin total in-era true bosses:** ~30 (excluding Yaemiu elite
tier which is arguable). Aggregate HP reduction target: 80-92% for
top bosses, 65-80% for mid-bosses.

**Luclin scaling-gap summary:** Luclin is the end-of-era wall and
has the widest top-end gap (Aten Ha Ra at 63× scaled-named). If
Phase 2-5 proceed serially, Luclin (Phase 5) will carry the most
tuning complexity. Companion-system-reliant: small-group Luclin
raids absolutely depend on the companion system functioning cleanly
since boss scripts (Aten adds, Emperor's guards, Seru's Inquisition)
feature heavy add-phases that were designed against 72-player raids.

**Strong recommendation for user decision:** Luclin alone justifies
splitting Phase 5 into Phase 5a (Ssraeshza + Akheva + Seru/Katta +
outdoor — ~18 bosses) and Phase 5b (Vex Thal — 9-11 top-tier + key-
progression rework). Vex Thal's 10-shard key quest (lore-master
Task #10) is a progression-phase of its own.

### Luclin raid quest chains

> **Status:** Lore-master's canonical catalog delivered 2026-04-22. See
> full walkthrough at
> `/mnt/d/Dev/eq/claude/project-work/feature-raid-scaling/lore-master/luclin-chains.md`.
> This section summarizes lore-master's findings and highlights
> project-critical additions for the architect. The game-designer's
> original fallback (preserved below) is SUPERSEDED where it conflicts.
> **This completes all four era quest-chain catalogs (tasks #7-10).**

#### Key project-critical findings from lore-master Luclin review

**1. The Vex Thal key is NOT a 10-shard + 3-component quest — it's a 10-shard
quest PLUS Emperor Ssraeshza + a Luclin raid kill.** My boss-catalog
summary (and the prior pass's reference) described VT key as "13
shards from various Luclin raid targets." Lore-master's canonical
research corrects this:
- **Phase 1: 10 Lucid Shards** from non-raid mobs across 10 Luclin
  zones (Acrylia, Akheva, Dawnshroud, Fungus Grove, Maiden's Eye,
  Katta/Seru, Scarlet Desert, Ssraeshza Temple outer, The Grey, The
  Deep) — GREEN/YELLOW tier, all accessible to a small group.
- **Phase 2: Shadowed Scepter Frame** from an Akheva Ruins Sacrificed
  Remains → shimmering presence → Spirit of Akelha`Ra chain — YELLOW
  tier, requires Magician (Wisp Stone) + Necromancer (Essence Emerald)
  or purchased equivalents.
- **Phase 3: Planes Rift** from Emperor Ssraeshza kill — RED.
- **Phase 4: Glowing Orb of Luclinite** from any Luclin raid boss
  kill — RED.
**Good news for Open Question #7** (VT shard-count reduction): the
actual shard-collection phase is already accessible without raid.
The RED blockers are Emperor Ssraeshza + any Luclin raid boss —
which are covered by the boss-catalog scaling. The VT key "shard
reduction" question may be moot; the architect should not need to
touch the shard count.

**2. CRITICAL: Cross-era gate — Vulak`Aerr blocks ALL advanced
Luclin content.** The Key to Luclin (for entering Ssraeshza Temple,
The Grey, Akheva, Vex Thal, Fungus Grove, Grimling Forest, The Deep,
Grieg's End, Umbral Plains) requires killing Vulak`Aerr in Temple of
Veeshan (Velious). This is a **hard-wired cross-era progression
gate**:

```
Velious ToV completion (Vulak`Aerr kill at 890k HP)
  → Key to Luclin
  → Advanced Luclin zones become accessible
  → Emperor Ssraeshza + Aten Ha Ra + VT key completion
  → Vex Thal endgame
```

**Phased-delivery implication (affects Open Question #A — phased
strategy):** Luclin cannot be a standalone phase. If the user splits
into per-era phases, Velious ToV work MUST precede any meaningful
Luclin work — even the outer shard-collection chain. This argues for:
- **Phase 4b must include Vulak`Aerr** scaling, not just ToV trash-tier
- **Phase 5 Luclin is downstream of Phase 4b**, not independent
- Alternatively: architect investigates whether the Key to Luclin
  requirement can be lifted or alternate-sourced on small-group
  server (e.g. purchased from a Shadow Haven vendor as some classic-
  era PEQ versions allow).

**3. Luclin has NO Epic 1.0 dependencies.** Consistent with Velious
finding — all 14 class Epic 1.0 chains complete in Classic + Kunark.
Luclin scaling can proceed without Epic tuning coordination.

**4. Ssraeshza Temple Ring of the Shissar quest is small-group
accessible (NEW intel — reduces Luclin scope).** My original boss-
catalog flagged Emperor Ssraeshza and his pre-Emperor area as raid
tier. Lore-master confirms:
- **Commanders Zazuzh (id 162150, L56, 9k HP) + Zherozsh (162217,
  L58, 9k HP)** are script-spawned boss-style NPCs but at 9k HP each
  — already scaled-named tier. **No scaling action needed.** Both
  drop guaranteed door-keys (internal progression).
- **Warden Mekuzh (162023, L60, 33k HP)** is the Taskmaster's Pouch
  source — elite-named tier.
- **Pre-Emperor named (Advisor Zekuzh 162067, Arbiter Korazhk
  162191, General Kizuhx 162066)** are in my boss catalog already
  at 150-250k HP with 1,080s (18m) respawn — 2-group tier.
- Ring of the Shissar itself does NOT require Emperor Ssraeshza kill
  — only the door-key Commanders + pre-Emperor tier. **Small group
  can complete Ring quest without hitting the Emperor raid wall.**
  They must hit Emperor only for VT key progression.

**5. Grimling War event (Acrylia Caverns) is a wave-based gate
similar to Coldain Ring 10.**
- Triggered by Spiritist Kama Resan (id 154052, L60, 5.6k HP) after
  clearing the cage room
- Three progressively harder quest events with grimling waves
- Reward: Hollow Acrylia Obelisk → Inner Acrylia Caverns access
- **Architect flag:** lore-master notes "a later patch removed the
  key requirement on some servers." Architect must verify PEQ state:
  is the Obelisk still required, or is Inner Acrylia freely
  accessible? If still required, this is a second wave-event
  script-level problem (like Ring War) beyond boss-stat scaling.
- **Silver lining:** 3 inner Acrylia raids (Ring of Fire, Vah Shir
  Captive, Burrower) are key-free regardless. Small group can hit
  those directly.

**6. Grieg's End is the "easiest Luclin raid zone."**
- Grieg's Key drops from random named (5 of them identified by
  lore-master) — no quest chain, just camping rotation
- **Servitor of Luclin (id 163013, L65, 120k HP)** described as
  "easiest Luclin raid boss, no special abilities" — my boss catalog
  already covers this at HP cut ~67% → 40k.
- **Grieg Veneficus (id 163075, 475k HP)** is the zone-end target.
- **Phase 5 implementation priority:** start with Grieg's End as the
  "warm-up Luclin raid" before Ssraeshza/Akheva/VT. It has the
  simplest mechanics.

**7. Umbral Plains has no key gate but hosts Doomshade and other
raid-tier mobs.** Doomshade was NOT in my Luclin boss catalog —
let me check the db to confirm. My catalog listed Zelnithak (176089,
251k HP) and Rumblecrush (176002, 150k HP) as Umbral bosses. If
Doomshade exists as a separate entity, architect addendum needed.

**8. Luclin pain-score distribution (5 quest chains):**
- **RED:** VT key (Emperor + raid boss requirement), Umbral Plains
  Doomshade+ content, cross-era Vulak`Aerr gate. **3 of 5 quest chains.**
- **YELLOW:** Ring of the Shissar, Grimling War, Grieg's End key.
  **3 of 5.** (overlap because Ring of Shissar leads to VT key's
  Emperor step)
- **GREEN:** VT key Phase 1 (shard collection, taken standalone).

**9. Boss catalog amendments for Luclin quest-critical encounters:**
- **Commander Zazuzh (162150, L56, 9k HP)** — already scaled-named
  tier; audit addition for completeness.
- **Commander Zherozsh (162217, L58, 9k HP)** — same.
- **Spiritist Kama Resan (154052, L60, 5.6k HP)** — non-combat quest
  trigger NPC; NOT a scaling target.
- **Warden Mekuzh (162023, L60, 33k HP)** — elite named; minor HP
  trim (10-20%) appropriate.
- **Sacrificed Remains / a shimmering presence / Spirit of Akelha`Ra**
  (Akheva) — script-spawned quest-chain NPCs; architect to verify
  IDs and whether they need scaling tweaks. Likely low HP.

**10. The three tiers of small-group accessibility (lore-master's
final synthesis):**

**Tier 1 — Small group accessible (GREEN/YELLOW), no scaling needed:**
- Sebilis key (Kunark) / VP key shards (Kunark, non-Trakanon)
- Coldain Rings 1-7 (Velious)
- VT key Phase 1 shards + Phase 2 Scepter Frame (Luclin)
- Ring of the Shissar quest (Luclin)
- Grieg's End key farming (Luclin)

**Tier 2 — Needs boss scaling to be accessible (RED → scaled):**
- All 14 Epic 1.0 weapons (Classic/Kunark bosses)
- VP key final: Trakanon (Kunark)
- Sleeper's Tomb key: First Brood dragon (Velious)
- VT key Phase 3-4: Emperor Ssraeshza + Luclin raid boss
- Cross-era gate: Vulak`Aerr (Velious ToV)

**Tier 3 — Structurally broken regardless of boss scaling:**
- Coldain Ring 10 Ring War (21-wave DPS gate)
- Grimling War event (wave gate, if Obelisk still required)
- Truespirit faction (Druid/Ranger/Shaman — linear non-repeatable)
- Keepers of the Art (3k Batwing turn-ins)
- Ring 8 failure-reset-to-Ring-1 mechanic

**Architect action items from the 4-era lore-master synthesis:**
1. Cross-era gate policy for Vulak`Aerr → Key to Luclin
2. Ring War script tunability (`ring_war.lua`)
3. Grimling War script tunability + Obelisk-requirement patch status
4. Ring 8 failure-reset UX decision
5. Truespirit + Keepers-of-the-Art faction-grind mitigation
6. VT key Phase 1 shard count verified as 10 (not 13) — my audit
   doc updates to reflect this.

---

#### Full Luclin catalog

See `lore-master/luclin-chains.md` for complete walkthrough of VT
key, Ssraeshza Temple Ring of the Shissar, Grimling War, Grieg's
End, Umbral Plains, cross-era gate analysis, and the 3-tier
synthesis summary for architect.

---

#### (Preserved: Game-designer's original Luclin fallback summary, now superseded by lore-master catalog above)

**Scope:** Vex Thal shard quest (10-shard + 3-component key quest — the densest
raid-progression in the game), Emperor Ssraeshza key quest, Sanctus
Seru / Katta Castellum progression, Luclin-specific class AA-
precursor quests, any Luclin-tier components of Epic 1.0s that
extend this late.

---

#### Vex Thal key quest (10 Lucid Shards + 3 components)

- **Class/scope:** General raid access — VT contains some of the
  best in-era loot and the Aten Ha Ra cluster
- **Era:** Luclin
- **Zones:** ALL Luclin raid zones + some mid-level Luclin zones
- **Turn-in NPCs:** Final key forge NPC (lore-master verify —
  traditionally in Shadow Haven or Umbral Plains)
- **Raid encounters required for key components (NOT shards — shards are non-raid named):**
  - Shard drops come from a mix of mid- and high-tier Luclin
    bosses. Traditional spread:
    1. Ssraeshza Temple component (requires Emperor-tier access)
    2. Akheva Ruins components (3-4 shards from Vyzh`dra, Itraer
       Vius, Shar Vinitras, Insanity Crawler)
    3. Grieg's End components (Grieg Veneficus shard)
    4. Sanctus Seru / Katta component (Lord Inquisitor Seru)
    5. Umbral Plains / Acrylia / The Deep components (Thought
       Horror, Rumblecrush, evolved burrower)
    6. Grimling Forest / other mid-Luclin shard sources
    7. Plus some mid-boss drops (Nathyn Illuminious,
       Praesertum, Zelnithak)
- **Non-encounter blockers:**
  - Emperor Ssraeshza key itself is a prereq for 1+ shard
  - Seru key is prereq for 1 shard
  - Faction requirements in Akheva / Sanctus Seru
- **Progression path:** VT key effectively requires completing
  most of Luclin's raid progression — it's the pinnacle gate
- **Small-group blockers:**
  - Every shard-dropping boss needs audit scaling applied
  - Multiple raid zones' faction access required
  - Travel / key-chain traversal time
- **Recommended action:**
  - Audit boss-catalog covers stats
  - **Critical:** architect to verify shard drop rates and quest
    script logic for small-group viability
  - Flag for user: VT key is the single biggest quest-chain
    blocker in the game — even post-scaling, 13 raid-tier boss
    kills across 8+ zones is a multi-session project. Consider
    whether to reduce the shard requirement (e.g. 6 of 13) for
    small-group server, or keep as "worthy endgame mountain".

#### Emperor Ssraeshza key quest

- **Class/scope:** Emperor Ssraeshza access
- **Era:** Luclin
- **Zones:** Ssraeshza Temple
- **Raid encounters required:**
  - **High Priest of Ssraeshza** kill (primary key trigger)
  - Possibly General Kizuhx + Xerkizh the Creator tier encounters
- **Progression path:** Clear Ssraeshza Temple outer tiers →
  High Priest → Emperor throne
- **Small-group blockers:** High Priest 941k HP + Xerkizh 807k HP
  at current stats are walls; audit 90% HP cuts make tractable
- **Recommended action:** Addressed by boss-catalog.

#### Sanctus Seru access (Lord Inquisitor Seru key)

- **Class/scope:** Sanctus Seru inner zone access
- **Era:** Luclin
- **Zones:** Katta Castellum, Sanctus Seru
- **Raid encounters required:**
  - Praesertum quartet (Vantorus, Rhugol, Bikun, Matpa) for
    traditional pre-Seru chain
  - Lord Inquisitor Seru (end boss)
- **Non-encounter blockers:** Faction requirements — players
  must side with Katta OR Seru (mutually exclusive)
- **Small-group blockers:** Seru at 1.2M HP is top-tier; audit
  90% cut makes tractable
- **Recommended action:** Boss-catalog + user decision on faction-
  lock mechanic (it's lore-central — probably preserve)

#### Luclin-phase Epic 1.0 and class AA-precursors

- Most Epic 1.0s complete in Kunark or Velious. Luclin-era
  Epic 1.0 extensions are rare but exist for a few classes:
  - **Beastlord** has a Classic-through-Luclin epic chain
    (Scion's Staff) that traverses multiple Luclin zones +
    raid targets including Khati Sha
  - Some "enhancement" quests for Bard/Druid use Luclin drops
- **Khati Sha the Twisted (154145)** in Grimling Forest is
  the specifically-named "Beastlord Epic" target
- **Recommended action:** Boss-catalog scaling covers Khati Sha;
  lore-master to verify Beastlord epic progression (we only
  verified raid target NPC stats, not quest script).

---

#### Luclin quest chain summary

- **Vex Thal shard quest is the project's single largest
  progression wall.** 13 required shards from multiple raid-tier
  bosses across 8+ zones. Even if every individual boss is
  scaled tractable (audit addresses this), the CUMULATIVE quest
  time is large for a small group.
- **Flag for user:** Should the Vex Thal key requirement be
  reduced (e.g. to 6-8 shards) for small-group play? This is a
  quest-script / data change (not boss-stat), and it's the
  single highest-impact small-group quality-of-life decision
  in the project. Lore-master to weigh in on lore-appropriateness
  of reducing shard count.
- **Emperor Ssraeshza key** is straightforward post-scaling.
- **Seru / Katta faction lock** is lore-canonical (pick a side) —
  should be preserved. Small group can complete either side.
- **Shared-dependency bosses across multiple Luclin chains:**
  - **High Priest of Ssraeshza (ssratemple, 162076):** Emperor
    key + possibly 1 VT shard
  - **Vyzh`dra the Cursed (akheva, 162206):** multiple VT shards
  - **Shar Vinitras / Shei Vinitras (akheva):** multiple VT shards
  - **Lord Inquisitor Seru (sseru, 159691):** Sanctus access + 1
    VT shard
  - **Grieg Veneficus (griegsend, 163075):** 1+ VT shard
- **Beastlord epic** is the only in-era Epic 1.0 with substantive
  Luclin-only raid dependency (Khati Sha).

**Luclin quest-chain blockers BEYOND boss-stat scaling:**
- **Vex Thal shard count** — RESOLVED 2026-04-22: actual count is 10, not 13; shard phase is non-raid already accessible
- **Faction grinds for Sanctus Seru / Katta / Akheva access** —
  time-wall like Velious
- **Vex Thal internal progression** — the zone has extensive add-
  phase scripts and patrol paths that may or may not be small-
  group tractable even with boss-stat cuts

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

Bosses that gate more than one quest chain — the "choke-point"
encounters where scaling failures have outsized impact:

| Boss | Zone | Era | Dependent chains |
|------|------|-----|------------------|
| **Faydedar** (96089) | timorous | Kunark | Druid Epic, Ranger Epic, Shaman Epic, Magician Epic, Bard Epic, VP key quest — **6 chains** |
| **Chardok royals** (103055/56/80) | chardok | Kunark | Enchanter Epic, Magician Epic, Paladin Epic, Rogue Epic, Wizard Epic — **5 chains** |
| **Trakanon** (89154) | sebilis | Kunark | Cleric Epic, Warrior Epic, Bard Epic, VP key quest — **4 chains** |
| **Venril Sathir** (102112) | karnor | Kunark | Necromancer Epic, Shadow Knight Epic — **2 chains** |
| **Noble Dojorn** (71057) | airplane | Classic | Rogue Epic, Monk Epic, Enchanter Epic, Plane of Sky progression — **4 chains** |
| **a_dracoliche** (72090) | fearplane | Classic | Cleric Epic (Soulfire), possibly Wizard Epic — **1-2 chains** |
| **Innoruuk** (76007 / 186158) | hateplane / hateplaneb | Classic | Necromancer Epic, Shadow Knight Epic — **2 chains** |
| **Outdoor Kunark dragons** (Gorenaire, Severilous, Talendor) | dreadlands / emeraldjungle / skyfire | Kunark | VP key quest (5 dragon components) + various epic side-components — **5+ chains** |
| **Avatar of War** (113457) | kael | Velious | Kael Arena endgame loot target (NOT a class-epic dependency — lore-master corrected: Warrior/Paladin/SK epics have no Velious step) — **0 quest chains** |
| **King Tormax** (113215) | kael | Velious | Sleeper's Tomb key (Shard of Hsagra's Talisman alt path), Thurgadin armor molds — **2 chains** |
| **Dain Frostreaver IV** (129003) | thurgadinb | Velious | Coldain Ring War (Ring 9 + Ring 10 turn-in) + Coldain Prayer Shawl chain (pending lore-master addendum) + Sleeper's Tomb key (Shard of Hsagra alt source) — **3+ chains** |
| **ToV Aaryonar line** (124010, 124037, 124020) | templeveeshan | Velious | Halls of Testing quest chain (Dozekar + named drakes for Skyshrine armor molds). NOT a Sleeper's Tomb key or SK/Paladin epic dependency (lore-master corrected) — **1 chain** |
| **First Brood dragons** (Klandicar 120084 / Sontalak 120005 / Zlandicar 123115 / Yelinak 114106 / Lendiniara 124020) | westwastes / necropolis / skyshrine / templeveeshan | Velious | Sleeper's Tomb key (ONE talisman required from any of these). Klandicar/Sontalak/Zlandicar at ~40k HP post-audit are the recommended small-group path — **1 chain (but 5 path options)** |
| **Vulak`Aerr** (124155) | templeveeshan | Velious | ToV endgame gate, multiple class-enhancement Velious quests — **3+ chains** |
| **High Priest of Ssraeshza** (162076) | ssratemple | Luclin | Emperor Ssraeshza key quest, possibly 1 VT shard — **1-2 chains** |
| **Vyzh`dra the Cursed** (162206) | akheva | Luclin | Multiple VT shards, Akheva progression — **2+ chains** |
| **Lord Inquisitor Seru** (159691) | sseru | Luclin | Sanctus Seru access, possibly 1 VT shard — **1-2 chains** |
| **Grieg Veneficus** (163075) | griegsend | Luclin | VT shard, Grieg's End access — **1-2 chains** |
| **Khati Sha the Twisted** (154145) | grimling | Luclin | Beastlord Epic (the most Luclin-heavy Epic) — **1 chain** |

**Key takeaway:** The Kunark era has the densest quest-chain dependency
concentration (6 bosses gate 4+ chains each). Scaling mistakes here
have the biggest ripple across class progression. Velious shares this
concentration around Kael (AoW + Tormax) + Dain + the Aaryonar ToV
line. Luclin's concentration is distributed across VT shard sources
(many bosses, 1-2 chains each) but the VT shard quest itself is a
13-boss meta-dependency.

**Scaling impact on progression:** if boss-stat scaling per the
audit-catalog recommendations is applied correctly, ALL listed
encounters become beatable by 1 player + 5 companions. The
remaining blockers are:
- Faction grind time (Velious Ring of Scale / Claws of Veeshan /
  Coldain; Luclin Sanctus Seru / Katta)
- Vex Thal 10-shard meta-quest scope (shards are non-raid, no scope issue)
- Any scripted events with hard-coded group-size checks
  (architect to investigate Ring War, VT internals, Sleeper event)

---

## Boss-catalog addenda from lore-master Classic epics review

Added 2026-04-22 after lore-master Classic epics catalog delivery.
The following NPCs are quest-critical for Epic 1.0 progression and
were either missing from the boss catalog or needed additional
flagging. All stats verified via `peq` db query.

### The Tangrin — Field of Bone (Kunark zone, not Classic)

- **NPC ID:** 78070
- **Level:** 54 / **HP:** 16,350 / **dmg:** 62-220 / **AC:** 189 / **MR:** 435
- **npcspecialattks:** S (summon)
- **Originally omitted:** Field of Bone is a Kunark zone but the
  Enchanter Epic 1.0 step that requires The Tangrin sits in the
  Classic-phase walkthrough. The Kunark boss catalog missed this
  entry because my initial query filtered by expansion + high-HP
  thresholds.
- **Quest dependency:** Sands of the Mystics for Enchanter Epic
  4th Piece of Staff
- **Respawn:** 12hr (per lore-master)
- **Gap vs. L54 scaled-named (~7.5k HP):** ~2.2× HP — already close
  to scaled-named tier; damage already in named range
- **Recommended:** Minor HP cut (15-20%, target ~13k). Respawn to
  6h. Preserve summon ability. Add to Kunark boss catalog scope.

### Faydedar dual-variant handling (reaffirmed)

- **Standard Faydedar (id 96089):** L55 32k HP — outdoor boss in
  Timorous Deep, farmable through normal spawn cycle
- **`#Faydedar` (id 96073):** L55 32k HP — script-spawned variant
  via Dolgin Codslayer (Timorous Deep, 12hr respawn). Used for the
  "weak Faydedar" step in Druid/Ranger epics.
- **Both have `raid_target = 1`** and identical stats (32k/103-236/AC 234).
- **Critical:** Scaling changes to Faydedar MUST apply to BOTH
  NPC IDs or the Druid/Ranger epic's "weak Faydedar" step breaks.
- **Recommendation:** SQL UPDATE targeting `name LIKE '%Faydedar%'`
  OR explicit id list `(96089, 96073)` — architect to choose.

### Venril Sathir multi-form scaling

The boss catalog captured #Venril_Sathir (id 102112, raid_target=1,
22k HP). Four additional VS-family entities exist, three of which
are quest-load-bearing:

- **102112 `#Venril_Sathir`** (raid_target=1, 22k HP, L55) —
  triggered raid form; Druid/Ranger epic target after 20hr remains
  wait + Firefly Globe + Rez scroll ritual. Already in Kunark
  boss catalog.
- **102126 `Venril_Sathir`** (raid_target=0, 11k HP, L55, SRUMCNIDf
  abilities) — likely the Wizard Epic standard form (dropping the
  Gnarled Staff). HP is half the triggered form but carries the
  raid-boss immunity set. NOT in boss catalog because raid_target=0.
  **Flag for architect:** verify this is the Wizard Epic VS. If yes,
  scale identically to the raid-target form (HP cut 25%, target ~8k).
- **102099 `Venril_Sathirs_remains`** (L50, 4,375 HP) — NPC spawned
  after killing the Wizard/raid VS. Intermediate step for Druid/
  Ranger epic. No scaling needed — low HP trivial.
- **102123 `Spirit_of_Venril_Sathir`** (L55, 9,375 HP, flee-disabled
  only) — intermediate spirit-form from giving Firefly Globe to
  remains. Turns into triggered VS after rez-scroll. No scaling
  needed — low HP.
- **105182 `Venril_Sathir`** (Charasis, L55, 15,375 HP, SRUMCNIDf)
  — separate VS encounter in Howling Stones (different zone).
  Possibly a lore-variant (VS's undead form in Drusella's stronghold?).
  **Architect to investigate role** before scaling.

### Lhranc (citymist, id 90093) — dual-class epic gatekeeper role

- Boss catalog entry stands — stats are fine (19k HP, 120-305 dmg),
  minimal-change recommendation remains.
- **Audit lore note to add:** Lhranc is the **final combat
  encounter for BOTH Paladin (Fiery Defender) and Shadow Knight
  (Innoruuk's Curse) Epic 1.0 quests.** Scaling him too aggressively
  downward trivializes two endgame weapons; leaving him as-is (the
  minimal-change recommendation) matches lore-master's pain-score
  YELLOW for both epics.
- **Spawn mechanic note:** Per lore-master, Lhranc is spawned by
  giving the pre-assembled component set (Corrupted Ghoulbane +
  Heart of the Innocent + Head of the Valiant + Will of Innoruuk)
  at loc 0 +90 in City of Mist. After kill, Marl Kastane spawns
  outside the room for the token turn-in. Respawn 13hr+ per
  lore-master research.

### a_dracoliche (fearplane, id 72090) role clarification

- Boss catalog entry stands (175k HP recommended → 35-50k) but the
  "Cleric Epic 1.0 step" annotation is WRONG.
- **Cleric Epic actually requires "Slime Blood of Cazic-Thule"
  from PoFear** — drops from Cazic-Thule, Dread, Fright, or Terror.
  NOT from a_dracoliche.
- **Shadow Knight Epic requires Soul Leech Dark Sword of Blood**
  — drops from Dread/Fright/Terror/Cazic-Thule. NOT from dracoliche.
- **Updated role:** a_dracoliche is a PURE scaling target (large
  HP gap, aggressive Flurry+Unslowable), NOT a quest blocker.
  This reduces its implementation-priority ranking from "quest-
  critical" to "standard scaling". The four Fear gods (Dread/
  Fright/Terror/Cazic-Thule) are the actual quest-critical PoFear
  bosses for Cleric + SK epics.

### Trakanon dual-variant handling (added 2026-04-22 from Kunark review)

- **Standard Trakanon (id 89154):** L65, 32,000 HP, SERFMCNDf, raid_target=1 — drops Trakanon's Tooth (VP key component) and is the Old Sebilis zone boss. Already in boss catalog.
- **`#Trakanon` (id 89181):** L65, **16,000 HP**, SMCNIDf, raid_target=0 — script-spawned via An Undead Bard (id 89168) for the Bard Epic. Drops Undead Dragongut Strings. Same-lore-identity NPC. Damage and immunity sets reduced (no Enrage/Rampage/Flurry on triggered variant per db).
- **Other Trakanon entries in db (out of scope):** 89196 (`#The_Fabled_Trakanon`, L75 4M HP — Fabled OOE), 452079 (L90 9k HP — likely PoP proxy or script placeholder, OOE).
- **Recommendation:** Scaling changes to Trakanon (audit catalog: HP cut 30% to ~22k, flurry trim) should apply to BOTH id 89154 and id 89181. Since 89181 already starts at 16k HP, architect may choose to leave it untouched OR apply proportional cut (e.g. to ~11k) to preserve the "weaker triggered variant" lore feel.

### An Undead Bard — Bard Epic spawner NPC (not a scaling target)

- **NPC ID:** 89168 (Old Sebilis) / **Level:** 57 / **HP:** 7,875
- **Role:** Quest-handler for Bard Epic. Giving Mystical Lute Body spawns `#Trakanon` (id 89181). Not itself a combat-scaling concern.
- **Architect note:** Quest-script at `akk-stack/server/quests/sebilis/` handles this spawn. Verify script doesn't break under scaling changes.

### Jennus Lyklobar — Magician Epic turn-in NPC (not a combat encounter)

- **NPC ID:** 91046 (Skyfire Mountains, roaming) / **Level:** 61 / **HP:** 14,000
- **Role:** Element of Fire assembly for Magician Epic. Non-combat NPC. Sees invis, can path into geometry (tracker recommended in era). No scaling action needed.

### Idol of Rallos Zek — Kael spawn-chain boss (added 2026-04-22 from Velious review)

- **NPC ID:** 113341 / **Zone:** kael / **Level:** 66 / **HP:** 650,000
- **Damage:** 245-1,100 / **npcspecialattks:** SERTMCNIDf / **raid_target:** 1
- **Spawn chain role:** Statue of Rallos Zek (113071, 400.75k HP) → kill spawns Idol (113341, 650k HP) → kill spawns Avatar of War (113457, 900k HP).
- **Originally omitted:** My Velious boss catalog covered Statue and Avatar but missed the middle tier (Idol). Kael Arena raid progression was incomplete.
- **Quest dependency:** Kael progression for Warrior / Paladin / SK epic late steps + Coldain Ring 9 adjacency + Thurgadin armor chain. The Avatar chain is the most prestigious Kael kill sequence.
- **Gap vs. L66 scaled-named (~24k HP):** ~27× HP
- **Recommended action:** HP cut 80% (→130k). Damage cut 37% (→200-700 range). Respawn 12h. Preserve spawn-chain semantics (killing Statue must still spawn Idol, killing Idol must still spawn Avatar).
- **Architect implementation note:** Spawn-chain script at `akk-stack/server/quests/kael/` must be preserved. Scaling changes must not break the trigger chain.

### Jaled Dar's Shade — Sleeper's Tomb key turn-in NPC (not scaling target)

- **NPC ID:** 123011 / **Zone:** necropolis / **Level:** 70 / **HP:** 3,002,000 / **dmg:** 250-900
- **Role:** Sleeper's Tomb key quest turn-in (receives First Brood talisman, gives Key of Sleeper's Tomb). 3M HP is intentional "uncombattable quest NPC" design. The original Velious boss catalog flagged this as "SPECIAL — investigate before scaling".
- **Lore-master confirmation:** This is a QUEST-NPC, not a kill target. Leave at 3M HP.
- **Implementation:** Remove from any scaling UPDATE that might target `hp > 1,000,000 AND raid_target = 1` (if architect uses such a filter — better to use explicit ID lists).

### Doomshade — Umbral Plains raid boss (added 2026-04-22 from Luclin review)

- **NPC ID:** 176088 / **Zone:** umbral / **Level:** 66 / **HP:** 350,000
- **Damage:** 127-412 / **raid_target:** 1
- **Originally omitted:** Luclin boss catalog missed this — my initial Umbral query captured Zelnithak (176089) and Rumblecrush (176002) but not Doomshade (176088).
- **Role:** Signature Umbral Plains raid boss. Not quest-required but high-value loot target.
- **Gap vs. L66 scaled-named (~24k HP):** ~15× HP; damage already in manageable range
- **Recommended action:** HP cut 75% (→90k). Damage no change. Respawn 12h.

### Ssraeshza Temple Ring of the Shissar NPCs (added 2026-04-22)

- **Commander Zazuzh (id 162150):** L56, 9,000 HP — `#`-prefix script-spawned. Floor 1 door-key source (guaranteed drop). Already scaled-named tier. **No scaling action needed.**
- **Commander Zherozsh (id 162217):** L58, 9,000 HP — script-spawned. Floor 2 door-key source. **No scaling action needed.**
- **Warden Mekuzh (id 162023):** L60, 33,000 HP — elite-named Taskmaster's Pouch source. Recommend minor HP trim (10-20% → ~27k).
- **Spiritist Kama Resan (id 154052):** L60, 5,600 HP (Acrylia zone). Grimling War trigger NPC — non-combat. **No scaling action.**
- Pre-Emperor named (Advisor Zekuzh 162067, Arbiter Korazhk 162191, General Kizuhx 162066) are already in the Ssraeshza Temple boss catalog; confirmed as Ring of the Shissar Insignia sources.

### VT Key correction (added 2026-04-22)

- VT key is **10 Lucid Shards** (not 13 as originally described) + Shadowed Scepter Frame (Akheva chain) + Planes Rift (Emperor Ssraeshza) + Glowing Orb of Luclinite (any Luclin raid boss).
- Shard collection phase is fully non-raid, accessible to small group today.
- Only two RED blockers: Emperor Ssraeshza + any Luclin raid boss kill. Both covered by boss-catalog scaling.
- Open Question #7 (shard-count reduction) now **resolved** as largely moot — no quest-script change needed.

### Implementation implications of the addenda

- **Kunark boss catalog** needs The Tangrin added (78070).
- **Any SQL scaling UPDATE for Faydedar** must cover both 96089 AND
  96073. Recommend matching by `loottable_id` or an explicit id list.
- **Wizard Epic VS form (102126)** should be scaled even though
  `raid_target = 0`. Architect: do not filter by raid_target on
  implementation UPDATE; use the consolidated ID list.
- **Lhranc scaling floor is "minimal change".** Don't over-cut him
  — his role as dual-epic gatekeeper means he should remain a
  recognizable challenge.
- **Dracoliche priority drop:** from "quest critical" to "standard
  scaling" in the implementation task breakdown. Not urgent for
  Cleric/SK epic completion.
- **Trakanon dual-variant:** scaling UPDATE must cover BOTH id 89154
  (standard) and id 89181 (triggered #Trakanon). Architect can match
  by `name LIKE '%Trakanon%' AND level = 65` OR explicit id list. The
  triggered variant is already at 16k HP (half of standard 32k), so
  it may need lesser or no cut depending on philosophy.
- **Kilidna is not a kill target — she's a traversal hazard.** The
  4,600 max damage cut recommendation exists to make the City of
  Mist path to Lhranc survivable for small groups doing Paladin/SK
  epics. Implementation SQL comment should preserve this rationale.
- **Velious script review required beyond stats:** Ring War wave
  structure (`greatdivide/encounters/ring_war.lua`), Peffin Ambersnow
  guard spawn mechanic, Kael Avatar spawn-chain triggers, and Ring 8
  fort-war failure-reset logic. Pure SQL scaling is insufficient for
  small-group Velious progression — quest-script tuning is required
  for the Ring 10 event specifically.
- **Add Idol of Rallos Zek (113341) to Velious boss catalog SQL set.**
  Middle tier of the Kael Avatar spawn chain — omitted from initial
  catalog; without it the chain is broken.
- **Jaled Dar's Shade (123011) excluded from scaling UPDATE set** —
  quest-NPC with intentional 3M HP; lore-master confirmed non-kill
  role. The original boss catalog's "SPECIAL investigate before
  scaling" flag is now resolved to "do not scale".
- **Community-source HP values vs db values:** several Velious
  bosses (Avatar of War, Sontalak, Klandicar, Zlandicar) have
  community sources citing 1.7M / 300k / 200k+ HP. PEQ db values
  are lower (900k / 97.5k / 110k). **Db values are authoritative**
  for scaling math — community sources often reflect post-PoP
  live-server tunings or different server eras. Architect should
  NOT inflate scaling cuts to match community sources.
- **Add Doomshade (id 176088) to Luclin boss catalog SQL set.** L66
  350k HP Umbral Plains raid target — omitted from initial catalog.
- **Cross-era gate Vulak`Aerr → Key to Luclin** must be considered
  in phase sequencing. Phase 4b (Velious ToV) contains Vulak`Aerr
  and gates all of Phase 5 (Luclin). Cannot split these into
  independent projects without architect investigating whether Key
  to Luclin can be alternate-sourced (Shadow Haven vendor per some
  PEQ versions, or GM-granted) to decouple.

---

## Headline Findings

### 1. The prior scaling pass left ALL raid-boss stats untouched

The small-group-scaling project (completed 2026-02-23) filtered its
stat-reduction UPDATEs on `raid_target = 0`, explicitly excluding raid
bosses from HP / damage / AC cuts. It also left `npc_scale_global_base`
type 2 (raid-tier baseline) unchanged. **Every one of the ~140 true-boss
encounters across Classic-Luclin therefore sits at default PEQ values.**
The prior pass DID improve raid loot probability (×1.5), rare-drop
chance (×1.5), and spawn2 respawn timer (×0.75) for raid targets — but
respawn is still in the 54-130 hour range, above the brief's 6-24h
target.

### 2. True-boss counts by era (in-era, filtered)

| Era | Raw `raid_target = 1` | True bosses | Excludes |
|-----|----------------------|-------------|----------|
| Classic | 344 | ~30 | Fear/Hate/Growth trash, Halloween events, GM dummies, Legendary Behemoth (L72 OOE) |
| Kunark | 28 | 19 | Fabled (L70+ LoN), post-Luclin Prince/Princess variants |
| Velious | 362 | 60-65 | ToV/Sleeper/Growth trash, Mischief Plane revamp, Fabled, Sir Elmonious (3.6k dmg OOE) |
| Luclin | 144 | ~30 | Vex Thal Yaemiu elite (80 at 55-100k HP), Fabled, OOE content (L73+) |
| **Total** | **878** | **~140** | |

### 3. Scaling gap size ranges by tier

| Tier | Example encounters | HP gap vs. scaled-named | Damage gap |
|------|--------------------|-----------------------|-----------|
| **Endgame (Luclin VT + top ToV + Vulak + AoW)** | Aten Ha Ra, Vulak`Aerr, Emperor Ssraeshza, Kaas Thox Xi Aten Ha Ra | **30-63× HP** | 1,000-2,475 max damage (often one-shots small-group tanks) |
| **Mid-boss (most ToV, most Sleeper, Seru, Grieg, Akheva top, some Luclin mids)** | Lord Vyemm, Dagarn, Zeixshi-Kar, Lord Inquisitor Seru, Grieg Veneficus, Khati Sha, Thought Horror | 10-25× HP | 500-1,200 max damage (dangerous but survivable with prep) |
| **Low-boss (Kael, Skyshrine Crusaders, Growth mid, VP classic-variant, outdoor Velious, mid Luclin)** | King Tormax, Skyshrine Crusaders, Ail the Elder, Velketor, VP variants | 4-10× HP | 400-800 max damage (largely in current scaled-named range) |
| **Near-named (Classic bosses, most Kunark outdoor dragons, Chardok, WW dragons)** | Nagafen, Vox, Gorenaire, Trakanon, Overking Bathezid, Phinigel, most Fear/Hate bosses | 2-4× HP | 200-500 max damage (already fine, primary lever is HP) |

### 4. Worst-offender encounters (highest single-boss priority)

| Rank | Boss | Zone | Current HP | Current max dmg | Gap multiplier |
|------|------|------|-----------|-----------------|----------------|
| 1 | Aten Ha Ra | vexthal | 1,901,500 | 1,054 | 63× HP |
| 2 | Kaas Thox Xi Aten Ha Ra | vexthal | 1,900,000 | **1,650** | 63× HP + worst dmg |
| 3 | Thall Va Kelun | vexthal | 1,825,000 | 1,000 | 61× HP |
| 4 | Diabo Xi Va Temariel | vexthal | 1,706,000 | **1,400** | 57× HP + worst dmg |
| 5 | Va Xi Aten Ha Ra | vexthal | 1,601,500 | 1,254 | 53× HP |
| 6 | Emperor Ssraeshza | ssratemple | 1,250,500 | 904 | 42× HP |
| 7 | Lord Inquisitor Seru | sseru | 1,201,500 | 915 | 40× HP |
| 8 | High Priest of Ssraeshza | ssratemple | 941,000 | 722 | 31× HP |
| 9 | Vulak`Aerr | templeveeshan | 890,000 | **1,400** | 30× HP + worst dmg |
| 10 | Thought Horror Overfiend | thedeep | 807,000 | 776 | 27× HP |
| 11 | Xerkizh the Creator | ssratemple | 806,516 | 674 | 27× HP |
| 12 | Vyzh`dra the Cursed | akheva | 900,000 | 588 | 30× HP |
| 13 | The Avatar of War | kael | 900,000 | 1,154 | 30× HP + damage (general loot target, not class-epic dependency) |
| 14 | Xygoz (VP revamp) | veeshan | 814,000 | **2,266** | 27× HP + worst dmg |
| 15 | Nexona (VP revamp) | veeshan | 800,000 | **2,475** | 27× HP + worst dmg |
| 16 | Cazic Thule | fearplane | 451,000 | 603 | 15× HP (but Classic-era outlier) |
| 17 | Kilidna | citymist | 100,000 | **4,600** | 3× HP but **catastrophic damage** |

The **damage outliers** (Kilidna 4,600, Nexona 2,475, Xygoz 2,266,
Kaas Thox 1,650, Diabo Xi Va 1,400, Vulak 1,400) are the highest
priority for player survival regardless of HP — these are one-shots
for any small-group tank at current tuning, and should be addressed
in the FIRST phase of implementation regardless of era.

### 5. Respawn timers are almost universally above the 6-24h target

The prior pass reduced raid_target respawn timers by 25%, but the
PEQ defaults are so high that even post-×0.75 most bosses are still
at 40-130 hours. The brief's 6-24h window requires a significant
additional reduction.

| Current respawn | Count across audit | Target |
|-----------------|-------------------|--------|
| 400k-470k sec (112-130h) | ~15 (Vex Thal top, NToV top, Sleeper top) | 24h |
| 258k-290k sec (72-80h) | ~30 (most ToV, Sleeper, Ssraeshza, Seru, most outdoor Velious/Luclin) | 12h |
| 194k sec (54h) | ~20 (most Classic Fear/Hate/Sky, Kunark outdoor dragons, Trakanon, VS, etc.) | 6-12h |
| 43k-86k sec (12-24h) | ~12 (Kael's Vindicator, Growth, some Luclin mid) | leave or reduce to 6h |
| 10-20k sec (3-5h) | ~10 (Skyshrine Crusaders, most airplane bosses, Chardok royals) | leave |
| 640-1080 sec (11-18m) | ~12 (Hate council, some Ssraeshza mid, some training) | leave |

### 6. Progression choke-points (pending lore-master final pass)

The following bosses are known to be quest-chain nodes for multiple
classes simultaneously (lore-master Task #7-10 will complete):

- **Faydedar (timorous):** Ranger, Druid, Magician, Shaman Epic 1.0
  steps confirmed; potentially 6+ total classes per lore-master pass
- **Venril Sathir (karnor):** Cleric, Necromancer, SK Epic 1.0 steps
- **a_dracoliche (fearplane):** Cleric Epic (Soulfire chain), possibly
  Wizard Epic
- **Trakanon (sebilis):** Cleric, Warrior, others
- **Vulak`Aerr (templeveeshan):** ToV key tier — gates entire ToV
  access chain
- **King Tormax / Avatar of War (kael):** Kael endgame / Sleeper's
  Tomb key alt-path (Shard of Hsagra). **NOT class-epic dependencies**
  — lore-master corrected 2026-04-22: Warrior/Paladin/SK epics have
  no Velious step.
- **Dain Frostreaver IV (thurgadinb):** Coldain Ring War + multiple
  Velious faction chains
- **Noble Dojorn / Plane of Sky island bosses:** Rogue, Monk Epic
  + Sky access

### 7. Era-variant duplicate IDs (data-quality note for architect)

Multiple raid bosses exist as TWO NPC IDs in the PEQ database —
typically a pre-revamp variant and a post-revamp variant. Examples:

- **Veeshan's Peak dragons:** 6 of 7 have both L65-67 "classic" IDs
  (108509-108517, 144-192k HP) and L70 "revamp" IDs (108040-108053,
  454-814k HP). Quest scripts target the revamp IDs — revamp is live.
- **Lord Yelinak:** id 114106 (500k HP) vs id 114618 (297k HP)
- **Aten Ha Ra:** id 158006 vs id 158096 (both at 1.9M HP)
- **The Final Arbiter:** id 128143 (357k) vs id 128045 (200k) —
  main boss vs sub-encounter variant
- **Guardian of Tunare:** id 127007 vs id 127106 (both 310k)
- **#Master of the Guard:** id 128145 (326.5k) vs id 128054 (100.5k)
- **#The Progenitor:** id 128144 (327k) vs id 128053 (150k)
- **Faydedar:** id 96089 (in spawnentry, live) vs `#Faydedar` id 96073
  (script-spawned duplicate)
- **Zordak Ragefire:** id 32038 (9.5k HP) vs id 91096 (9.5k) vs
  Zordakalicus Ragefire id 91090 (33k) — three-way ambiguity

The architect should audit each duplicate, confirm which is live,
and normalize to a single ID per encounter before scaling operations
fan out to unused records.

### 8. Abilities to preserve vs. trim

The audit recommends HP reductions of 70-90% for most Velious/Luclin
top bosses but damage reductions of only 20-50%. Additionally:

**Preserve** (signature mechanics that small groups can learn around):
- Summon (S) — all raid bosses have it; defines raid-boss tension
- Enrage (E) — enrage timing teaches the "finish the kill" skill
- Rampage (R) — add-management is a positive skill check
- Triple/Quad attack (T/Q) — damage pattern variety
- Flee-disabled (f) — no kiting, forces commitment

**Consider trimming** (to help small groups at the margin):
- Flurry (F) — stacks with rampage; if current damage is high, flurry
  becomes lethal. For Velious/Luclin top bosses, reduce or replace.
- Rampage 10×7 (Cazic Thule) and 6×6 (Avatar of War) — reduce to 3×3
  at most. Six concurrent rampage targets require 6+ bodies to absorb.
- Unslowable (U) — debatable. Enchanters/shaman slow is a core small-
  group tool. On most top bosses, consider removing U to give small
  groups a dps tool.

**Keep immune** (for era preservation):
- Magic-immune, charm-immune, mez-immune, stun-immune, normal-weapon-
  immune, disease-immune — these are part of "raid boss" identity.
- Magic Resist values should generally remain high — this preserves
  "casters can't solo-nuke a dragon".

### 9. Cross-era gate: Vulak`Aerr blocks ALL advanced Luclin (lore-master Task #10 finding)

The Key to Luclin (zone access for Ssraeshza, Akheva, Vex Thal,
Grieg's End, Umbral Plains, Fungus Grove, The Deep, The Grey,
Grimling Forest, Acrylia inner) requires killing **Vulak`Aerr**
(ToV final boss, id 124155, 890k HP). This is a Velious endgame
kill gating the entire Luclin raid progression.

**Phased-delivery implication:** If the user splits Phase 2-5 by
era, Luclin is DOWNSTREAM of Velious-ToV completion. Phase 4b
must include Vulak`Aerr scaling, not just ToV mid-tier. Alternatively,
architect should investigate whether the Key to Luclin requirement
can be lifted for small-group server (purchased from a Shadow Haven
NPC as some PEQ versions allow, or GM-granted). This is a new **Open
Question** for the user.

### 10. Special-case encounters flagged for non-standard handling

| Encounter | Zone | Reason | Recommended handling |
|-----------|------|--------|----------------------|
| #The_Sleeper / Kerafyrm (L99, 3.5M HP) | sleeper | Awakened Sleeper is a world-event narrative kill, not a raid target | Out of scope — do not scale |
| a_warm_light / a_thifling_focuser | growthplane | Event-trigger NPCs (not combat) | Out of scope |
| #Keymaster / #Aten_Trigger / #Vulak_Trigger / #kerafyrm_trigger | various | Instance/event-control NPCs at 50M-99M HP | Out of scope |
| Halloween event mobs (Eve Hallows, Jack Lanturn, Tricksy Treetor) | kithicor | Seasonal content, appear only during event windows | Out of scope |
| Bella/Heracus Helsin, Lantaric`Dar | katta/wakening | Event-control NPCs at L1 with giant HP | Out of scope |
| Fuzz Selppa (tox) | tox | Anomalous L50 200k HP outdoor mob — likely event trigger | Investigate before scaling |
| Hateplaneb vs Hateplane | (both) | Two versions of Plane of Hate in database | User decision needed |
| Vex Thal Yaemiu elite tier (~80 mobs 55-100k HP) | vexthal | Elite trash that in any other zone would be raid-tier | User decision: include in scope or leave |

---

## Recommended User Decisions

### A. Phased delivery — how to split the remaining work

**Option A — Single sustained Phase 2-5:** One continuous project
covering all four eras. Estimated encounter count: ~140 bosses, plus
quest-chain fixes.
- Pro: single context, no re-bootstrap overhead between eras
- Con: 140 encounters is a large single-phase implementation scope;
  context drift risks; user can't course-correct mid-project

**Option B — Split by era (recommended):** Four consecutive projects.
- 2 — Classic (~30 bosses) — simplest, quickest win
- 3 — Kunark (~19 bosses) — second-quickest
- 4 — Velious (~60-65 bosses) — THE big one; consider sub-split
  (4a: non-ToV/Sleeper; 4b: ToV + Sleeper + Vulak)
- 5 — Luclin (~30 bosses) — consider sub-split
  (5a: non-VT; 5b: VT + key-quest rework)
- Pro: deliverable at each era; user can test before committing next
- Con: higher bootstrapping overhead (4 separate architect phases)

**Option C — Tier-first (experimental):** Instead of by era, split
by difficulty tier. Phase 2 = all "low-boss" and "near-named" tier
across all eras (Classic dragons, Kunark outdoor, etc. — ~65 entries,
the HP-gap-3× to 10× set). Phase 3 = all "mid-boss" (Kael, Skyshrine,
Grieg, Akheva, Ssraeshza mids — ~40 entries). Phase 4 = "endgame"
(ToV dragon lords, Sleeper's Tomb, Vex Thal — ~35 entries).
- Pro: player experience smooth — they see the progression curve
  working through tiers; lower-tier fixes unlock lower-tier quest
  content first
- Con: era lore progression ignored; may feel disjointed

### B. Veeshan's Peak dragons — two ID sets exist

Use the level-65-67 classic-era variant (144-192k HP) with minor
scaling, OR keep the level-70 revamp variants (454-814k HP) with
deep scaling? Quest scripts currently target the revamp IDs.
Recommendation: keep the IDs the scripts point at and scale the
revamp variants down. Update quest scripts ONLY if the user wants
true classic-era VP difficulty.

### C. Plane of Hate — classic (hateplane) or revamp (hateplaneb)?

Both versions exist in the database. The revamp adds ~20 bosses and
much more trash. Which is intended as the live version? Recommendation:
confirm via in-game probe — which version does the player actually
zone into today?

### D. Vex Thal Yaemiu elite trash

The ~80 Yaemiu-pattern elite mobs in Vex Thal sit at 55-100k HP —
above a scaled-named's 30k. Brief says "named feels good" but these
specifically are NOT named — they're raid-zone elite trash. Include
in raid-scaling scope (cut HP to ~40k) OR leave (they remain
significantly harder than group-level named)?

### E. Respawn timer targets

The brief says "6-24h range". Recommendation by tier:
- Endgame (Vex Thal, Vulak, top ToV, top Sleeper, Aten, Emperor): 24h
- Mid-boss (most ToV, Kael, Skyshrine, Seru, Grieg, Akheva top): 12h
- Low-boss (outdoor Velious, Classic Fear/Hate/Sky, Classic dragons,
  Kunark outdoor, Chardok royals): 6h
- Already-short (Skyshrine Crusaders, Hate council, Ssraeshza mids
  at 11-18m): leave

### F. Sleeper-awake event

Is Kerafyrm / Awakened Sleeper intended to be killable, a world-event
narrative mechanic, or disabled entirely? Current DB values (L99, 3.5M
HP, 7,003 max damage) are intentionally unkillable. Recommendation:
leave untouched — it's a narrative event, not a scaling target.

### G. Cazic Thule level-and-scale

Cazic Thule at L70 with 451k HP is anomalous even for Classic era
(Classic cap is 50, Luclin introduced 65). PEQ decided to bump him
post-era. Recommendation: drop him to L65 for era alignment, scale
HP to 100-120k, trim rampage from 10×7 to 3×3.

### H. Special abilities vs. scaling dependency

Lord Vyemm's MR=1,000 magic wall and Aaryonar's specific breath
mechanics are lore-canonical. Should these be preserved (recommended)
or softened for small-group tractability? The brief implies
preservation — gate progression through mechanics, not stats.

---

## Phase 1 Audit — Deliverable Status

- [x] Every raid boss in Classic cataloged with current state and gap
- [x] Every raid boss in Kunark cataloged
- [x] Every raid boss in Velious cataloged
- [x] Every raid boss in Luclin cataloged
- [x] Prior scaling pass impact documented per-boss (uniform: stats
  UNTOUCHED, loot/respawn boosted)
- [x] Every raid-tier quest chain cataloged at summary level
  (Classic / Kunark / Velious / Luclin sections). **Flagged as
  game-designer placeholder pending lore-master deep-review** —
  see Coordination Note below.
- [x] Cross-reference matrix of boss counts by zone (in `### Raw
  boss counts`)
- [x] Quest-chain dependency graph (shared-bosses / choke-points)
- [x] Headline findings summary (section above)
- [x] Recommended user decisions list (8 decisions A-H)
- [x] PRD updated with design-intent summary at `game-designer/prd.md`

### Coordination Note (lore-master)

Tasks #7 (Classic), #8 (Kunark), #9 (Velious) were marked completed
by lore-master but no detailed content was contributed to the audit
document or lore-notes. Task #10 (Luclin) was left in_progress at
the time game-designer closed out Phase 1. To prevent the audit
from stalling, **the game-designer wrote summary-level quest-chain
sections from public-domain EQ knowledge** so the Phase 1
deliverable is usable by the architect.

**These quest-chain sections are FIRST-PASS.** The architect should
expect, and lore-master should be re-engaged for:
- NPC ID verification on each quest-step (traditional EQ epics have
  many script-spawned components the audit may have missed)
- Specific component drop rates and lore-accurate step ordering
- Faction-grind time estimates (how many hours of outdoor farming
  is a solo small-group realistic limit?)
- Lore-continuity sign-off on any mechanical changes that affect
  canonical encounter identity (Vyemm's magic wall, Ring War event
  scale, Sleeper-awake narrative, VT shard count reduction if user
  approves)

The audit's boss-catalog portion is FULLY game-designer-owned and
does not require lore-master revision — only the quest-chain
portion (~400 lines) is flagged for lore-master re-review.

### Architect Handoff Ready

This audit + the PRD at `game-designer/prd.md` together form the
complete Phase 1 deliverable. The architect can proceed with:
1. Driving user resolution on the 8 open decisions (sections A-H
   above in Recommended User Decisions)
2. Duplicate-ID resolution (~15 pairs in boss catalog)
3. Script review for Ring War, VT internals, Sleeper event
4. Implementation task breakdown by era+cluster (suggested in PRD
   Appendix: Technical Notes)

**Lore-master re-engagement recommended in parallel** to deepen
the quest-chain sections before Phase 4 implementation reaches
scripted event content.
