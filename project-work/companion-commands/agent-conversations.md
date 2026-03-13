# Companion Commands — Agent Conversations Log

> **Feature branch:** `feature/companion-commands`
> **Created:** 2026-03-13

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

### 2026-03-13 — Early Lore Review: Companion Command Changes

**From:** game-designer → **To:** lore-master

> Sent early feature concept for lore review before writing PRD sections.
> Three changes described:
> 1. !hold command — combines guard + passive, companion says "Holding position."
> 2. !tome update — adds target-clearing and attack deactivation on recall
> 3. !help rework — alphabetically sorted formatting, pure UI change
>
> Asked if any of these raise lore concerns. Noted that all changes are purely
> mechanical with no new NPCs, quests, factions, zones, or cultural content.

**Response from** lore-master:

> Responded as part of the full PRD review (see next entry). No separate
> early response was needed — the full review covered all items.

**Outcome:** Covered by full PRD review below.

### 2026-03-13 — Final PRD Lore Review

**From:** game-designer → **To:** lore-master

> Sent complete PRD for final lore continuity check. PRD covers:
> - REQ-1: !help rework (formatting only, no target required)
> - REQ-2: !hold new command (guard + passive combo)
> - REQ-3: !tome update (clear target, stop attacking on recall)
> - REQ-4: Documentation updates (fix 5 discrepancies)
> - REQ-5: Test coverage requirements
> - Complete audit of all 23 existing commands
> - Era compliance section noting !hold analogous to Classic /pet hold

**Response from** lore-master:

> **APPROVED — no blocking issues.**
>
> Era compliance: All elements verified Classic-through-Luclin compliant.
> Command naming: All names fit era conventions. !hold is authentically
> grounded in EQ guard/military vocabulary and Classic /pet hold precedent.
> Dialogue strings: "Holding position.", "Already holding position.",
> "[Name] is dead and cannot hold position." all match established style.
> Example scenario: Sebilis dungeon crawl is era-appropriate (Kunark).
> Documentation discrepancies: All 4 identified issues confirmed accurate.
>
> **One non-blocking observation:** !tome name is lore-incongruous (tomes
> are books in EQ, not movement commands). Pre-existing issue, not
> introduced by this PRD. Flagged for the record only.

**Outcome:** Lore sign-off recorded. PRD approved for architecture phase.
Non-blocking !tome naming observation noted in lore-master/lore-notes.md.

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

### 2026-03-13 — Protocol Feasibility Review

**From:** architect → **To:** protocol-agent

> Sent three questions for protocol feasibility review:
> 1. !help without target routing: Confirmed that Player EVENT_SAY fires at
>    client.cpp:1609 before NPC EVENT_SAY at line 1633. Proposed intercepting
>    !help in global_player.lua via event_say(e). Asked about Titanium constraints.
> 2. !hold command: Purely Lua-side using existing SetStance, WipeHateList,
>    SetGuardMode bindings. Asked about protocol concerns.
> 3. !tome target clearing: Adding WipeHateList after GMMove. Asked about
>    protocol-level edge cases with clearing hate while mobs still pursue.
>
> Summary: All three changes appear pure Lua-layer, no C++ or protocol changes.

**Response from** protocol-agent:

> **APPROVED — no protocol concerns.**
> All three changes are server-side Lua. No new packets, opcodes, or struct
> changes needed. Player EVENT_SAY interception is standard. WipeHateList is
> server-side only and doesn't affect packet flow. No Titanium constraints.

**Outcome:** Protocol feasibility confirmed. All changes stay in Lua layer.

### 2026-03-13 — Configuration/Rules Review

**From:** architect → **To:** config-expert

> Sent three questions about existing rules and configuration:
> 1. Is there an existing rule for "hold" behavior? Checked Companions category.
> 2. Can !help rework be done without rule changes?
> 3. Any existing rules controlling target-clearing behavior?
>
> Also asked about all Companions-category rules that might interact.

**Response from** config-expert:

> **CONFIRMED — no rule changes needed.**
> No existing rules govern hold behavior, help display format, or
> target-clearing. The Companions-category rules (CompanionsEnabled,
> RecallCooldownS, EnforceClassRestrictions, EnforceRaceRestrictions)
> are unaffected by any of the three changes. All changes require Lua
> code, not configuration.

**Outcome:** Configuration-first principle verified. No config shortcuts available;
Lua implementation is the correct and least-invasive approach.

---

## Implementation Team Conversations

_Expert-to-expert exchanges during Phase 4._

### [Date] — [Topic]

**From:** [agent] → **To:** [agent]

> [Message content or summary]

**Response from** [agent]:

> [Response content or summary]

**Outcome:** _What was decided or changed as a result_

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication.
This table is the quick-reference for anyone catching up._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | PRD lore-approved for architecture | game-designer, lore-master | 2026-03-13 | All changes Classic-Luclin compliant. !hold name grounded in /pet hold precedent. |
| 2 | !tome naming flagged as non-blocking | lore-master | 2026-03-13 | Tomes are books in EQ lore; existing name, not changed by this PRD. |
| 3 | All changes confirmed pure Lua — no protocol impact | architect, protocol-agent | 2026-03-13 | Player EVENT_SAY interception, WipeHateList, SetGuardMode all server-side. No Titanium constraints. |
| 4 | No existing rules can achieve these changes | architect, config-expert | 2026-03-13 | Companions-category rules unaffected. Lua code is required for all three features. |
| 5 | !hold tracked as guard+passive, not new mode | architect | 2026-03-13 | companion_modes "guard" + stance==0 is sufficient. No third mode value needed. |
| 6 | !tome uses WipeHateList, not SetTarget(nil) | architect | 2026-03-13 | Avoids luabind nil-conversion risk. WipeHateList is proven safe in codebase. |
| 7 | !help uses Player EVENT_SAY, not C++ routing | architect | 2026-03-13 | global_player.lua event_say fires before NPC dispatch (client.cpp:1609 vs 1633). No C++ changes. |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| !tome command naming incongruity | lore-master | Non-blocking flag | No |
| (No architecture-phase unresolved threads) | — | — | — |
