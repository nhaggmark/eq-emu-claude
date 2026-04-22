# Raid Scaling — Product Requirements Document

> **Feature branch:** `feature/raid-scaling`
> **Author:** game-designer (mechanical audit + design intent) + lore-master (quest-chain audit)
> **Date:** 2026-04-21
> **Status:** Draft — Phase 1 (Audit) — pending lore-master quest-chain sections

---

## Problem Statement

EverQuest's raid content — from Classic through Luclin — was designed
for 24-72 coordinated players with dedicated healer/tank/dps stacks.
Our server targets **1-3 players + up to 5 companions per player**
(the recruit-any-NPC companion system). A prior small-group-scaling
project (completed 2026-02-23) tuned overland and group dungeon
content for this scale, but **deliberately excluded raid bosses**
from HP/damage/AC cuts, noting they should be "deferred to the
companion system". That was the right call at the time — the
companion system wasn't live yet. It is now.

The result today: every one of ~140 raid encounters across Classic,
Kunark, Velious, and Luclin sits at default PEQ values. HP pools
range from 15,750 (Drusella Sathir) to **1,901,500 (Aten Ha Ra)** —
in the worst case that's **63× a scaled-named at the same level**.
Max damage on several raid bosses (Kilidna 4,600, Nexona 2,475,
Kaas Thox 1,650) is an automatic one-shot for any tank a small
group can field. Respawn timers average 54-130 hours, outside the
brief's 6-24h target.

Raid content, and the dozens of epic / keying / faction quest chains
that depend on raid bosses, is effectively walled off from small-
group play despite the companion system being live. That wall is
the problem.

## Goals

1. **Raid bosses beatable by 1 player + 5 companions** (~6 effective
   bodies), with occasional flex up to 2-3 players each with a full
   companion roster.
2. **Bosses sit "slightly harder than current named mobs"** —
   preserving their status as meaningful encounters without them
   being categorically different from the named mobs the small
   group has already been clearing.
3. **Tiered mechanical difficulty curve:** early-era raids
   (Nagafen, Vox, Classic Fear/Hate/Sky) are mechanically
   challenging (positioning, adds, coordination); endgame raids
   (ToV, Sleeper, Vex Thal, Emperor Ssraeshza) are peak mastery —
   preparation matters, mistakes punish, they represent the wall.
4. **Respawn timers** reduced to 6-24h range — small-group-friendly
   cadence without making kills feel trivial.
5. **Epic 1.0 chains and keying progressions completable by a
   small group.** Every quest chain that currently requires a raid
   must be beatable at 1-3 players (with companions).
6. **Loot tables unchanged** — stock drop rates and items. Raid
   kills remain loot piñatas; a solo player's kill is showered in
   gear. Lean into the "earned reward" feel.
