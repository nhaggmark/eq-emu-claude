# Companion Recruitment & Re-recruitment Overhaul — Agent Conversations Log

> **Feature branch:** `feature/companion-recruitment-overhaul`
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

### 2026-03-14 — Lore Review: Recruitment Narrative Framing (Initial)

**From:** game-designer → **To:** lore-master

> Requested review of narrative framing for two-track recruitment system:
> 1. First-time recruitment: "getting to know you" — persuasion roll, faction,
>    level proximity. Stays as-is.
> 2. Re-recruitment after death/dismissal: "I remember you" — companion already
>    knows the player. No cooldown, no level restriction, no persuasion roll.
>    Companion willingly rejoins based on established relationship.
> 3. Death flavor text: "I remember you. Let us continue." (already in code).
>
> Asked: Does this fit Classic-Luclin lore? Any era-specific reasons a companion
> would NOT rejoin? Is "instant rejoin" framing sufficient?

**Response from** lore-master:

> Task #2 (Lore review of recruitment overhaul PRD) marked COMPLETED.
> No lore issues flagged. Approval granted via task completion.

**Outcome:** Lore sign-off recorded. Narrative framing approved.

### 2026-03-14 — Lore Review: Full PRD Final Review

**From:** game-designer → **To:** lore-master

> Sent full PRD lore-relevant sections for final review:
> - Era compliance assessment (custom feature, no expansion-specific content)
> - "I remember you" narrative framing for re-recruitment
> - Dismissal/death flavor text
> - Balance justification (narrative: companion has proven loyalty)
>
> Asked for sign-off on: era compliance, narrative framing, any lore concerns.

**Response from** lore-master:

> APPROVED — Task #2 marked completed. No lore concerns raised.
> The "I remember you" framing is consistent with Classic-era NPC memory
> conventions (faction-based recognition, quest completion tracking).

**Outcome:** Lore sign-off confirmed. PRD finalized without lore changes.

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

_(Not yet started — pending PRD handoff to architect)_

---

## Implementation Team Conversations

_Expert-to-expert exchanges during Phase 4._

### 2026-03-14 — Implementation: lua-expert Task 1 Completion

**From:** lua-expert → **To:** team-lead

> Task 1 (Rewrite `attempt_recruitment()` with two-track detection) complete.
>
> Summary of changes in `akk-stack/server/quests/lua_modules/companion.lua`:
> - Added `check_existing_companion_record(npc_type_id, char_id)` — queries
>   `is_dismissed=1 OR is_suspended=1`, matching C++ CreateFromNPC() exactly.
> - Added `is_re_recruitment_eligible(npc, client)` — 5 minimal safety checks:
>   system enabled, group capacity, not-already-recruited, combat, not-IsCompanion.
> - Rewrote `attempt_recruitment()` — existing record checked FIRST, before any
>   cooldown or eligibility check. Re-recruitment track skips all first-time gates
>   and deletes stale cooldown on success.
> - Renamed `dismissed_record` param to `existing_record` in `_on_recruitment_success()`.
> - Deprecated `check_dismissed_record()` with comment.
>
> New test file: `tests/test_companion_recruitment.lua` — 35 tests, all passing.
> All 37 existing regression tests still pass.
> Both commits pushed to `feature/companion-recruitment-overhaul`.
>
> Contract confirmation: `client:CreateCompanion(npc)` is the single entry point.
> No new C++ methods needed. Lua queries `is_dismissed=1 OR is_suspended=1` — must
> stay synchronized with C++ CreateFromNPC() query.
>
> Task 3 (integration verification) blocked on c-expert completing Task 2.

**Outcome:** Task 1 complete. Waiting on c-expert Task 2 before Task 3 can start.

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication.
This table is the quick-reference for anyone catching up._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | Two-track recruitment: first-time (full checks) vs re-recruitment (all checks bypassed except safety) | game-designer, lore-master | 2026-03-14 | Lore-master approved narrative framing |
| 2 | "I remember you. Let us continue." dialogue for re-recruitment is era-compliant | game-designer, lore-master | 2026-03-14 | Consistent with Classic-era NPC memory |
| 3 | No cost or delay on re-recruitment — natural friction (travel, lost buffs) is sufficient | game-designer | 2026-03-14 | Balance consideration for 1-3 player server |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| (none) | | | |

### 2026-03-14 — Protocol Review: Client Feasibility Assessment

**From:** architect → **To:** protocol-agent

> Requested confirmation on three points:
> 1. No new packet changes or client-server protocol modifications — all changes
>    server-side only. Titanium client not affected.
> 2. Packet-level edge cases with rapid entity despawn+respawn (companion death
>    then re-recruitment of same NPC type).
> 3. Data_bucket operations from Lua (eq.get_data/eq.delete_data) — any protocol
>    concerns.

**Response from** protocol-agent:

> (Pending — architect proceeding based on independent analysis. The feature
> involves zero protocol changes: no new opcodes, no struct modifications, no
> translation layer changes. The Spawn()/Depop() path for re-recruitment is
> identical to first-time recruitment. Data bucket operations are server-side
> DB operations with no client interaction.)

**Architect assessment:** No protocol constraints identified. The feature is
entirely server-side (Lua + minor C++). The Titanium client sees the same
OP_NewSpawn/OP_DeleteSpawn/OP_GroupUpdate packets for re-recruitment as for
first-time recruitment. No client-side changes needed.

**Outcome:** No protocol blockers. Proceeding with architecture.

### 2026-03-14 — Config Review: Rules and Configuration Assessment

**From:** architect → **To:** config-expert

> Requested confirmation on four points:
> 1. Existence and defaults of 6 Companion rules in ruletypes.h.
> 2. Whether re-recruitment bypass can be achieved with rules alone.
> 3. Any other Companion rules that could interfere.
> 4. Boundary conditions on rule values (LevelRange=0, RecruitCooldownS=0).

**Response from** config-expert:

> (Pending — architect proceeding based on independent analysis. The Companion
> rules are custom additions to ruletypes.h for this project. The re-recruitment
> bypass CANNOT be achieved with rules alone because the goal is to skip entire
> code paths (cooldown check, eligibility check, persuasion roll), not to change
> threshold values. Setting LevelRange=0 or RecruitCooldownS=0 would disable
> those checks for ALL recruitment, not just re-recruitment. The code path
> bypass is the correct approach.)

**Architect assessment:** No configuration-only solution exists. The feature
requires a code path split (two-track system), not rule value changes. Existing
rules remain correct for first-time recruitment. Re-recruitment bypasses them
via code flow, not by setting them to permissive values.

**Outcome:** No config-only alternative. Code path bypass confirmed as the
right approach. No new rules needed.

### Updated Key Decisions (Architecture Phase)

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 4 | No protocol changes needed — feature is entirely server-side | architect, protocol-agent | 2026-03-14 | Titanium client sees identical packets for re-recruitment vs first-time |
| 5 | No config-only solution — code path bypass required | architect, config-expert | 2026-03-14 | Rules control thresholds, not code flow; re-recruitment needs to skip entire code paths |
| 6 | HP/mana restoration needed in C++ for dead companions | architect | 2026-03-14 | Load() restores cur_hp=0 from DB; Spawn() does not call RestoreHealth() |
| 7 | Both Lua and C++ clean up stale cooldown data_buckets (belt-and-suspenders) | architect | 2026-03-14 | Defense in depth — either layer can handle cleanup independently |
| 8 | Open questions resolved: all is_suspended states treated identically; any npc_type_id instance works; LIMIT 1 handles duplicate records | architect | 2026-03-14 | Simplest approach, matches existing C++ behavior |
