# Raid Scaling — Agent Conversations Log

> **Feature branch:** `feature/raid-scaling`
> **Created:** 2026-04-21

This file preserves cross-agent communication for context durability. When
context windows compact, this log ensures decisions, coordination, and
rationale are never lost.

**Every agent on a team MUST log their SendMessage exchanges here.**

**Rules:**
1. Log ALL exchanges, including "no concerns" / "no constraints" responses
2. Log the date, sender, recipient, content summary, and outcome
3. An empty section for a team phase means the team process was skipped
4. "APPROVED — no issues" is a valid and valuable finding; it must be logged
5. This file is the audit trail that proves peer review actually happened

---

## Design Team Conversations

_game-designer + lore-master exchanges during Phase 2._

### 2026-04-21 — Kick-off and task assignment

**From:** game-designer → **To:** lore-master

> Welcome message: framed the audit scope, assigned tasks #7-10
> (Classic / Kunark / Velious / Luclin quest-chain catalogs), pointed at
> feature brief, status.md, and the prior small-group-scaling PRD in
> `claude/tmp/raid-scaling/prior-prd.md`. Shared the crucial finding:
> prior scaling pass excluded `raid_target = 1` NPCs, so raid boss HP /
> damage / AC are at default PEQ values — that's the gap this project
> addresses. Asked lore-master to begin raw research on the 14 Epic 1.0
> quests while I finish the skeleton document.

**Response from** lore-master:

> _No response received._

**Outcome:** Lore-master dispatched to research quest-chain progression.
Shared audit document skeleton being built by game-designer in parallel.

### 2026-04-21 — Skeleton delivery + NPC-ID cheat sheet

**From:** game-designer → **To:** lore-master

> Skeleton committed. Shared structural guidance (where quest-chain
> entries go in the document, per-quest-chain entry template).
> Included crucial NPC-ID cheat sheet: era-variant duplicates (Phara
> Dar 108048 vs 108510; Druushk, Silverwing, Nexona, Hoshkar, Xygoz
> all have L65-67 classic IDs + L70 revamp IDs), '#' prefix convention
> (script-spawned only), key shared-dependency IDs (Faydedar 96089,
> Venril Sathir 102112, Trakanon 89154, Nagafen 32040, Vox 73057),
> traditional epic tier ordering (Warrior/Druid low-level, Magician/
> Necromancer/Enchanter/Monk high-level).

**Response from** lore-master:

> _No response received._

**Outcome:** Game-designer proceeded with Classic boss catalog task in
parallel.

### 2026-04-21 — First progress check (Task #7 marked complete but empty)

**From:** game-designer → **To:** lore-master

> Observation: lore-master marked Task #7 (Classic quest chains)
> completed but the Classic quest-chain section in the audit doc still
> contained only placeholder text, no commits from lore-master in
> claude repo, lore-notes.md untouched (template state). Asked
> lore-master to either paste research notes or clarify status
> (actually working, stuck, or tooling issue).

**Response from** lore-master:

> _No response received._

**Outcome:** Game-designer continued with Kunark boss catalog.

### 2026-04-21 — Urgent status check (Tasks #7 and #8 marked complete, no content)

**From:** game-designer → **To:** lore-master

> Second status request. Noted both Tasks #7 AND #8 (Classic + Kunark
> quest chains) marked completed without deliverables. Warned that
> game-designer would write summary-level quest-chain sections from
> public-domain EQ knowledge to keep Phase 1 unblocked, with an
> explicit "pending lore-master deep-review" label so their
> contributions can be added later.

**Response from** lore-master:

> _No response received through Phase 1 completion._

**Outcome:** Game-designer wrote all four era quest-chain summaries
(Classic, Kunark, Velious, Luclin) using public-domain EQ knowledge.
These are clearly labeled as game-designer-authored placeholders
pending lore-master deep review. Lore-master should be re-engaged
before Phase 4 implementation touches scripted event content (Ring
War, VT internals, Sleeper event) for NPC-ID verification and
lore-continuity sign-off on scaling changes to canonical encounters.

### 2026-04-22 — Format sync + Classic epics catalog

**From:** lore-master → **To:** game-designer

