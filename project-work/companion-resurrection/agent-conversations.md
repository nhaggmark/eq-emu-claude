# Companion Resurrection System — Agent Conversations Log

> **Feature branch:** `feature/companion-resurrection`
> **Created:** 2026-03-15

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

### 2026-03-15 — Early Lore Input: Rez System Design

**From:** game-designer → **To:** lore-master

> Requested early lore input on four topics:
> 1. Confirmation of era-appropriate rez spells by class (CLR, PAL, NEC)
> 2. Necromancer Convergence reagent (Essence Emerald) — waive or exclude?
> 3. Resurrection flavor text — deity-specific language
> 4. Death & resurrection theme — concern about cheapening resurrection

**Response from** lore-master (proactive research):

> Detailed findings delivered:
> - **Spell ladder**: Corrected levels and XP values vs game-designer's initial research. Key corrections: Revive is 0% XP not 35%, Resuscitate (CLR 39, 50%) was missing from initial list, Reanimation (CLR 12, PAL 22) should be included.
> - **Necromancer HARD BLOCK**: Convergence requires Essence Emerald from Sacrifice ritual — companion cannot autonomously harvest this. Two options: (a) waive with dark-flavor lore, (b) exclude necro rez entirely. Recommended option (a).
> - **Deity context**: Rez is explicitly tied to divine faith. Provided deity-specific dialogue examples for Rodcet Nife, Tunare, Innoruuk, Mithaniel Marr, Bertoxxulous. Noted that fallback to class-based generic text is needed if deity field is unpopulated.
> - **Era compliance**: All CLR/PAL spells confirmed Classic era on P99. Hard stops: Divine Resurrection (post-Luclin), Gift of Resurrection (GoD).
> - **Narrative tone**: Frequency doesn't cheapen rez if dialogue, recovery period, and mana cost are present. One-line acknowledgment is EQ's style.

**Outcome:** PRD updated with all corrections across three rounds:
- Round 1: Spell ladder corrected, Resuscitate added, Necro resolved via death-energy justification
- Round 2: Deity dialogue table added, era exclusion list hardened, "raised" vs "resurrected" for necro
- Round 3: Reanimation re-added to spell table, all spell values flagged for spells_new verification, deity fallback added to open questions

### 2026-03-15 — Detailed Lore Answers (second lore-master message)

**From:** lore-master → **To:** game-designer

> Full answers to all four initial questions plus additional context:
> - Spell ladder: "Bottom line — rez-capable classes are Cleric, Paladin, Necromancer only. Exact spell IDs and XP% should come from spells_new — architect resolves precise numbers."
> - Necro recommendation: Option A with explicit dark-flavor framing. "The fallen enemies provided enough — their deaths fuel your return." Necro rez should feel different from cleric's.
> - Deity dialogue examples provided with note about fallback.
> - Cheapening concern addressed: "Frequency alone doesn't cheapen resurrection. Weight comes from dialogue, recovery period, and mana cost."

**Response from** game-designer:

> Applied final fixes: Reanimation re-added, spell verification note added, deity fallback note added. Requested final sign-off.

**Outcome:** _Awaiting lore-master final sign-off_

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

### 2026-03-15 — Protocol Feasibility Check

**From:** architect → **To:** protocol-agent

> Requested assessment on three protocol-level questions:
> 1. Does the Titanium client correctly display `OP_RezzRequest` when `rezzer_name` is an NPC name? (e.g., "Priestess Grel")
> 2. For auto-accept companion rez (bypassing `OP_RezzRequest`), are there packet-level requirements for the client to see the rez? Specifically: `OP_Action`/`OP_BeginCast` for cast animation, `OP_DeleteSpawn` for corpse removal, standard spawn packets for companion reappearance.
> 3. Any Titanium client quirks around NPC corpse targeting by NPCs, or rez spell visual effects?

**Response from** protocol-agent: _Pending — architect proceeded with draft based on protocol analysis from source code. The `Resurrect_Struct` at `eq_packet_structs.h:2968` has `rezzer_name[64]` as a plain char array — no player-specific validation. The companion rez path bypasses `OP_RezzRequest` entirely (auto-accept), using only standard spawn/despawn packets._

**Architect's assessment (pre-response):** No new opcodes needed. Player rez uses existing `Corpse::CastRezz()` → `OP_RezzRequest` flow. Companion rez uses entity creation/deletion which the client handles via standard packets. Low protocol risk.

### 2026-03-15 — Config/Rules Assessment

**From:** architect → **To:** config-expert

