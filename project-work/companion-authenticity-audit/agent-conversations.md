# Companion Authenticity Audit — Agent Conversations Log

> **Feature branch:** `feature/companion-authenticity-audit`
> **Created:** 2026-03-14

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

### [Date] — [Topic]

**From:** [agent] → **To:** [agent]

> [Message content or summary]

**Response from** [agent]:

> [Response content or summary]

**Outcome:** _What was decided or changed as a result_

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

### [Date] — [Topic]

**From:** [agent] → **To:** [agent]

> [Message content or summary]

**Response from** [agent]:

> [Response content or summary]

**Outcome:** _What was decided or changed as a result_

---

## Implementation Team Conversations

_Expert-to-expert exchanges during Phase 4._

### 2026-03-14 — C++ audit complete, findings summary to team-lead

**From:** c-expert → **To:** team-lead

> Task #1 complete. Full audit written to
> `claude/project-work/companion-authenticity-audit/c-expert/dev-notes.md`.
> 18 systems audited.
>
> Critical gaps found:
> 1. MAJOR: No critical hits — `attack.cpp:5446` `if (IsNPC() && !RuleB(Combat, NPCCanCrit))` blocks all companions. Fix: add `&& !IsCompanion()` guard.
> 2. MAJOR: Missing defensive skills — NPC constructor never sets SkillDefense/Parry/Riposte/Dodge/Block for companions. Level 60 warrior loses ~85 AC from Defense and can never parry, dodge, riposte, or block.
> 3. SIGNIFICANT: PC-only spell targeting gap — `spells.cpp:832,838,3940,3945,6999,7094` lists `IsClient()||IsMerc()||IsBot()` but not `IsCompanion()`. Player-only buffs cannot target companions.
>
> Systems confirmed correct: AC divisors, STA-to-HP, MaxMana (BUG-017 fix), weapon damage path, haste, dual wield, double/triple attack, focus effects.
>
> Intentional divergences: resist caps at 70% of player cap, always-meditate regen, no fizzle.

**Outcome:** Findings delivered. Task #1 marked complete. Ready for architect synthesis in Task #4.

---

### 2026-03-14 — Lua audit complete, findings summary to team-lead

**From:** lua-expert → **To:** team-lead

> Task #2 complete. Full audit written to
> `claude/project-work/companion-authenticity-audit/lua-expert/dev-notes.md`.
>
> Key findings:
> 1. MAJOR: No autonomous combat spell casting in Lua — all combat AI must be in C++
>    `Companion::AI_SpellCast()` or it doesn't happen at all.
> 2. MINOR: Level-up LLM dialogue incomplete — `companion_culture.lua` defines a
>    "level_up" event type but `global_npc.lua` has no `event_level_up` NPC handler.
> 3. DESIGN QUESTION: `REREC_BONUS = 10` defined in `companion.lua:74` but never
>    applied. Help text advertises "+10% bonus" on re-recruit but re-recruitment is
>    unconditional (always succeeds). Needs design clarification.
> 4. MINOR: Unprompted commentary uses `npc:Say()` (public channel) while all command
>    responses use `group:GroupMessage()`. Inconsistent channel routing.
> 5. CONFIRMED: Nil-guard fragility on all `Lua_Companion`-specific methods
>    (SetStance, GetStance, SetGuardMode, etc.) — silent no-ops when luabind
>    inheritance fails. Fix is in C++ lua_companion.cpp.

**Outcome:** Findings delivered. Task #2 marked complete.

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication.
This table is the quick-reference for anyone catching up._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| | | | | |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| | | | |