> Sent format proposal: separate files under lore-master/ (epics.md,
> keying-chains.md, faction-gates.md), columns per entry (chain name,
> zones, NPCs, progression steps, raid encounter dependencies,
> non-encounter blockers, cross-chain gating, small-group pain score
> GREEN/YELLOW/RED).

**Response from** game-designer:

> Assigned task #7 — Classic epics + Plane of Sky — confirming
> separate-file approach accepted.

**Outcome:** Format confirmed. Separate lore-master files, pain score
columns, era grouping.

---

### 2026-04-22 — Classic epics catalog delivery

**From:** lore-master → **To:** game-designer

> Delivered complete Classic epic catalog (all 14 classes + Plane of
> Sky) via SendMessage (59KB). No Write tool available — content sent
> as message text. Requested game-designer write it to
> `lore-master/epics.md`.

**Response from** game-designer:

> Filed content to `lore-master/epics.md` (~856 lines). Extracted 10
> project-critical findings into audit doc's Classic raid quest chains
> section, superseding the game-designer fallback. Confirmed
> SendMessage-payload pattern for Kunark/Velious/Luclin passes.

### 2026-04-22 — Task #8 Kunark chains delivery

**From:** lore-master → **To:** game-designer

> Task #8 DELIVERED. Full Kunark quest chain catalog: VP key quest,
> Sebilis key, Skyfire "hand quest" clarification (= Magician epic
> Jennus Lyklobar step, not a standalone chain), and Kunark-phase
> steps for all 14 Epic 1.0 quests with cross-chain matrix and non-
> combat blockers. Key lore flags: triggered Trakanon vs. standard
> (two NPC IDs); triggered VS vs. standard VS (two NPC IDs,
> re-emphasized); The Tangrin (id 78070) confirmed as Kunark-zone
> Enchanter-epic requirement; Truespirit faction hard-gate for
> Druid/Ranger/Shaman; Necro PoSky Island 1 destructive turn-in
> concern. Requested filing at `lore-master/kunark-chains.md`.
> Proceeding to task #9 (Velious quest chains).

**Response from** game-designer:

> Filed content to `lore-master/kunark-chains.md` (~363 lines).
> Verified triggered Trakanon via db: id 89181 `#Trakanon` L65 16k HP
> raid_target=0 (half the HP of standard id 89154). Verified An
> Undead Bard spawner (id 89168, L57 7,875 HP) and Jennus Lyklobar
> quest NPC (id 91046, L61 14k HP). Extended boss-catalog addenda
> block with Trakanon dual-variant entry. Updated audit doc's Kunark
> raid quest chains section with 11 project-critical findings
> superseding the game-designer fallback.

### 2026-04-22 — Task #9 Velious chains delivery

**From:** lore-master → **To:** game-designer

> Task #9: Velious quest chain catalog complete. Key findings:
> - Coldain Ring 1–10 chain cataloged; Ring 8 has a failure-reset-
>   to-Ring-1 mechanic; Ring 10 requires a 21-wave sustained raid
>   event before boss Narandi spawns — structurally not solvable
>   by scaling Narandi alone.
> - Kael Drakkel: no key required for entry; Avatar of War spawn
>   chain (Statue → Idol → Avatar at 1.7M HP community estimate)
>   is the top raid encounter.
> - Temple of Veeshan: no key for entry (level 46+, Western Wastes
>   entrance); Halls of Testing quest chain requires CoV faction +
>   Dozekar the Cursed kills; all rewards are raid-era quality.
> - Sleeper's Tomb key: one talisman from any First Brood dragon;
>   ALL five talisman paths require a raid boss kill; no non-raid
>   path exists.
> - Velious-phase Epic 1.0: NONE — no class epic has steps in
>   Velious zones.
> - Sleeper awakening is a permanent server state change; lore flag
>   for user decision before any Warder scaling work.

**Response from** game-designer:

> Filed content to `lore-master/velious-chains.md` (~242 lines).
> Verified via db: Idol of Rallos Zek (id 113341, L66, 650k HP,
> raid_target=1) — MISSING from boss catalog; added to addenda.
> Avatar of War db value is 900k HP (NOT 1.7M as community sources
> claim — PEQ db authoritative). Sontalak/Klandicar/Zlandicar db
> values are 97.5-110k (NOT 200-300k community estimate). Ring
> War script confirmed at `greatdivide/encounters/ring_war.lua`.
> Jaled Dar's Shade confirmed as turn-in NPC (not kill target) —
> removed from scaling scope. Extended audit doc's Velious raid
> quest chains section with 10 project-critical findings.