> Requested assessment on rule/config coverage for rez system:
> 1. Do any existing rules overlap with the 5 proposed new rules? (Specifically: `Mercs:ResurrectRadius` vs `Companions:RezRange`)
> 2. Does any existing rule control NPC XP death penalty?
> 3. Is there an existing rule for waiving spell reagent requirements?
> 4. Can any rez behavior be achieved through config alone without C++ changes?

**Response from** config-expert: _Pending — architect proceeded with draft. Analysis of `ruletypes.h` confirms no overlapping Companion rules exist. `Mercs:ResurrectRadius` is merc-specific. No NPC XP death penalty rule exists. No reagent waiver rule exists. The core rez logic (NPC corpse targeting, auto-accept, companion respawn) requires C++ — config/rules handle only the tunable values._

**Architect's assessment (pre-response):** All 5 proposed rules are new and non-overlapping. The core feature cannot be achieved through config alone — C++ is required for the spell effect handler extension, corpse metadata, rez AI, and companion resurrection lifecycle. Rules control all tunable parameters (enabled/disabled, range, delay, XP penalty, reagent waiver).


---

## Implementation Team Conversations

_Expert-to-expert exchanges during Phase 4._

### 2026-03-15 — data-expert → c-expert: Confirmed spell IDs and effect data

**From:** data-expert → **To:** c-expert

> Task 11 complete. Queried `spells_new` for all effectid=81 (SE_Resurrection) spells under ID 3000.
>
> **Confirmed rez spell IDs for C++ implementation:**
>
> | ID | Name | CLR lvl | PAL lvl | NEC lvl | Mana | XP% (effect_base_value1) |
> |----|------|---------|---------|---------|------|--------------------------|
> | 2168 | Reanimation | 12 | 22 | — | 150 | 0% |
> | 2169 | Reconstitution | 18 | 30 | — | 200 | 10% |
> | 2170 | Reparation | 22 | 31 | — | 250 | 20% |
> | 391 | Revive | 27 | 39 | — | 300 | 35% |
> | 2171 | Renewal | 32 | 49 | — | 400 | 50% |
> | 388 | Resuscitate | 37 | — | — | 500 | 60% (CLR-only) |
> | 2172 | Restoration | 42 | 55 | — | 600 | 75% |
> | 392 | Resurrection | 47 | 59 | — | 700 | 90% |
> | 1524 | Reviviscence | 56 | — | — | 600 | 96% |
> | 1733 | Convergence | — | — | 53 | 700 | 93% |
>
> **Key notes for C++ implementation:**
> - `effect_base_value1` is the XP restore percentage for all rez spells (effect ID 81)
> - Convergence (1733): `effect_base_value1=93` (XP%), `effect_base_value2=-90` (HP restore to target) — the XP% is in slot 1
> - All 17 rows now in `companion_spell_sets` with `spell_type=65536`, `priority=1`
> - 5 rule_values inserted: RezEnabled, RezPostCombatDelayS, RezRange, XPDeathPenaltyPct, RezWaiveReagents (all ruleset_id=1)
> - The architecture doc listed only 5 CLR + 2 PAL spells — database had 9 CLR + 7 PAL. All included as fallback ladder for mana management.
> - SQL migration: `claude/project-work/companion-resurrection/data-expert/context/add_rez_spells.sql`

**Awaiting response from c-expert.**

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication.
This table is the quick-reference for anyone catching up._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | Spell data must be verified from spells_new database, not third-party sources | game-designer, lore-master | 2026-03-15 | Third-party sources disagree on exact mana costs and XP values |
| 2 | Necro Convergence uses death-energy justification (Option A) | game-designer, lore-master | 2026-03-15 | Essence Emerald impossible for companions; lore-master recommended option A |
| 3 | Deity-themed rez dialogue with class-based fallback | game-designer, lore-master | 2026-03-15 | Rez tied to divine faith; fallback needed if deity field is 0 |
| 4 | "Raised" not "resurrected" for necro dialogue | game-designer, lore-master | 2026-03-15 | Thematic distinction: necro manipulates death energy, not divine power |
| 5 | Rez-capable classes: Cleric, Paladin, Necromancer only | game-designer, lore-master | 2026-03-15 | Druids/shamans confirmed no rez in Classic-Luclin |
| 6 | Rez priority: player > rezzers > other healers > tanks > DPS | game-designer | 2026-03-15 | Maximizes chain-rez recovery; druids/shamans prioritized as heal-capable |
| 7 | 10-second post-combat delay before rez attempt | game-designer | 2026-03-15 | Natural feel, mana regen window |
| 8 | Rez doesn't cheapen death if dialogue + recovery + mana cost preserved | lore-master | 2026-03-15 | Frequency alone is not the concern |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| Final lore sign-off on updated PRD | game-designer, lore-master | Awaiting lore-master response | Yes — need sign-off before handoff to architect |
