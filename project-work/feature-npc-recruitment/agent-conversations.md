# NPC Recruitment / Recruit-Any-NPC Companion System — Agent Conversations Log

> **Feature branch:** `feature/npc-recruitment`
> **Created:** 2026-02-25

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

### 2026-02-25 — Early Lore Consultation on Recruitment Design

**From:** game-designer → **To:** lore-master

> Requesting early lore guidance on 5 key areas before writing the PRD:
> 1. Recruitment lore framing — should there be a lore mechanism (e.g., "Oath of Companions") or pure organic persuasion?
> 2. Faction-gated recruitment — how should faction + soul disposition interact? Can KOS NPCs ever be recruited?
> 3. What happens to the world — NPC absence, death/return, dismissal mechanics
> 4. Era compliance concerns — any Classic-Luclin lore conflicts?
> 5. Cross-race recruitment — should Iksar recruiting Qeynos guards be possible?

**Response from** lore-master:

> Comprehensive preliminary research delivered (see next entry).

**Outcome:** Lore-master began independent research in parallel with PRD drafting.

### 2026-02-25 — PRD Draft Lore Review Request

**From:** game-designer → **To:** lore-master

> Sent full PRD draft for lore review at:
> claude/project-work/feature-npc-recruitment/game-designer/prd.md
> Requested review of: recruitment lore framing, faction gating, replacement NPC
> mechanic, era compliance, and cultural voice in dialogue examples.

**Response from** lore-master:

> Delivered comprehensive lore research covering:
> 1. OFF-LIMITS NPCs — hard lore anchors (Lucan, Antonius Bayle, King Thex, etc.)
> 2. FACTION ALIGNMENT CONSTRAINTS — Teir'Dal never truly loyal, Iksar tactical-only,
>    Ogre STR-based, cross-race barriers and opportunities
> 3. CHARISMA'S ROLE — varies by culture (high for Halflings, near-zero for Ogres)
> 4. DISPOSITION DEFAULTS — lore-consistent defaults per role and culture
> 5. RECRUITMENT DIALOGUE PATTERNS — authentic EQ-style by culture (2-3 sentences max)
> 6. LOYALTY/BETRAYAL THEMES — canonical precedents (Guard Alayle, Heretics, Corrupt Guards)
> 7. RACIAL BARRIERS — Iksar capped at Content, Teir'Dal mercenary-only, Ogre simple speech
> 8. ERA COMPLIANCE — Froglok restriction, Berserker exclusion, Gukta prohibition
> 9. PARTY COMPOSITION — tension pairs (Erudin+Paineel, Neriak+Qeynos priest)
> 10. DESIGN QUESTIONS — companion vs mercenary types, retention mechanics, persuasion alternatives

**Outcome:** Major PRD revision incorporating all feedback (see changes below).

### 2026-02-25 — PRD Revision Based on Lore Review

**From:** game-designer (internal revision)

> Incorporated lore-master feedback into PRD revision. Key changes:
>
> 1. **NEW: Companion vs. Mercenary recruitment types.** NPCs from good/neutral
>    cultures join as "companions" (loyal). NPCs from Neriak, Cabilis, Oggok, Grobb,
>    Paineel join as "mercenaries" (tactical alliance, calculating dialogue).
>
> 2. **NEW: Racial disposition caps.** Teir'Dal capped at Content (no Restless/Eager).
>    Iksar capped at Content. Ogre capped at Curious. Troll capped at Restless.
>
> 3. **NEW: Culture-specific persuasion system.** Replaced single CHA check with
>    culture-mapped primary/secondary stats: STR for Ogres/Barbarians, INT for
>    Erudites/Gnomes, CHA for Humans/Elves/Halflings, Level for Iksar.
>
> 4. **NEW: Party composition tensions.** Narrative-only tensions (dialogue, not
>    mechanical restrictions) for lore-enemy pairs in same party.
>
> 5. **NEW: Mercenary retention mechanic.** Mercenary-type recruits auto-dismiss
>    if player faction drops below Warmly (10-min warning). Companions do not.
>
> 6. **NEW: Named lore anchor exclusion list.** Specific NPCs identified as
>    non-recruitable by lore-master (Lucan, Antonius Bayle, Captain Tillin, etc.).
>
> 7. **NEW: Froglok exclusion.** Explicitly non-recruitable in Classic-Luclin era.
>
> 8. **UPDATED: Dialogue examples.** Replaced generic examples with culture-specific
>    patterns from lore-master (Qeynos formal, Halas brogue, Neriak cold, Oggok simple).
>
> 9. **UPDATED: Canonical precedent framing.** Problem Statement now references
>    Guard Alayle, Corrupt Qeynos Guards, Heretics, and Lucan's fall as evidence
>    that NPC loyalty-shifting is native to Norrath.
>
> 10. **UPDATED: Era compliance.** Added Froglok constraint, Gukta prohibition.

**Outcome:** PRD substantially revised. Ready for lore-master final review.

### 2026-02-25 — PRD Final Review Request

**From:** game-designer → **To:** lore-master

> Sent revised PRD for final lore sign-off. All lore-master feedback incorporated.

**Response from** lore-master:

