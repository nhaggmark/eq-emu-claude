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

> **Status:** Game-designer summary from public-domain EQ knowledge.
> **Pending:** lore-master deep-review and NPC-ID verification for all
> entries below. This section is load-bearing for the architect —
> changes here before Phase 3 are expected.

**Scope:** The "Classic-phase" steps of all 14 class Epic 1.0 quests
(many epics span all 4 eras — this subsection lists the
Classic-phase-only steps), plus Plane of Sky island progression,
plus Cazic-Thule access (Lost Temple) as a Classic-specific
raid-access chain.

---

#### Plane of Sky — key + 8-island progression

- **Class/scope:** General raid access; prerequisite for Rogue Epic
  (Ragebringer), Monk Epic (Celestial Fists), Enchanter Epic
  (Staff of the Serpent), Warrior Epic (Swiftwind/Earthcaller) end
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

**Druid Epic 1.0 — Nature Walker's Scimitar**
- Classic raid step (pre-Faydedar): **Phinigel Autropos** drop
  required (Kedge Keep) for some versions of the chain —
  lore-master confirm
- Kunark raid step: Faydedar (primary raid target)
- Cross-references: Phinigel Autropos (kedge, 64001)

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

**Warrior Epic 1.0 — Swiftwind / Earthcaller**
- Classic raid step: no specific Classic raid required
- Kunark raid step: Trakanon, outdoor dragons
- Velious raid step: Avatar of War, Ring of Scale
- Cross-references: Trakanon (sebilis, 89154), AoW (kael, 113457)

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

> **Status:** Game-designer summary pending lore-master deep-review.

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

**Warrior Epic 1.0 — Swiftwind / Earthcaller (pair)**
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

> **Status:** Game-designer summary pending lore-master deep-review.

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

#### Temple of Veeshan (ToV) key quest

- **Class/scope:** ToV access; Warrior / Paladin / SK epic late
  steps
- **Era:** Velious
- **Zones:** Kael + ToV itself + "shard" collection across
  Velious
- **Turn-in NPCs:** (lore-master to confirm) — traditionally at
  Claws of Veeshan dragons in Kael/Skyshrine
- **Raid encounters required:**
  - Key pieces drop from Kael bosses (Tormax, Derakor, AoW
    component) + outdoor Velious dragons (Klandicar, Sontalak,
    Yelinak context)
  - Sleeper's Tomb key is SEPARATE — see below
- **Non-encounter blockers:** Ring of Scale / Claws of Veeshan
  positive faction required
- **Small-group blockers:** Tormax and AoW at current stats are
  walls; audit's 78-87% HP cut makes them tractable
- **Recommended action:** Addressed by boss-catalog scaling + the
  user decision on faction-grind time

#### Sleeper's Tomb key quest

- **Class/scope:** Sleeper's Tomb access; prereq for 4-Warder
  events and the Sleeper-awake event
- **Era:** Velious
- **Zones:** ToV (four Ancients trigger Warder summons)
- **Raid encounters required:**
  - Kill specific ToV dragons for key components (traditionally:
    Aaryonar, Dozekar, Lendiniara as a core set — lore-master
    verify)
  - Some Sleeper's Tomb ancients drop key components themselves
- **Progression path:** ToV → collect key components from
  Aaryonar line → enter Sleeper's → face Warders
- **Small-group blockers:**
  - ToV bosses at current stats (audit covers)
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

#### Avatar of War quest (Warrior / Paladin / SK)

- **Class/scope:** Warrior, Paladin, SK Epic 1.0 late step
- **Zones:** Kael, ToV
- **Raid encounters required:** Avatar of War kill + component from
  ToV tier
- **Small-group blockers:** AoW at 900k HP + rampage 6×6 = current
  wall. Audit recommends 87% HP cut + rampage 3×3.
- **Recommended action:** Addressed by boss-catalog scaling.

---

#### Velious-phase of Epic 1.0

Most Epic 1.0s COMPLETE in Kunark or have their Velious steps as
quality-of-life rewards (not raid-tier). The Velious-required raid
steps are specific:

**Warrior Epic 1.0 — Swiftwind / Earthcaller**
- Velious raid step: **Avatar of War** kill (for Swiftwind) +
  **Vindicator** (for Earthcaller pair)
- Small-group viability: post-scaling, AoW tractable; Vindicator
  already moderate tier (180k HP → 60k post-audit)

**Paladin Epic 1.0 — Fiery Avenger**
- Velious raid step: **Avatar of War** component
- Small-group viability: same as Warrior

**Shadow Knight Epic 1.0 — Innoruuk's Curse / Velious step**
- Velious raid step: varies by chain; traditional SK "blood of
  the dragon" requires ToV dragon kill (usually Aaryonar or
  Dozekar — lore-master verify)
- Small-group viability: ToV bosses covered by audit

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
Entry requires **the 13-part Vex Thal key quest**, with shards
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
progression rework). Vex Thal's 13-shard key quest (lore-master
Task #10) is a progression-phase of its own.

### Luclin raid quest chains

> **Status:** Game-designer summary pending lore-master deep-review.

**Scope:** Vex Thal shard quest (13-part key quest — the densest
raid-progression in the game), Emperor Ssraeshza key quest, Sanctus
Seru / Katta Castellum progression, Luclin-specific class AA-
precursor quests, any Luclin-tier components of Epic 1.0s that
extend this late.

---

#### Vex Thal key quest (13 shards)

- **Class/scope:** General raid access — VT contains some of the
  best in-era loot and the Aten Ha Ra cluster
- **Era:** Luclin
- **Zones:** ALL Luclin raid zones + some mid-level Luclin zones
- **Turn-in NPCs:** Final key forge NPC (lore-master verify —
  traditionally in Shadow Haven or Umbral Plains)
- **Raid encounters required for the 13 shards:**
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
- **Vex Thal 13-shard count** — flag for reduction decision
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

> Populated at consolidation. Shows which quest chains share boss
> encounters (e.g. multiple epics rely on Faydedar; VT shards draw
> from many zones).

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
| 13 | The Avatar of War | kael | 900,000 | 1,154 | 30× HP + damage |
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
- **King Tormax / Avatar of War (kael):** Warrior, SK, Paladin Epic
  steps and Kael faction
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

### 9. Special-case encounters flagged for non-standard handling

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
- [ ] Every raid-tier quest chain cataloged — **pending lore-master
  Tasks #7-10 completion**
- [x] Cross-reference matrix of boss counts by zone (in `### Raw
  boss counts`)
- [x] Headline findings summary (this section)
- [x] Recommended user decisions list (above)

**This deliverable is COMPLETE FROM THE GAME-DESIGNER SIDE.** Final
consolidation (task #11) merges with lore-master quest-chain work
when their Tasks #8, #9, #10 complete. The PRD at
`game-designer/prd.md` will be updated with the design-intent summary
(scope, philosophy, success criteria) to feed the Phase 3 architecture
phase.