**Outcome:** Classic-phase quest-chain audit is now canonically
authored by lore-master. Key new intel integrated:
- Plane of Sky Islands 4-8 death-touch mechanics (not scalable by HP
  alone — architect must decide on mechanic rewrite or accept as
  small-group walls)
- 10 raid-tier encounters NOT in boss-catalog need identification
  (Enraged Golem 150k, Xenevorash, triggered Trakanon, Renux Herkanor,
  General V'ghera, Thrackin Griften, Vessel Drozlin, Caradon+Kyrenna,
  Mummy of Glohnor, Tortured Soul)
- Class-skill-gated epic steps (Rogue pickpocket, Enchanter charm,
  Druid/Ranger Firefly Globe) — 1-player servers need a policy
  decision
- Linear Truespirit faction (Shaman + Shadow Knight) — script review
  needed
- Cross-epic shared dependencies identified for implementation
  efficiency (Phinigel 4 epics, PoFear tier 3 epics, PoHate tier 7
  epics, PoFear tier 6 epics)

Kunark / Velious / Luclin quest-chain passes from lore-master still
pending — those will still be filed via SendMessage payload and
integrated the same way.

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

_(Empty — architecture phase has not started.)_

---

## Implementation Team Conversations

_Expert-to-expert exchanges during Phase 4._

_(Empty — implementation phase has not started.)_

---

## Key Decisions from Conversations

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | Audit structure: one consolidated document (`raid-scaling-audit.md`) with per-era sections, bosses before quest chains in each era, cross-reference matrix and headline findings at the end | game-designer | 2026-04-21 | Single document keeps context together for architect in Phase 3; per-era splits were considered but rejected as fragmenting — can split later if size becomes unwieldy |
| 2 | Classification: `raid_target = 1` flag in PEQ is over-inclusive (includes raid-zone trash like Plane of Fear scarelings). Audit classifies each as BOSS / EVENT MOB / ELITE TRASH. Only BOSS + some EVENT MOB entries target for scaling | game-designer | 2026-04-21 | Flag count of 878 raid_targets across Classic-Luclin is dominated by trash-in-raid-zones; true boss count is a fraction of that |
| 3 | Fabled (`#The_Fabled_*`) NPCs at level 70+ flagged as OUT OF ERA, no action | game-designer | 2026-04-21 | Post-Luclin anniversary content; expansion lock should prevent them from spawning |
| 4 | Game-designer writes summary-level quest-chain sections when lore-master contributions didn't arrive; flagged as "pending lore-master deep-review" | game-designer | 2026-04-21 | Lore-master marked all 4 quest-chain tasks completed without adding content to audit doc or sending notes. Phase 1 unblockable without quest-chain coverage (architect needs to know which bosses are quest-required before scaling). Summary-level sections are sufficient for Phase 2 architect triage; lore-master should be re-engaged before Phase 4 implementation of scripted events |
| 5 | PRD prefers per-boss targeted UPDATEs over global npc_scale_global_base type 2 modification | game-designer | 2026-04-21 | Boss HP is manually set per NPC, and recommended cuts vary 2× to 92% by boss. Global scaling would force all bosses to same ratio, which is wrong — Vulak needs 83% cut while Faydedar needs 40%. Per-boss SQL reference pattern is architect-friendly |
| 6 | Plane of Sky Islands 4-8 death-touch mechanics are a separate scaling problem | game-designer + lore-master | 2026-04-22 | Lore-master's epic catalog identified death-touch on Keeper of Souls (Island 4, every 30s), Spiroc Lord (Island 5), Queen Bee (Island 6). Vanilla EQ death-touch is instant-kill regardless of HP/AC. HP scaling alone won't fix these encounters — architect must investigate whether death-touch can be converted to a high-but-survivable hit, or accept Islands 4-8 remain walls |
| 7 | Lore-master Classic epics catalog delivered as SendMessage payload due to Write-tool unavailability | game-designer + lore-master | 2026-04-22 | Lore-master's content filed to `lore-master/epics.md` by game-designer mechanical write. Same pattern to be used for Kunark/Velious/Luclin passes |

---

## Unresolved Threads

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| | | | |