7. **Reversible implementation.** Prefer `rule_values` and
   database tuning over C++ changes (the prior project's precedent).

## Non-Goals

- Changes to trash or named difficulty in raid zones — the prior
  pass addressed these and the user explicitly confirmed "current
  named difficulty feels good, do not touch".
- Loot table redesign — out of scope per brief.
- New raid content, mechanics, or encounters — we are scaling
  existing encounters, not redesigning them.
- Post-Luclin content — expansion lock remains at 3 (Luclin).
- Changes to the signature abilities and immunities that define
  "raid boss identity" (summon, enrage, rampage, magic-immune,
  etc.). Small groups should learn around these, not have them
  removed.
- Sleeper-awake event (Kerafyrm) — narrative/world event, not a
  scaling target. Remains untouched.

## User Experience

### Player Flow

1. **Classic bosses (e.g. Nagafen, Vox, Lady Vox):** A small
   group at level 55-60 with their full companion roster and a few
   consumables can attempt these bosses. The fight is tough —
   summon forces positioning, enrage punishes slow kills, rampage
   catches the group at wrong times — but it is winnable in 1-3
   attempts. The group feels challenged, not walled.
2. **Kunark bosses (Trakanon, VS, outdoor dragons, VP):** Outdoor
   dragons are a one-pull raid for a geared group. Sebilis's
   Trakanon is a prep fight (Cure Disease, focus DPS). Venril
   Sathir's lich transition forces adaptation. Veeshan's Peak
   remains an endgame wall but is now scalable — tackle the
   outer dragons first, work toward Phara Dar, etc.
3. **Velious bosses:** Kael (Tormax, Avatar of War) and Skyshrine
   (Yelinak, Crusaders) are progression milestones — beatable
   with class composition and strategy. Temple of Veeshan is
   the "come back with your A team" zone. Sleeper's Tomb is a
   separate arc — Ancients and Warders as progression-locked raid
   targets.
4. **Luclin bosses:** Emperor Ssraeshza trio, Akheva, Seru/Katta
   faction war — all tractable. Vex Thal is the most scripted
   zone in the game; bosses are beatable but the 13-shard key
   quest is the real progression wall.
5. **Respawn cadence:** a small group can target a boss, die, and
   come back the same real-world day (6-24h respawn) rather than
   waiting 3-5 days.
6. **Epic 1.0 progression:** Every class can complete their epic
   through the recruit-any-companion model. Raid-boss-required
   steps (Faydedar, VS, Trakanon, Dracoliche, Noble Dojorn, Avatar
   of War, etc.) are beatable.

### Example Scenario

A level 60 enchanter with 5 companions (a warrior tank, cleric,
shaman, wizard, mage) wants to kill Trakanon for their guild-
hall piece quest. They zone into Sebilis, work their way down
(already using the prior pass's scaled-named tuning for trash
and named mobs, which feel right). They reach Trakanon's lair.
At current stats Trakanon has 32,000 HP and hits 144-630 —
already within small-group range after the audit-recommended
30% HP cut (post-implementation he'd have 22,400 HP) and
flurry-chance trim. The enchanter mezzes the one add; the
companions follow a buff-pull-tank-dps routine; the player
runes themselves defensively; the cleric Complete Heals the
tank at 20% HP. Trakanon's 630-max-damage hit is tank-
survivable with shaman MR buffs. Kill time ~3 minutes.
Loot: some raid-tier items that drop on post-prior-pass
probability curve.

## Game Design Details

### Mechanics

The audit (see `raid-scaling-audit.md`) produced four numerical
levers for the architect to apply per-boss:

**Lever 1 — HP reduction.**
- Endgame tier (top ToV, Sleeper top, Vulak, AoW, Vex Thal top,
  Emperor, Seru, Xygoz/Nexona VP revamp, High Priest of Ssraeshza):
  **80-92% HP cut** (targets 80-150k HP).
- Mid-boss tier (most ToV, most Sleeper, Akheva top, Grieg
  Veneficus, Thought Horror, Velketor, Narandi, King Tormax,
  Yelinak, Praesertum, Vyzh`dra): **70-85% HP cut** (targets
  40-100k HP).
- Low-boss tier (Skyshrine Crusaders, Growth mid, VP classic-
  variants, Khati Sha, outdoor Velious, Shar Vinitras, Seru
  Praesertum, Kael Derakor): **50-75% HP cut** (targets 40-80k HP).
- Near-named tier (Classic Fear/Hate/Sky bosses, Nagafen/Vox,
  Kunark outdoor dragons, Trakanon, VS, Chardok royals, Western
  Wastes outdoor dragons, Hate council, Luclin Rumblecrush/
  Zelnithak): **20-50% HP cut** (targets 15-30k HP).

**Lever 2 — Damage reduction.**
- Apply only where max_damage is a one-shot risk (>800 for tanks
  with sub-2.5k HP effective pool).
- Worst offenders needing 40-75% damage cut: Kilidna (4,600 →
  1,000), Nexona (2,475 → 1,000), Xygoz (2,266 → 900), Kaas
  Thox (1,650 → 800), Diabo Xi Va Temariel (1,400 → 770), Vulak
  (1,400 → 800), Va Xi Aten Ha Ra (1,254 → 750), Avatar of War
  (1,154 → 700), Lord Vyemm (1,200 → 700), Diabo Xi Xin (1,200 →
  650).
- Most bosses need no damage change — current damage is already
  within "dangerous but survivable" for a scaled small group.

**Lever 3 — Respawn timer.**
- Target: endgame = 24h, mid-boss = 12h, low-boss = 6h, near-
  named = 6h or shorter.
- Nearly universal reduction needed — current PEQ defaults are
  54-130h after prior pass's ×0.75 cut.

**Lever 4 — Ability trims (narrow).**
- Cazic Thule's rampage 10×7 → 3×3 (no small group has 7 bodies
  to absorb concurrent rampage).
- Avatar of War's rampage 6×6 → 3×3.
- Consider removing Unslowable (U) from select Velious/Luclin top
  bosses (not all) to give slow-class small groups a tool.
- Everything else preserved — summon, enrage, mez/charm/normal/
  magic immunity, flurry-on-ranged-bosses, etc.

### Balance Considerations

- **Companion system is THE enabler.** Scaling math assumes 1
  player + 5 companions is ~6 effective bodies. If 2-3 humans
  play together with full companion rosters, encounters are
  somewhat easier — this is intended. Companion mana/HP pools
  and class-appropriate AI (scaled spell priority, healer cleric
  behavior, caster LoS, etc.) are all load-bearing dependencies.
- **Per-boss tuning, not globally scaled.** The architect should
  NOT update `npc_scale_global_base` type 2 (raid baseline) —
  boss HP pools are manually set per NPC, and the audit's per-
  boss recommendations preserve lore/mechanic-appropriate
  differences (e.g. Vyemm's MR wall, Dain Frostreaver's faction
  gating, Guardian of Veeshan's AE-rampage).
- **Loot unchanged = solo player showered in gear.** A geared
  1-player group clearing Classic raids will progress faster
  than on a stock server. This is intended — "earned reward"
  feel.
- **Mechanics over stats for lore-central bosses.** Cazic Thule,
  Vulak`Aerr, Aten Ha Ra, Emperor Ssraeshza — these define era
  identity. Their mechanics (Mortal Coil, dragon breaths, death
  beam, Serpent-Lord summons) should be preserved. Scaling is
  HP + damage, not mechanic removal.

### Era Compliance

- Every encounter audited exists in Classic, Kunark, Velious, or
  Luclin. No post-Luclin content is scaled.
- Fabled (`#The_Fabled_*`) and Legends-of-Norrath anniversary
  content (identified in audit: Legendary Behemoth L72, Legendary
  Velious Dragon L72, Seventh Hammer L73, Netherbian Swarmfiend
  L73, etc.) are flagged OUT OF ERA — no action.
- Mischief Plane revamp (L75 Bristlebane) is OOE.
- Cazic Thule at L70 is a PEQ-era creep vs. Classic's L50 cap —
  audit recommends dropping to L65 for era alignment (user
  decision).

## Affected Systems

- [ ] C++ server source (`eqemu/`) — **Not required** — all
  scaling via database tuning per prior-pass precedent
- [ ] Lua quest scripts (`akk-stack/server/quests/`) — **Possibly**
  — if user chooses to update VP quest scripts to target classic-
  era dragon variants (108509-108517) instead of revamp (108040-
  108053). See audit decision B.
- [ ] Perl quest scripts — **Not touched**
- [x] Database tables (`peq`) — `npc_types` (per-boss HP, min/max
  dmg, AC, special_abilities, npcspecialattks), `spawn2`
  (respawntime per raid-boss spawn)
- [ ] Rule values — **Likely not needed**. Global rule levers
  (NPCFlurryChance, MaxRampageTargets, NPCAssistCap, StartEnrage)
  were already tuned by the prior pass and those settings already
  apply to raid bosses. Per-boss `special_abilities` overrides
  are the surgical tool.
- [x] Server configuration — **Not touched** — expansion lock
  already at Luclin.
- [ ] Infrastructure / Docker — **Not touched**

## Dependencies

1. **Companion system must be stable.** Recent bug batches
   (BUG-019 through BUG-035) cleaned up companion combat AI,
   targeting, buff queue, and gear-handling. Raid-scaling
   assumes companions behave correctly in sustained raid
   encounters.
2. **Prior small-group-scaling pass in effect.** All rule_values
   (GlobalLootMultiplier=2, NPCFlurryChance=12, MaxRampageTargets=2,
   NPCAssistCap=3, regen/xp multipliers, etc.) remain applied.
   Raid-scaling doesn't change these.
3. **Lore-master quest-chain audit completion.** Before the
   architect plans Phase 3 implementation, the epic/keying
   dependency map must be complete — otherwise scaling changes
   might unintentionally gate required quest progression.
4. **Backup tables.** Architect to back up
   `npc_types.{hp,mindmg,maxdmg,AC,special_abilities,npcspecialattks}`
   for all `raid_target = 1` NPCs before writing. The prior pass's
   `npc_types_backup_sgs` table covers non-raid NPCs only — raid
   bosses need their own backup.

## Open Questions

The audit at `raid-scaling-audit.md` produced 8 concrete user
decisions (section "Recommended User Decisions"). The Phase 3
architect should drive user resolution on these before
implementation planning:

A. Phased delivery strategy (single sustained / per-era / tier-first)
B. Veeshan's Peak variant choice (revamp IDs or classic-era IDs)
C. Plane of Hate version (hateplane or hateplaneb)
D. Vex Thal Yaemiu elite trash scope (include or exclude)
E. Respawn timer targets (specific values per tier)
F. Sleeper-awake event handling (leave untouched as narrative)
G. Cazic Thule era alignment (drop to L65 or leave at L70)
H. Lord Vyemm MR wall / other signature mechanics preservation

Additional technical unknowns for architect to investigate:

1. Does `special_abilities` column accept partial overrides per-NPC
   or is it a complete replacement? (Prior project implied complete
   replacement.)
2. How does PEQ's `npcspecialattks` letter-code interact with
   per-NPC abilities — is it deprecated?
3. Are the duplicate NPC IDs (Phara Dar classic vs revamp,
   Yelinak main vs variant, Final Arbiter main vs sub, etc.)
   used by any active quest script that would break if one is
   dropped?

## Acceptance Criteria

_Phase 1 audit acceptance criteria._ Phase 2-5 implementation
criteria will be defined per-phase by the architect.

- [x] Every raid boss in Classic-Luclin cataloged with current
  stats, prior-pass status, gap vs. target, and recommended action
- [x] Prior small-group-scaling pass impact documented per-boss
- [x] Cross-reference matrix of per-zone raid_target counts
- [x] Headline findings summary
- [x] 8+ concrete user-decision questions surfaced
- [ ] Every raid-tier quest chain cataloged — pending lore-master
  (tasks #7-10)
- [ ] Lore-master sign-off on the complete audit

---

## Appendix: Technical Notes for Architect

These are notes from the game-designer's database investigation.
Advisory only — architect determines all implementation approach.

### Schema details

- `npc_types` columns to modify per-boss: `hp`, `mindmg`, `maxdmg`,
  `AC`, `special_abilities`, `npcspecialattks`
- `spawn2.respawntime` is in seconds. Current range 640 (11m) up
  to 468,720 (130h / 5.4 days).
- `npc_scale_global_base` type 2 is the auto-scale baseline for
  raid tier — **do not modify** (per prior-pass precedent and
  because boss HP is already manually set).

### SQL scoping concerns

- Target NPCs via BOTH `raid_target = 1` AND explicit ID lists
  (because `raid_target = 1` includes ~750 elite-trash entries
  that are out of scope per the "named feels good" brief).
- The audit's per-era summary tables list explicit IDs to scale.
- Filter out `name LIKE '#The_Fabled%'` across all queries.
- Filter out `level >= 71` (post-Luclin cap) unless architect
  confirms in-era NPC exists at that level (e.g. Cazic Thule
  L70).

### Duplicate-ID resolution

The architect should investigate which of each duplicate pair is
"live" by:
1. Checking `spawnentry` membership — is NPC in active rotation?
2. Checking quest script references — which ID does a script
   actually spawn?
3. Running `#findnpc <name>` in game to see active spawns.

Once resolved, scale only the live variant. Optionally clean
unused variants from npc_types (separate task, not required for
scaling work).

### Backup strategy (suggestion)

```sql
CREATE TABLE npc_types_backup_raid_scaling AS
SELECT id, hp, mindmg, maxdmg, AC, special_abilities, npcspecialattks
FROM npc_types
WHERE raid_target = 1
  AND level BETWEEN 45 AND 70
  AND name NOT LIKE '#The_Fabled%';
-- Expected count: ~750 rows (includes elite trash — harmless
-- to back up extra, useful for any future decision to scale)
```

And for respawns:
```sql
CREATE TABLE spawn2_backup_raid_scaling AS
SELECT s2.id, s2.respawntime
FROM spawn2 s2
JOIN spawnentry se ON se.spawngroupID = s2.spawngroupID
JOIN npc_types nt ON nt.id = se.npcID
WHERE nt.raid_target = 1 AND nt.level BETWEEN 45 AND 70;
```

### Implementation suggestion: per-boss UPDATE blocks

Unlike the prior pass's global UPDATE with `raid_target = 0`
filter, the raid-scaling implementation needs per-boss targeting
because (a) recommended changes vary 2× to 92% by boss, and (b)
special-case entries (Sleeper event, Fabled, OOE) must be
explicitly excluded.

Pattern (for architect's execution planning):
```sql
-- Example block — Vex Thal top tier
UPDATE npc_types SET hp = 180000 WHERE id = 158096;  -- Aten Ha Ra
UPDATE npc_types SET hp = 160000, maxdmg = 800 WHERE id = 158007;  -- Kaas Thox
-- ... one block per tier cluster
```

The audit's summary tables already list per-boss recommended
values. The architect can emit an implementation SQL reference
document the same way the prior project did
(`architect/context/implementation-sql-reference.md`).

---

> **Next step:** Pass this PRD (together with the full audit at
> `raid-scaling-audit.md`) to the **architect** for technical
> feasibility assessment and implementation planning. Architect
> should:
> 1. Drive user resolution on the 8 open decisions (A-H above)
> 2. Resolve the duplicate-ID question across ~15 encounter pairs
> 3. Design the per-boss implementation SQL organization (per-era
>    or per-zone-cluster file structure)
> 4. Identify any Lua/Perl quest-script changes required (most
>    likely none if user keeps VP revamp variants)
> 5. Create the rollback/revert SQL script
> 6. Plan the implementation task breakdown — recommend matching
>    the audit's per-era + per-cluster structure
