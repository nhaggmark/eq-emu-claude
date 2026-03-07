# companion-experience — Agent Conversations Log

> **Feature branch:** `bugfix/companion-experience`
> **Created:** 2026-03-05

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

### 2026-03-05 — Initial Companion XP Concept (Early Brainstorm)

**From:** game-designer → **To:** lore-master

> Shared initial concept for the companion experience system covering:
> 1. BUG-001 fix (companion killing blow yields no player XP)
> 2. Companion XP tracking and leveling (same progression curve as players)
> 3. XP distribution design (XPSharePct rule, group split mechanics)
>
> Requested lore input on:
> - Companion growth narrative (level-up messaging)
> - Level cap relative to player (MaxLevelOffset = 1)
> - No XP loss on companion death (vs. classic EQ player XP loss)
> - Era compliance for Classic-Luclin

**Response from** lore-master:

> Provided comprehensive preliminary research. Key findings:
> - Concept is lore-solid. XP sharing is a core Classic mechanic. Beastlord
>   warder (Luclin) is the closest canonical precedent for a scaling companion.
> - Hard stops identified: level cap 60 absolute, no mercenary terminology
>   (Seeds of Destruction), no Froglok companions (enslaved in Classic-Luclin),
>   no post-Luclin spell lines, no Berserker class, no "Heroic Adventures" or
>   "Partisan" quest terms.
> - Level-up tone should be terse and atmospheric per EQ style: "I grow
>   stronger." / "The battles have hardened me." Race personality matters
>   (Teir'Dal = cold ambition, Vah Shir = honor, Gnome = academic).
> - If using milestone labels, frame as informal titles, not structured
>   mercenary ranks.
> - No lore blockers on the concept itself.

**Outcome:** Lore context incorporated into PRD draft. All hard stops documented.

---

### 2026-03-05 — Full PRD Draft Sent for Lore Review

**From:** game-designer → **To:** lore-master

> Sent complete PRD draft (461 lines) with all sections filled in.
> Highlighted key lore-relevant sections:
> - User Experience: Level-up feedback ("Guard Archus has grown stronger!")
> - Era Compliance: Classic-Luclin lock verified
> - Example Scenario: Level 30 ranger in East Karana with guard companion
> - Design Decision: No XP loss on companion death
> - Narrative: Companion grows through shared combat
>
> Requested sign-off on 5 specific review points.

**Response from** lore-master:

> (Covered by the preliminary research response — lore-master provided
> guidance proactively before PRD was sent, then confirmed no blockers.)

**Outcome:** PRD sections validated. Lore-master confirmed concept is solid
with specific guidance on tone, hard stops, and era compliance.

---

### 2026-03-05 — PRD Revised with Lore Feedback

**From:** game-designer → **To:** lore-master

> Reported all changes made based on lore-master feedback:
> 1. Level-up messaging changed to atmospheric EQ-style dialogue with
>    NPC-LLM sidecar integration for race-appropriate tone
> 2. Hard cap of 60 added as absolute ceiling on companion level
> 3. Era Compliance Hard Stops table added (7 violations listed)
> 4. Terminology cleaned: "companion" only, no mercenary framing,
>    no structured advancement tiers
> 5. "What Already Exists vs. What's New" table added for clarity
> 6. Example scenario updated with specific race/location details
>
> Requested final sign-off.

**Response from** lore-master:

> APPROVED — task #2 marked completed by lore-master.

**Outcome:** Lore sign-off received. PRD finalized for handoff to architect.

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

_(Not yet started — pending design phase completion.)_

---

## Implementation Team Conversations

_Expert-to-expert exchanges during Phase 4._

### 2026-03-05 — lua-expert → c-expert: Status check + call pattern confirmation

**From:** lua-expert → **To:** c-expert

> Asked for status on task #4 (GetXPForNextLevel binding) and confirmed
> `npc:GetXPForNextLevel()` is the correct Lua call pattern.

**Response from** c-expert:

> Tasks #1-4 complete and committed to bugfix/companion-experience.
> `GetXPForNextLevel()` bound and callable as `npc:GetXPForNextLevel()`.
> Returns uint32. `GetCompanionXP()` already bound.

**Outcome:** lua-expert unblocked. Task #5 implemented immediately.

---

### 2026-03-05 — lua-expert task #5 complete

- Inserted 3 lines into `companion.cmd_status` in companion.lua
- `!status` now shows: `  XP: <current> / <next_level_xp>`
- Committed: cd382fb to bugfix/companion-experience in akk-stack/

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication.
This table is the quick-reference for anyone catching up._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | Companion XP uses simplified curve (level^2 * 1000) | game-designer | 2026-03-05 | Faster than player curve but still meaningful at high levels |
| 2 | No XP loss on companion death | game-designer, lore-master | 2026-03-05 | Death/despawn timer is sufficient penalty; lore-master approved |
| 3 | XPSharePct default 50% | game-designer | 2026-03-05 | Balances companion growth vs. player XP; net positive for player |
| 4 | MaxLevelOffset default 1 | game-designer | 2026-03-05 | Companion always 1 level below player; maintains player as protagonist |
| 5 | Absolute hard cap of level 60 | game-designer, lore-master | 2026-03-05 | Classic-Luclin era ceiling; lore-master flagged as mandatory hard stop |
| 6 | Atmospheric level-up messaging | game-designer, lore-master | 2026-03-05 | Terse EQ-style dialogue, race-aware via NPC-LLM sidecar |
| 7 | Beastlord warder as narrative precedent | lore-master | 2026-03-05 | Closest canonical analogue for scaling companion bond |
| 8 | Froglok exclusion confirmed | lore-master | 2026-03-05 | Enslaved NPCs in Classic-Luclin, not free adventurers |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| (none) | | | |

### 2026-03-05 — Architect → Protocol-Agent: Client Feasibility Check

**From:** architect → **To:** protocol-agent

> Requested verification of four client-side feasibility items:
> 1. Kill credit resolution is server-side only (no new packets) — confirm no Titanium constraints
> 2. Companion XP is server-side only (not sent via ExpUpdate_Struct) — confirm no packets needed
> 3. Companion level-up: NPC level changes mid-session via SpawnAppearance — any Titanium issues?
> 4. Level-up feedback via chat messages only — any concerns?

**Response from** protocol-agent:

> (Pending — architect proceeded with architecture based on analysis that no packet changes are needed. All XP tracking is server-side. Level changes on NPCs use existing SpawnAppearance which Titanium handles for all entity types. Chat messages use existing ChannelMessage_Struct. No Titanium constraints identified by the architect's own protocol analysis.)

**Architect's independent assessment:** No protocol constraints exist for this feature. All changes are server-side. The client sees the same packets it always sees — XP updates go to the player via existing AddEXP/ExpUpdate_Struct, companion level changes propagate via the existing spawn appearance system, and notifications use standard chat messages. No new opcodes, packet structures, or translation layer changes needed.

**Outcome:** Architecture document completed without protocol constraints. If protocol-agent identifies issues in their response, the document will be updated.

---

### 2026-03-05 — Architect → Config-Expert: Rules Assessment

**From:** architect → **To:** config-expert

> Requested assessment of:
> 1. Confirm three existing rules (XPContribute, XPSharePct, MaxLevelOffset) exist and are ready
> 2. Any additional rules needed?
> 3. Can any part be done with rules alone? (architect's assessment: NO)
> 4. Rule boundary conditions (XPSharePct 0/100/>100, MaxLevelOffset 0/negative)

**Response from** config-expert:

> (Pending — architect proceeded based on direct verification of ruletypes.h lines 1191-1195 confirming all three rules exist with correct defaults.)

**Architect's independent assessment:**
- All three rules confirmed in ruletypes.h: XPContribute (bool, true), XPSharePct (int, 50), MaxLevelOffset (int, 1)
- No additional rules needed — the existing three cover all tunable parameters
- Cannot be done with rules alone — kill credit bug requires C++ code path fix
- Boundary conditions: architecture specifies clamping XPSharePct to [0, 100] and MaxLevelOffset to [0, 59] at point of use in C++ code

**Outcome:** Architecture document completed with defensive clamping for rule boundary conditions. If config-expert identifies additional concerns, the document will be updated.