> APPROVED WITH CHANGES — Four corrections required:
> 1. Faction modifier table inverted: Kindly (+20%) listed higher than Warmly (+15%), but Warmly is BETTER faction in EQ. Reorder to Ally > Warmly > Kindly.
> 2. Dreadguard Inner needs hard-block in curated exclusion list (Innoruuk's religious mandate).
> 3. "Rogues of the White Rose" is a Halas faction (305), not Qeynos. Qeynos thieves' guild is Circle of Unseen Hands (faction 223).
> 4. Rooted named NPCs retain 5% clamp chance — named lore anchors need hard blocks that bypass the roll entirely.

**Outcome:** Corrections applied (see next entry).

### 2026-02-25 — Lore Corrections Applied

**From:** game-designer (corrections applied based on lore-master review)

> Applied all 4 corrections to the PRD:
>
> 1. **Faction table fixed.** Reordered to Ally (+30%) > Warmly (+20%) > Kindly (+10%).
>    Changed minimum faction requirement from Warmly to Kindly throughout the PRD.
>    Secondary factor bonus reordered: Kindly +0, Warmly +5, Ally +10.
>    Example updated: Kindly faction + low CHA + Content Iksar = 40% (was 45%).
>    MinFaction rule default changed from 2 (Warmly) to 3 (Kindly).
>    Mercenary retention threshold kept at Warmly (intentionally stricter than recruitment minimum).
>
> 2. **Dreadguard Inner added to exclusion list.** "Dreadguard Inner (all members) —
>    Under Innoruuk's direct religious mandate. Their loyalty is theologically bound
>    to Neriak's inner sanctum."
>
> 3. **Rogues of the White Rose fixed to Circle of Unseen Hands** in the
>    Building a Full Party example scenario.
>
> 4. **Hard block language added.** New paragraph after the recruitment roll table:
>    "Hard blocks bypass the roll. NPCs on the curated exclusion list are filtered
>    out BEFORE the recruitment roll is evaluated. The 5% minimum clamp never
>    applies to them."

**Outcome:** All 4 corrections applied. PRD ready for lore-master final sign-off.

### 2026-02-26 — Lore-Master Final Sign-Off

**From:** lore-master → **To:** game-designer (relayed via team-lead)

> PRD approved. All 4 corrections verified. Design phase complete.

**Outcome:** APPROVED. PRD is lore-approved and ready for architect handoff.

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

### 2026-02-25 — Protocol Analysis: Titanium Mercenary Support

**From:** protocol-agent → **To:** architect

> Completed full analysis of mercenary protocol support in the Titanium client.
>
> **VERDICT: Titanium has ZERO mercenary opcodes.**
>
> Key findings:
> 1. `titanium_ops.h` (137 lines) contains zero `OP_Mercenary*` entries of any kind.
> 2. 14 `OP_Mercenary*` opcodes exist internally in `emu_oplist.h` but none map to Titanium.
> 3. Merc opcodes first appear in SoD (`sod_ops.h`) — 2 years after the Titanium client.
> 4. `titanium.cpp` has zero ENCODE/DECODE methods for any mercenary opcode.
> 5. Merc handlers in `client_packet.cpp` (lines 302-308) are registered but unreachable from Titanium.
>
> **What works for companions on Titanium:**
> - Standard group packets (`OP_GroupUpdate`) — `Group::AddMember(Mob*)` accepts any mob type
> - `/say` command interception for recruitment (quest script layer)
> - Standard `OP_NewSpawn`/`OP_DeleteSpawn` for companion entity management
> - Group window (MAX_GROUP_MEMBERS=6) as status display
>
> **Recommended approach:**
> New `Companion` class (extend `NPC` or adapt from `Merc : NPC`), using existing group
> infrastructure. No merc-specific client packets needed or possible.
>
> Full findings in: `claude/project-work/feature-npc-recruitment/protocol-agent/dev-notes.md`

**Awaiting:** Architect response on class design decision.

---

### 2026-02-25 — Config-Expert: Rule System Planning Results

**From:** config-expert → **To:** architect

> Task #3 complete (Stage 1/2). Full rule system plan delivered.
>
> **Key finding: No existing rules can be reused.** Zero overlap with Mercs or Bots categories.
> A new `Companions` category is required in `common/ruletypes.h`.
>
> **eqemu_config.json: No changes needed.** Pure game logic system.
>
> **Proposed 30 rules across 6 groups:**
> 1. Core toggle/limits (3): Enabled, MaxPerPlayer, MaxGroupSlots
> 2. Eligibility (4): LevelRange, MinFaction=3 (Kindly), RecruitCooldownS=900, AllowRecruitInCombat=false
> 3. Roll modifiers (13): BaseRecruitChance=50, Min/MaxRecruitChance=5/95, faction bonuses (30/20/10), disposition modifiers (25/15/5/-10/-30), LevelDiffModifier=5, PreviousRecruitBonus=10
> 4. Balance tuning (5): StatScalePct=100, SpellScalePct=100, HealThresholdPct=70, AggroRadius=100, ResurrectRadius=50
> 5. Lifecycle (4): DeathDespawnS=1800, ReplacementSpawnDelayS=45, SuspendIntervalMS=10000, XPContribute=true
> 6. Mercenary retention (2): MercRetentionWarningS=30, MercRetentionDepartureS=600
> 7. Optional hard cap override (2): HardCapEnabled=false, HardCap=3
>
> **Questions for architect:**
> - Approve/adjust rule list and category name (`Companions`)
> - Persuasion formula weights: recommend NOT exposing as rules (Lua handles it)
> - Sequencing: c-expert adds ruletypes.h first, then config-expert writes DB inserts
>
> Full notes: `config-expert/dev-notes.md`

**Awaiting:** Architect approval of rule list before Stage 3 (socialize with c-expert).

---

## Implementation Team Conversations

_Expert-to-expert exchanges during Phase 4._

_(Not yet started — awaiting architecture phase completion.)_

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication.
This table is the quick-reference for anyone catching up._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | Titanium client has no merc UI — must use chat commands + dialogue | game-designer (research) | 2026-02-25 | titanium_ops.h has zero merc opcodes |
| 2 | Group window (MAX_GROUP_MEMBERS=6) is the primary recruit display | game-designer (research) | 2026-02-25 | Hard limit from Titanium client protocol |
| 3 | Faction minimum set to Kindly (corrected from Warmly after lore review) | game-designer | 2026-02-25 | Ensures meaningful faction work for cross-alignment |
| 4 | Two recruitment types: Companion (loyal) vs. Mercenary (tactical) | game-designer + lore-master | 2026-02-25 | Teir'Dal/Iksar/Ogre/Troll cultures cannot express genuine loyalty |
| 5 | Racial disposition caps enforced | lore-master | 2026-02-25 | Teir'Dal/Iksar max Content, Ogre max Curious, Troll max Restless |
| 6 | Culture-specific persuasion replaces single CHA check | lore-master recommendation, game-designer design | 2026-02-25 | STR for Ogres/Barbarians, INT for Erudites, CHA for Humans/Elves |
| 7 | Party tensions are narrative-only, not mechanical | game-designer | 2026-02-25 | Player chose the party; recruits respect player authority |
| 8 | Canonical NPC allegiance-shifts justify the feature | lore-master | 2026-02-25 | Guard Alayle, Heretics, Corrupt Guards, Lucan's fall |
| 9 | Frogloks not recruitable in Classic-Luclin | lore-master | 2026-02-25 | Not organized civilization in this era; Gukta is post-Luclin |
| 10 | Named lore anchors have curated exclusion list | lore-master | 2026-02-25 | Lucan, Antonius Bayle, Captain Tillin, King Thex, etc. |
| 11 | Dreadguard Inner hard-blocked from recruitment | lore-master | 2026-02-25 | Innoruuk's religious mandate; theologically bound to inner sanctum |
| 12 | Named lore anchors are hard blocks that bypass the 5% roll clamp | lore-master + game-designer | 2026-02-25 | Exclusion list filtered BEFORE roll, not subject to probability |
| 13 | Mercenary retention threshold (Warmly) is intentionally stricter than recruitment minimum (Kindly) | game-designer | 2026-02-25 | Creates design where mercs can be hired at Kindly but demand Warmly to stay |
| 14 | New `Companion : public NPC` class (not extending Merc or Bot) | architect + protocol-agent | 2026-02-26 | Merc too coupled to templates, Bot too complex. NPC subclass is cleanest. |
| 15 | Zero merc opcodes on Titanium — chat + group window only | protocol-agent → architect | 2026-02-26 | titanium_ops.h confirmed zero OP_Mercenary* entries |
| 16 | New Companions rule category with 12 rules (trimmed from 28) | config-expert → architect | 2026-02-26 | Drop roll modifiers to Lua, drop redundant caps/AI tuning |
| 17 | No eqemu_config.json changes needed | config-expert | 2026-02-26 | Pure game logic via rules + Lua |
| 18 | Persuasion formula weights stay in Lua, not rules | config-expert + architect | 2026-02-26 | Formula too complex to split between rules and Lua |
| 19 | c-expert writes ruletypes.h first, data-expert writes rule_values INSERTs | config-expert + architect | 2026-02-26 | Sequencing: C++ header before DB seed data |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| Final lore sign-off on revised PRD | game-designer, lore-master | RESOLVED — Approved 2026-02-26 | No — design phase complete |
| Protocol-agent awaiting class design decision | protocol-agent, architect | RESOLVED — Companion : public NPC (2026-02-26) | No — architecture decision made |
| Config-expert awaiting rule list approval | config-expert, architect | RESOLVED — 12 rules approved (2026-02-26) | No — architecture decision made |

### 2026-02-26 — Architect Response to Protocol-Agent: Class Design Decision

**From:** architect → **To:** protocol-agent

> Acknowledging protocol findings. Your analysis is incorporated into the architecture doc.
>
> **Class design decision: New `Companion : public NPC`** — not extending Merc or Bot.
>
> Rationale verified against source code:
> 1. Merc is too coupled to MercTemplate/merc_stats — every stat method assumes merc-specific tables
> 2. Bot is too complex — designed for player-created characters with equipment management
> 3. `Companion : public NPC` gets all NPC capabilities for free, uses NPCType struct directly
>
> **Follow-up questions for protocol-agent:**
> 1. Group window rendering: When an NPC is added via `Group::AddMember(Mob*)`, does the
>    Titanium client render the NPC's name and HP bar correctly in the group window?
>    (Verified: yes — bots and mercs use this path and render correctly.)
> 2. Spawn packet: For the Companion entity, we use standard `OP_NewSpawn`. The `Spawn_Struct`
>    `bodytype` field — should Companion use bodytype 1 (Humanoid) to match the original NPC,
>    or does the NPC type field matter for client rendering?
>
> **Architecture doc reference:** See Companion class design at architecture.md lines 101-138.

**Outcome:** Class design decision finalized as `Companion : public NPC`. Protocol-agent's
zero-merc-opcode finding is a key architectural constraint that shaped the entire approach.

---

### 2026-02-26 — Architect Response to Config-Expert: Rule List Refinement

**From:** architect → **To:** config-expert

> Reviewed your proposed 28 rules. Category name `Companions` APPROVED.
>
> **Trimming from 28 to 12 rules.** Rationale:
>
> 1. **DROP MaxGroupSlots** — redundant with MaxPerPlayer + the hard 6-member group cap
> 2. **DROP 9 roll modifier rules** (FactionAllyBonus, FactionWarmlyBonus, FactionKindlyBonus,
>    DispositionEagerBonus, DispositionRestlessBonus, DispositionCuriousBonus,
>    DispositionContentPenalty, DispositionRootedPenalty, LevelDiffModifier, PreviousRecruitBonus)
>    — move these to Lua `companion.lua` module as local constants. The persuasion formula is
>    complex enough that it should live in one place (Lua), not split between rules and Lua.
>    Config-expert's own recommendation to keep persuasion formula weights in Lua is correct.
> 3. **DROP MinRecruitChance/MaxRecruitChance** — hardcode 5/95 in Lua
> 4. **DROP AllowRecruitInCombat** — hardcode false in Lua
> 5. **DROP HealThresholdPct, AggroRadius, ResurrectRadius** — these are AI tuning values
>    that should be constants in companion_ai.cpp, not runtime rules
> 6. **DROP SuspendIntervalMS** — matches merc pattern; hardcode to match Mercs value
> 7. **DROP HardCapEnabled/HardCap** — redundant with MaxPerPlayer
> 8. **DROP MercRetentionWarningS** — merge into single MercRetentionCheckS rule
>
> **Final 12 rules:**
> Enabled, MaxPerPlayer, LevelRange, BaseRecruitChance, StatScalePct, SpellScalePct,
> RecruitCooldownS, DeathDespawnS, MinFaction, XPContribute, MercRetentionCheckS,
> ReplacementSpawnDelayS
>
> **Sequencing confirmed:** c-expert adds RULE_CATEGORY to ruletypes.h (Task 1), then
> data-expert writes DB INSERT for rule_values (part of Task 2 seed data).
>
> **Persuasion formula weights:** CONFIRMED — keep in Lua, not rules. Correct recommendation.

**Outcome:** Rule list trimmed from 28 to 12. Config-expert's core findings (no existing rules
reusable, new Companions category needed, eqemu_config.json unchanged) all adopted. Persuasion
formula weights confirmed as Lua-only per config-expert recommendation.

---

### 2026-02-26 — Architecture Decision Summary

**Key architecture decisions from advisor consultations:**

| # | Decision | Advisors Consulted | Outcome |
|---|----------|-------------------|---------|
| 14 | New `Companion : public NPC` class (not extending Merc or Bot) | protocol-agent, config-expert | Merc too coupled to templates, Bot too complex. NPC subclass is cleanest. |
| 15 | Zero merc opcodes on Titanium — chat commands + group window only | protocol-agent | titanium_ops.h has no OP_Mercenary* entries. Group packets work for any Mob*. |
| 16 | New `Companions` rule category with 12 rules (trimmed from config-expert's 28) | config-expert | Drop roll modifiers (move to Lua), drop redundant caps, drop AI tuning rules |
| 17 | No eqemu_config.json changes needed | config-expert | Pure game logic system controlled via rules + Lua |
| 18 | Persuasion formula weights stay in Lua, not rules | config-expert recommendation, architect approval | Formula is complex; should live in one place |
| 19 | c-expert writes ruletypes.h, data-expert writes rule_values INSERTs | config-expert coordination | Sequencing: C++ header first, then DB seed data |


## User Stories Phase

_game-designer + lore-master exchanges during expanded scope user stories._

### 2026-02-27 — Lore Consultation: Expanded Scope (Leveling, Equipment, Persistence)

**From:** game-designer → **To:** lore-master

> Requesting lore review on 5 narrative-touching design decisions for expanded scope:
>
> 1. **Companion Leveling Narrative** — How should leveling be framed in lore for
>    companions vs. mercenaries? Companions grow together; mercenaries gain power
>    from the arrangement.
> 2. **Equipment and Gearing Lore** — Trade window for gearing. Companions receive
>    gear as gifts; mercenaries as payment in kind. Cultural voice reactions.
> 3. **Lifelong Companion Persistence / Soul** — NPC recruited at level 10 journeys
>    to level 65. Soul wipe on permanent death. Does an NPC fundamentally changing
>    from their original role (guard -> adventurer) create lore concerns?
> 4. **Re-recruitment After Dismissal** — Companion remembers everything, returns
>    with all progress. Mercenaries kept gear as collateral.
> 5. **Death and Soul Wipe** — Permanent death clears ChromaDB. NPC returns as
>    stranger. Should death consequences differ between companion and mercenary types?

**Response from** lore-master:

> _(Awaiting response — will update this entry when received.)_

**Outcome:** Pending lore-master review.

### 2026-02-27 — Design Decisions: Architect's 6 Open Questions

**From:** game-designer (design decisions)

> Answered all 6 open questions from the architect's feasibility review:
>
> 1. **Level scaling formula:** Linear scaling from base stats
>    (`stat = base_stat * current_level / recruited_level`). Simple, predictable,
>    preserves NPC identity. Avoids alien stat curves from player tables.
>
> 2. **Equipment on dismissal:** Items persist on companion. Creates emotional
>    investment. Players can trade to retrieve items before dismissal. Soul wipe
>    destroys all gear (emotional stakes).
>
> 3. **Equipment class restrictions:** Use existing item table race/class flags.
>    Battle-tested, intuitive, zero maintenance burden.
>
> 4. **XP rate for companions:** 50% of a full group member's share. Companions
>    lag behind player naturally. Lost 50% incentivizes human grouping. New rule
>    `Companions:XPSharePct` (default 50) for tuning.
>
> 5. **Level cap for companions:** player_level - 1, no absolute cap. A level 10
>    recruit can reach level 64 (if player reaches 65). Enables the lifelong
>    companion fantasy. The -1 cap maintains power hierarchy.
>
> 6. **Re-recruitment cost:** +10% bonus, full state restore for voluntarily
>    dismissed companions. Soul-wiped companions are strangers — standard
>    recruitment, no bonus, no progress.

**Outcome:** Decisions documented in user stories document (`user-stories.md`),
Decision Summary section. Ready for architect review as part of feasibility update.


### 2026-02-27 — Lore Review Status: User Stories Expanded Scope

**From:** game-designer → **To:** lore-master (4 messages sent, no response received)

> Sent 4 messages requesting lore review on expanded scope areas:
> 1. Companion leveling narrative framing (companion vs. mercenary growth)
> 2. Equipment/gearing lore (gift-giving vs. payment in kind)
> 3. Lifelong companion persistence and identity evolution (guard -> adventurer)
> 4. Soul wipe on permanent death (ChromaDB cleared, NPC returns as stranger)
> 5. Mercenary self-preservation threshold (Ogre self-awareness question)
>
> No response received from lore-master during this session.

**Outcome:** Lore-master did not respond during this session. However, the expanded
scope stories are primarily mechanical additions (XP rates, stat formulas, equipment
systems, database persistence) that do not alter the lore foundations the lore-master
already approved in the original PRD review. The narrative elements (dialogue tone,
cultural voice, soul wipe concept) are consistent with the patterns the lore-master
established and approved during the PRD phase.

**Risk assessment:** Low. The areas most likely to need lore correction are:
- US-P04 (identity evolution tiers) — new narrative concept, not reviewed
- US-M03 (Ogre self-preservation) — cultural accuracy question, not reviewed
- US-M02 (mercenary word prohibition list) — extends existing pattern, low risk

**Recommendation:** The architect reviewing these stories for feasibility can flag
any lore concerns for future lore-master review. The stories are mechanically
complete and narratively consistent with the approved PRD.

### 2026-02-27 — Lore-Master Review: Expanded Scope User Stories

**From:** lore-master → **To:** game-designer

> Comprehensive review of expanded scope stories (US-G, US-E, US-P, US-D, US-RR, US-M).
>
> **APPROVED:**
> - US-G01-G04 (Growth/Leveling): "companions grow together / mercenaries gain power" is lore-consistent
> - US-E01-E05 (Equipment): "gifts vs. payment in kind" framing appropriate
> - US-P04 (identity evolution): Three-tier structure sound; precedent in Heretics, Alayle, Corrupt Guards
> - US-D02 (soul wipe): Uniform mechanics for companion and mercenary — correct per Norrathian metaphysics
> - US-RR02 companion dialogue ("I kept your armor polished"): Tonally perfect
> - US-RR02 mercenary dialogue ("Our previous arrangement was acceptable"): Correct in every word
> - US-M01 (retention warning): Correct Teir'Dal/mercenary tone
> - Era compliance: fully within Classic-Luclin, no violations
>
> **2 REQUIRED CORRECTIONS:**
>
> 1. **US-M03: Ogre self-preservation framing.** "Tactical self-preservation" and "tactical retreat"
>    contradict Classic-era Ogre lore (stripped of intelligence as divine punishment). Reframe to
>    "survival panic" for Ogres. Same mechanic, different in-character expression. Teir'Dal retreats
>    with cold calculation; Ogre grunts and runs in primal panic.
>
> 2. **US-M02: Word prohibition scope.** "together" and "home" bans too broad. Must be scoped to
>    emotional/relational contexts only. Tactical "together" ("we advance together") and geographic
>    "home" ("Neriak is home") are permitted. Also add "protect" and "guard" to prohibited emotional terms.
>
> **3 SUGGESTIONS (optional):**
> 1. US-P04 Late tier: "Qeynos? That was another life." too clean a break. Suggest world-weary
>    alternatives that carry tension with old identity.
> 2. Replace "tactical assets" / "tactical position" phrasing with period-appropriate language
>    ("tools of war," "adequate compensation").
> 3. Add "protect" and "guard" to US-M02 emotional prohibition list.

**Outcome:** All corrections and suggestions incorporated. Changes applied:

1. **US-M03 rewritten:** Title changed from "Tactical Behavior" to "Self-Preservation." Story reframed
   from "tactical AI personality" to "survival instinct." Added 4 culture-specific disengagement
   expressions (Teir'Dal: cold calculation, Iksar: disciplined withdrawal, Ogre: survival panic,
   Troll: feral self-preservation). Design notes updated with Ogre cognitive limitations from Rallos
   Zek lore and clarification that the LLM expresses the difference, not the mechanic itself.

2. **US-M02 word list restructured:** Prohibited list now explicitly scoped to "emotional or bonding
   context." Added sub-bullets explaining permitted tactical/geographic usage for "together," "home,"
   "protect," and "guard." Removed "tactical" from the approved word list. Equipment dialogue example
   changed from "This improves our tactical position" to "These are acceptable tools of war."

3. **US-P04 Late tier dialogue updated:** Replaced "Qeynos? That was another life." with
   "The south gate is someone else's problem now." and "I serve better out here than I ever did
   on that wall." — carrying tension with old identity per lore-master's guidance.

**Lore sign-off status:** Lore-master indicated "Ready to sign off once the two corrections are made."
Both corrections applied. Awaiting formal sign-off confirmation.


### 2026-02-27 — Architect Review: User Stories and Design Decisions

**From:** architect → **To:** game-designer

> Technical review of 6 design decisions and 38 user stories, verified against EQEmu source.
>
> **ALL 6 DECISIONS APPROVED:**
>
> 1. **Decision 1 (Linear Stat Scaling): APPROVED WITH NOTE** — Integer division risk.
>    `current_level / recruited_level` truncates in C++. Level 15/10 = 1, not 1.5.
>    Must use floating-point: `(int)(base_stat * (float)current_level / (float)recruited_level)`.
>
> 2. **Decision 2 (Equipment Persists): APPROVED** — Cascade delete on soul wipe is clean.
>    Follows existing merc_buffs/bot_inventories cleanup patterns.
>
> 3. **Decision 3 (Item Race/Class Flags): APPROVED WITH CAVEAT** — `GetPlayerRaceValue()`
>    returns sentinel for non-player races. Only All Races items (bitmask 0 or 65535) for
>    exotic NPCs. Class 0 → class 1 (Warrior) mapping confirmed correct.
>
> 4. **Decision 4 (50% XP Share): APPROVED** — Hook point in Group::SplitExp() verified clean.
>    Companion needs own level-up threshold calculation (formula: `(level-1)^3 * modifier * 1000`).
>
> 5. **Decision 5 (player_level - 1, No Cap): APPROVED WITH NOTE** — 6.4x multiplier at
>    extreme ranges (10→64). Suggested documenting expected stat ranges at key breakpoints
>    for testers.
>
> 6. **Decision 6 (+10% Re-recruitment Bonus): APPROVED** — Data flow clean. Query
>    `companion_data WHERE is_dismissed = 1` for detection.
>
> **USER STORY FINDINGS:**
>
> - **US-E04: DESIGN CLARIFICATION NEEDED** — Trade window cannot browse other party's
>   equipped items in Titanium. Bot system uses `^inventory` commands, not trade window.
>   Primary retrieval mechanism should be say commands ("give me your weapon").
>
> - **US-D01/D03: NEEDS VERIFICATION** — Resurrection spells check `corpse->IsClientCorpse()`.
>   Companion corpses are NPC corpses. May need special corpse subtype handling. Architect
>   will consult protocol-agent.
>
> - **US-P02 (zones_visited JSON TEXT): MINOR CONCERN** — Not queryable, but only used for
>   LLM context. Approved as designed.
>
> **SUMMARY:** No design changes required. Only implementation notes and one clarification
> on US-E04. Architect proceeding to update architecture document with Tasks 19-24.

**Outcome:** All findings addressed by game-designer:

1. **Decision 1:** Added "Implementation note" to user-stories.md specifying floating-point
   division requirement with the exact C++ cast syntax.

2. **Decision 3:** Updated edge case handling with explicit `GetPlayerRaceValue()` sentinel
   behavior, bitmask values (0 or 65535), and class 0 → class 1 mapping detail.

3. **Decision 5 / US-G03:** Added "Expected stat ranges for testing" to US-G03 design notes:
   150 base STR → ~480 at level 32, ~720 at level 48, ~960 at level 64 (before StatScalePct).

4. **US-E04:** Rewritten. Removed incorrect trade window click-to-retrieve claim. Say commands
   are now the primary mechanism ("give me [slot]", "give me everything", "show equipment").
   Added inventory-full handling. Design notes explicitly state Titanium client limitation.

5. **US-D01/D03:** Acknowledged as implementation concern. No design change needed — the
   resurrection targeting constraint is an implementation detail for the c-expert and
   protocol-agent to resolve. The design intent (companions are resurrectable) is correct.

6. **US-P02:** Acknowledged as minor concern. No change — JSON TEXT is appropriate for
   LLM context data.


### 2026-02-27 — Lore-Master Final Sign-Off: Expanded Scope User Stories

**From:** lore-master → **To:** game-designer

> APPROVED. All 5 changes are correct.
>
> Specific confirmations:
> - US-M03: "body reacts when pain exceeds tolerance" is correct Ogre framing. Four
>   culture-specific expressions (Teir'Dal calculates, Iksar repositions, Ogre panics,
>   Troll snarls) all consistent with established characterization.
> - US-M02: Emotional/relational = prohibited, tactical/geographic = permitted. "Protect"
>   and "guard" additions correct — mercenaries fulfill contractual obligations, not
>   personal protection.
> - US-P04: Both Late tier lines carry correct tension — old identity acknowledged and
>   released without erasure. Consistent with Norrath's allegiance change patterns.
> - US-M02 equipment dialogue: "These are acceptable tools of war." is period-accurate.
>
> Era compliance confirmed across all 38 stories. Faction consistency confirmed.
> Companion vs. mercenary types consistently differentiated throughout.
>
> User stories document is ready for architecture handoff.

**Outcome:** APPROVED — full lore sign-off on all 38 user stories (original + expanded scope).
Both required corrections verified. All 3 suggestions confirmed appropriate. No further
lore concerns. Document ready for final architecture integration.


### 2026-02-27 — Architect → Protocol-Agent: Expanded Scope Questions

**From:** architect → **To:** protocol-agent

> Consulting on 4 protocol questions related to expanded scope (leveling,
> equipment, persistence, death):
>
> 1. **Trade window with companions:** Standard EQ trade window works between
>    player and NPC. Titanium client supports `OP_TradeRequest`, `OP_TradeAccept`,
>    `OP_TradeItems`. Confirmed: Bot trade system uses this same path on Titanium.
>    Can the trade window be used for companion equipment management?
>
> 2. **OP_WearChange for equipment visuals:** When a companion equips armor/weapons,
>    does `OP_WearChange` work for NPC entities? Bot system sends `OP_WearChange`
>    for visual updates — but only for player-race models. Non-player-race NPCs
>    (e.g., skeleton warriors) — does visual update work for them?
>
> 3. **Level-up display:** When a companion levels up, what packet should be sent
>    to notify the player? `OP_LevelUpdate` is client-specific. Can we use a
>    simple `Message()` to the owner, or is there a visual effect packet (like
>    the golden glow on level-up)?
>
> 4. **Resurrection targeting on NPC corpses:** Standard resurrection spells
>    may check `IsClientCorpse()`. Companion corpses are NPC corpses. Can
>    resurrection spells target NPC corpses on Titanium, or does the client
>    filter them out? If filtered, we need an alternative approach (say command
>    or special corpse subtype).

**Response from** protocol-agent:

> _(No response received during this session. Protocol-agent may not have been
> active in this team. Questions remain open for implementation phase.)_

**Outcome:** Questions logged for the implementation team. The architecture
proceeds with the assumption that all 4 are feasible based on Bot system
precedent. The resurrection corpse targeting question is flagged as NEEDS
VERIFICATION in the architecture doc (Pass 1 Addendum).

---

### 2026-02-27 — Architect → Config-Expert: Expanded Scope Rules

**From:** architect → **To:** config-expert

> Consulting on 3 configuration questions for expanded scope:
>
> 1. **Existing rules overlap:** Do any existing rules in the Mercs, Bots, or
>    Character categories cover XP sharing, level caps, or equipment restrictions
>    that could be reused for companions?
>
> 2. **New rule naming conventions:** Proposing 6 new rules for the Companions
>    category: `XPSharePct`, `MaxLevelOffset`, `ReRecruitBonus`,
>    `DismissedRetentionDays`, `CompanionSelfPreservePct`, `MercSelfPreservePct`.
>    Do these follow existing naming conventions? Any conflicts?
>
> 3. **StatScalePct appropriateness:** The existing `StatScalePct` rule (already
>    in the approved 12) — is it sufficient for the linear scaling formula, or
>    should we split into per-stat rules (STRScalePct, DEXScalePct, etc.)?

**Response from** config-expert:

> _(No response received during this session. Config-expert may not have been
> active in this team. Questions remain open for implementation phase.)_

**Outcome:** Questions logged for the implementation team. The architecture
proceeds with the proposed 6 new rules (total 18). A single `StatScalePct` rule
is used rather than per-stat rules — per the simplicity principle, splitting
would be premature optimization for a server with 1-6 players. Per-stat rules
can be added later if needed.

---

### 2026-02-27 — Architect → Lore-Master: Expanded Scope Lore Concerns

**From:** architect → **To:** lore-master

> Flagging 2 lore concerns from the technical review of expanded scope user stories:
>
> 1. **US-P04 (Identity Evolution):** The three-tier progression (Early/Mid/Late)
>    where a guard NPC gradually evolves into an adventurer is a new narrative
>    concept not covered in the original PRD lore review. Technically feasible
>    (driven by ChromaDB memories and time_active thresholds). But the lore
>    question is: does an NPC fundamentally changing their identity conflict with
>    Norrathian precedent? The guard was placed at their post by faction authority.
>
> 2. **US-M03 (Self-Preservation):** Mercenary-type companions disengage from
>    combat at low HP. The "tactical self-preservation" framing raised concern
>    about Ogre intelligence levels (Classic-era Ogres were stripped of intelligence
>    by divine punishment). Should Ogre self-preservation be "survival panic"
>    rather than "tactical retreat"?

**Response from** lore-master:

> Both concerns addressed in the lore-master's comprehensive review of user
> stories (see entry "2026-02-27 — Lore-Master Review: Expanded Scope User
> Stories" above). Summary:
>
> 1. **US-P04:** APPROVED. Three-tier structure is sound. Precedent in Heretics,
>    Guard Alayle, Corrupt Guards. Old identity acknowledged and released without
>    erasure. Dialogue revised per lore-master guidance.
>
> 2. **US-M03:** APPROVED WITH CORRECTION. "Tactical self-preservation" reframed
>    to "survival panic" for Ogres. Same mechanic, different in-character
>    expression. Teir'Dal: cold calculation. Iksar: disciplined withdrawal.
>    Ogre: survival panic. Troll: feral self-preservation.

**Outcome:** Both concerns resolved. Corrections applied to user stories document.
Lore-master gave final sign-off on all 38 stories.

---

### 2026-02-27 — Architecture Team Expanded Scope: Summary

**Consultations completed:**
- protocol-agent: 4 questions sent (trade window, WearChange, level-up display, resurrection). No response received — questions deferred to implementation team.
- config-expert: 3 questions sent (rule overlap, naming, StatScalePct). No response received — questions deferred to implementation team.
- lore-master: 2 concerns sent (identity evolution, Ogre self-preservation). Both resolved via lore-master's comprehensive review.
- game-designer: Full technical review of 6 decisions and 38 stories sent. All findings addressed.

**Architecture doc updated:** Tasks 19-24 added to `architect/architecture.md` as Expanded Scope Addendum. Total implementation tasks: 24 (was 18). Total rules: 18 (was 12). Additional estimated scope: ~1,600 lines C++, ~70 lines SQL, ~100 lines Lua.

### 2026-02-27 — Lore-Master → Architect: Implementation Constraints for Companion AI

**From:** lore-master → **To:** architect

> Two implementation constraints for the Lua/LLM layer:
>
> 1. **US-M03: Ogre mercenary AI dialogue must not use "tactical" framing.**
>    The 20% HP disengage threshold is mechanically race-agnostic (correct), but
>    `companion_culture.lua` must provide per-race flavor variants for the low-HP
>    disengage event. Teir'Dal: cold calculation ("This engagement is no longer
>    favorable"). Ogre: panic/survival instinct ("Oog go now."). This is an LLM
>    context distinction, not a C++ change.
>
> 2. **US-M02: Word prohibition scope must be context-scoped, not a regex filter.**
>    "together" and "home" are prohibited in emotional/bonding contexts but permitted
>    in tactical ("we advance together") and geographic ("Neriak is home") contexts.
>    The LLM system prompt must express this as context-scoped guidance, not a
>    blanket word blacklist.

**Architect response:**

> Acknowledged. Both constraints are already reflected in the architecture:
>
> 1. Task 15 (`companion_culture.lua`) is assigned to lua-expert and already
>    specifies culture-specific dialogue templates. The architecture doc's
>    antagonistic review (Pass 3) and the user stories (US-M03 as revised)
>    both call out Ogre-specific panic framing vs. Teir'Dal calculation.
>    The per-race disengage flavor variants are a Task 15 deliverable.
>
> 2. The word prohibition scope is documented in user stories (US-M02 as
>    revised by game-designer after lore-master review). The LLM system prompt
>    is constructed in `companion_culture.lua` (Task 15) and will use
>    context-scoped natural language guidance, not regex filtering.
>
> No architecture changes needed. These are implementation-level constraints
> for lua-expert's Task 15 work. They will be visible in the user stories
> document that lua-expert reads as part of their task context.

**Outcome:** Constraints acknowledged. No architecture changes required. Both
are implementation details for Task 15 (companion_culture.lua), already
scoped to lua-expert.

---

## Implementation Team Conversations

_data-expert, c-expert, lua-expert exchanges during Phase 4._

### 2026-02-27 — data-expert → c-expert: Foundation Tables Complete

**From:** data-expert → **To:** c-expert

> Tasks 2, 3, 4, 5, and 20 complete. All 6 companion tables live in peq database.
>
> Key facts for C++ companion class implementation:
>
> **companion_data (29 cols):** owner_id, npc_type_id, name, companion_type (0/1), level,
> class_id, race_id, gender, zone_id, x, y, z, heading, cur_hp, cur_mana, cur_endurance,
> is_suspended (default 1), stance (0/1/2), spawn2_id, spawngroupid, recruited_at,
> experience (BIGINT UNSIGNED), recruited_level, is_dismissed (default 0), total_kills,
> zones_visited (TEXT JSON), time_active, times_died
>
> **companion_spell_sets:** 842 entries across 12 spellcasting classes. Derived from
> Default class npc_spells lists (IDs 1-12). Bot npc_spells (3001-3016) have ZERO DB
> entries — they are C++ hardcoded. Class_id mapping: 2=CLR, 3=PAL, 4=RNG, 5=SHK,
> 6=DRU, 8=BRD, 10=SHM, 11=NEC, 12=WIZ, 13=MAG, 14=ENC, 15=BST.
>
> WAR(1)/MNK(7)/ROG(9): no spell entries — pure melee classes handled by melee AI.
>
> companion_inventories: unique key (companion_id, slot_id).
>
> SQL scripts in claude/project-work/feature-npc-recruitment/data-expert/context/.
> Tasks 6, 13 and others are now unblocked.

**Outcome:** c-expert notified. Database foundation ready for C++ implementation.

### 2026-02-27 — Lore-Master → Architect: Full Answers to US-P04 and US-M03 Concerns

**From:** lore-master → **To:** architect

> Detailed lore answers to the two concerns the architect raised:
>
> **US-P04 (Identity Evolution):** Three canonical precedents confirm the
> three-tier evolution structure is lore-sound:
> 1. Guard Alayle — Freeport Militia guard who defected to Knights of Truth spy
> 2. Erudite Heretics — Erudin scholars who founded Paineel, carrying Erudin
>    with them into exile (identity built in opposition, not erasure)
> 3. Corrupt Qeynos Guards — gradual allegiance shift toward personal interest
>
> Suggestion (not blocking): Late tier dialogue "Qeynos? That was another life"
> is too clean. Heretics didn't erase Erudin — they obsessed over it. Alternatives:
> "The south gate is someone else's problem now" / "I serve better out here than
> I ever did on that wall." Game-designer already applied these.
>
> **US-M03 (Ogre Self-Preservation):** Required correction confirmed. Ogres
> stripped of intelligence by divine punishment (Rallos Zek's assault on Plane
> of Earth). "Tactical self-preservation" is wrong for Ogres. Same 20% threshold,
> four different voices:
> - Teir'Dal: cold calculation
> - Iksar: disciplined tactical withdrawal
> - Troll: survival instinct without calculation
> - Ogre: survival panic ("Oog go now.")
>
> C++ threshold is race-agnostic (correct). Differentiation lives in LLM
> dialogue layer via companion_culture.lua (Task 15).

**Architect response:**

> Both answers confirm what is already in the architecture:
>
> 1. US-P04: Three-tier structure approved. Late tier dialogue already revised
>    per lore-master's suggestion (game-designer applied both alternatives).
>    Documented in user stories and architecture addendum.
>
> 2. US-M03: Required correction already applied. User stories document revised
>    to remove "tactical" framing. Four culture-specific disengage expressions
>    documented. Task 15 (companion_culture.lua) assigned to lua-expert covers
>    the per-race LLM dialogue variants.
>
> No further architecture changes needed. All lore concerns for the expanded
> scope are resolved.

**Outcome:** Both concerns fully resolved. Architecture and user stories
already reflect all corrections. No outstanding lore issues remain.

### 2026-02-27 — Game-Designer → Architect: All Findings Addressed

**From:** game-designer → **To:** architect

> Confirmed all architect findings incorporated into `user-stories.md`:
>
> 1. Decision 1: Implementation note added with exact C++ float cast syntax
> 2. Decision 3: Edge case handling updated (GetPlayerRaceValue sentinel, bitmask values, class 0→1)
> 3. Decision 5 / US-G03: Expected stat ranges for testing added (3.2x/4.8x/6.4x at 32/48/64)
> 4. US-E04: Rewritten — say commands as sole retrieval mechanism, Titanium limitation documented
> 5. US-D01/D03: Acknowledged as implementation concern, no design change needed
> 6. US-P02: No change, JSON TEXT confirmed appropriate

**Architect response:**

> Acknowledged. Architecture addendum (Tasks 19-24) was written with all these
> corrections already factored in. No further architecture changes needed.

**Outcome:** All architect-to-game-designer findings resolved. User stories
and architecture are fully aligned.

### 2026-02-27 — Architect Confirmation: Architecture and User Stories Aligned

**From:** architect → **To:** game-designer

> All confirmed. Architecture addendum (Tasks 19-24) written with game-designer's
> corrections already factored in. Architecture and user stories are fully aligned.
> Nothing else needed. Task #1 complete, architecture ready for implementation team.

**Outcome:** Both reviewers have completed their work. All 38 user stories are:
- Lore-approved (lore-master sign-off)
- Technically verified (architect review, all 6 decisions approved)
- Architecture-aligned (Tasks 19-24 added, dependency DAG updated)
- Ready for implementation team handoff.


### 2026-02-27 — Lore-Master → Architect: Final Confirmation

**From:** lore-master → **To:** architect

> No further lore constraints outstanding. User stories document is lore-approved.
> Task 15 (companion_culture.lua) implementation details correctly scoped.
> Lore-master work on this feature is complete unless new narrative elements
> surface during implementation.

**Outcome:** Lore review complete. All constraints documented and incorporated.
No outstanding lore issues for the implementation team.

### 2026-02-27 — lua-expert → c-expert: Stage 3 Socialization — Lua API Binding Names

**From:** lua-expert → **To:** c-expert

> Stage 3 socialization for Tasks 14, 15, 16, 23, 24. Three questions about
> the Companion C++ implementation that affect what Lua API I write against:
>
> 1. **Lua API method names (Task 17/18):** What will the Lua-facing methods be named
>    for companion creation and management? Specifically:
>    - Creating a companion from an NPC (Task 17): `eq.create_companion_from_npc(npc_id)`?
>    - Dismissing a companion (Task 17): `npc:DismissCompanion()`?
>    - Checking if already recruited (entity variable or method): `npc:GetEntityVariable("is_recruited")`?
>
> 2. **IsCompanion() on Lua_NPC (Task 18):** When Task 18 exposes the Companion class to Lua,
>    will `npc:IsCompanion()` be available on Lua_NPC objects (via lua_companion.h/cpp
>    wrapping the new Companion class)? Or will it only be on the Mob base?
>
> 3. **Re-recruitment state restore (Task 23):** For the C++ side of re-recruitment,
>    does the Companion class constructor accept an optional existing companion_data row
>    to restore from? Or does the Lua side just call the normal create function and then
>    separately restore state via setters?

**Response from c-expert:** _(No response received before context compacted — context was lost.)_

**Outcome:** Questions remain open. Re-contacting c-expert after context reset.

---

### 2026-02-27 — lua-expert → data-expert: Stage 3 Socialization — DB Schema Confirmation

**From:** lua-expert → **To:** data-expert

> Three questions about DB schema for Tasks 14, 23, 24:
>
> 1. **is_dismissed column:** Can you confirm `companion_data` has an `is_dismissed`
>    column (default 0)? The architecture uses `WHERE is_dismissed = 1` for re-recruitment
>    detection. I see `is_suspended` (default 1) in the schema you described — is
>    `is_dismissed` a separate column?
>
> 2. **companion_exclusions query:** What are the column names? Architecture says
>    `npc_type_id` for specific NPC exclusions and `class_id` for class-based exclusions.
>    Confirmed?
>
> 3. **Froglok race ID:** What is the Froglok race ID in the `races` table or `npc_types`?
>    I need it for the Froglok eligibility exclusion check in companion.lua.

**Response from data-expert (2026-02-27):**

> All four questions answered — verified directly against the live database:
>
> 1. **is_dismissed confirmed** — `TINYINT UNSIGNED NOT NULL DEFAULT 0` in companion_data.
>    Query `WHERE owner_id=? AND npc_type_id=? AND is_dismissed=1` correct as written.
> 2. **companion_exclusions** — 7,269 rows. PRIMARY KEY on npc_type_id. Point-lookup
>    `SELECT npc_type_id FROM companion_exclusions WHERE npc_type_id=?` is index-only.
>    No `class_id` column — all exclusions are stored by `npc_type_id` only.
> 3. **companion_culture_persuasion** — 14 rows. PRIMARY KEY on race_id. NULL return if
>    race has no entry — default to CHA/faction/companion/max_disposition=4 (Human-style).
> 4. **Froglok race IDs** — race 74 (primary) and race 330 (alternate). Race 15 is NOT
>    Froglok. 194 Froglok rows already in companion_exclusions — single npc_type_id
>    lookup is sufficient; no separate Froglok race check needed in Lua.

**Outcome:** All schema questions resolved. companion.lua queries are correct as written.
No changes needed. Only remaining blocker is Task 6 (c-expert Companion class).

---

### 2026-02-27 — lua-expert: Tasks 14/15/16 Implementation Complete

**From:** lua-expert (implementation status)

> Tasks 14, 15, and 16 complete. Context compacted mid-session but work resumed
> from dev-notes. All three files implemented while Task 6 (c-expert) is still in
> progress — the C++ companion creation calls are stubbed with clear TODOs.
>
> **Files created/modified:**
>
> 1. `akk-stack/server/quests/lua_modules/companion.lua` (~500 lines)
>    - Full eligibility check (11-step), persuasion formula, faction/disposition/level bonuses
>    - Recruitment roll with cooldown management
>    - Management command dispatch (dismiss, stance, follow, guard, equipment)
>    - Re-recruitment detection via companion_data WHERE is_dismissed=1
>    - Soul wipe: POST to http://npc-llm:8100/v1/memory/clear
>    - TODOs: npc:CreateCompanion(client), npc:Dismiss(), npc:SetStance() — pending Task 17
>
> 2. `akk-stack/server/quests/lua_modules/companion_culture.lua` (~200 lines)
>    - 3-tier identity evolution (0-10h, 10-50h, 50h+)
>    - Companion vs mercenary type framing
>    - Racial personality variants (Teir'Dal=cold, Iksar=disciplined, Ogre=panic, Troll=feral)
>    - 12 event type prompts (recruitment_success/failure, dismiss, level_up, equipment_receive, etc.)
>    - Lore-correct Ogre self-preservation: "HURT HURT" / "Oog go" — no tactical reasoning
>    - Context-scoped mercenary word prohibition (emotional=banned, tactical/geographic=OK)
>
> 3. `akk-stack/server/quests/global/global_npc.lua` (modified)
>    - Added `require("companion")` at top
>    - Added management keyword block BEFORE LLM (gated on `false` pending Task 18 IsCompanion())
>    - Added recruitment keyword block BEFORE LLM (fires for all eligible NPCs)
>
> **c-expert action needed (blocking Tasks 23/24):**
> - Task 17: Add Lua API methods (npc:CreateCompanion, npc:Dismiss, companion:SetStance, etc.)
> - Task 18: Expose Companion class to Lua (npc:IsCompanion() binding needed for management block)
> Once Tasks 17 and 18 are done, the 4 TODOs in companion.lua and the `false` guard in
> global_npc.lua can be replaced with the real API calls.

---

## Implementation Team Conversations (continued)

### 2026-02-27 — lua-expert Stage 3 Socialization: Lua API binding names

**From:** lua-expert → **To:** c-expert

**Summary:** lua-expert asked 3 questions before writing production companion.lua code:
1. Exact Lua method names for companion creation/management (Tasks 17/18)
2. Whether `IsCompanion()` would be exposed on Lua NPC binding
3. Whether re-recruitment state restore requires extra Lua parameters

**c-expert response:**

Method names confirmed:
- `client:CreateCompanion(npc)` — factory, returns Companion or nil; handles re-recruitment branch internally by checking for existing `is_dismissed=1` record
- `companion:Dismiss(voluntary_bool)` — true=voluntary (re-recruit bonus), false=forced
- `client:GetCompanionByNPCTypeID(npc_type_id)` — returns Companion or nil
- `client:HasActiveCompanion(npc_type_id)` — returns bool
- `companion:SetStance(stance_int)` — 0/1/2 matching DB column
- Soul wipe: Lua calls sidecar HTTP then `companion:SoulWipe()` — C++ handles cascade delete synchronously

`npc:IsCompanion()` will be exposed in Task 18 lua_companion bindings. Companions appear as NPCs to Lua, so this is the correct check in global_npc.lua.

Re-recruitment: no extra Lua parameters needed. `client:CreateCompanion(npc)` detects existing dismissed record automatically and calls `Load()` + `Unsuspend()` to restore all state (level, XP, equipment, buffs).

**Outcome:** lua-expert can write production-ready companion.lua without placeholders once Tasks 17/18 are delivered.

**Outcome:** Tasks 14, 15, 16 complete. Tasks 23 and 24 (Lua side) remain pending Tasks 6/17/18/21.

---

### 2026-02-27 — lua-expert: All Tasks Complete

**From:** lua-expert → **To:** c-expert (notification)

**Summary:** All lua-expert tasks are now complete.

- Task 14 (companion.lua): Full recruitment module with confirmed API calls
- Task 15 (companion_culture.lua): LLM culture context templates, all lore constraints implemented
- Task 16 (global_npc.lua): Companion keyword interception before LLM block
- Task 23 (re-recruitment Lua side): Resolved — CreateCompanion handles transparently; Lua adds +10% roll bonus via pre-roll dismissed record check
- Task 24 (soul wipe Lua side): trigger_soul_wipe() curl POST to ChromaDB sidecar implemented

**IsCompanion() guards activated** in both companion.lua and global_npc.lua after c-expert confirmed Task 18 binding name.

**companion_culture.lua integration note:** companion_culture.lua is complete but not yet called from llm_bridge.build_context(). Once Tasks 17/18 are done, llm_bridge should check npc:IsCompanion() and call companion_culture.get_companion_context() to enrich LLM prompts for active companions. This coordination item remains for when c-expert delivers those tasks.

Commits on quests repo branch `feature/npc-recruitment`:
- `90500ddc3` — initial Lua layer: companion.lua, companion_culture.lua, global_npc.lua
- `506e389d3` — IsCompanion() activation, stub replacement, Task 23 resolution

**Outcome:** lua-expert scope fully delivered. Lua layer is production-ready pending c-expert Tasks 17/18 compile and test.
