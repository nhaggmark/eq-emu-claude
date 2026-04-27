# XP Retune — Agent Conversations Log

> **Feature branch:** `feature/xp-retune`
> **Created:** 2026-04-27

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

### 2026-04-27 — Lore Review: full PRD sign-off

**From:** game-designer → **To:** lore-master

> Requested explicit lore sign-off on the finalized xp-retune PRD before closing
> out the Design phase. Summarized the change as a pure numerical rule tune:
> `Character:ExpMultiplier` 3.0 → 2.0, `Character:AAExpMultiplier` stays 3.0,
> no content/NPCs/zones/factions/quest dialogue touched, single-row UPDATE on
> `rule_values` applied live via `#reloadrules`. Asked for either APPROVED or
> specific lore concerns. Linked PRD path:
> `/mnt/d/Dev/eq/claude/project-work/xp-retune/game-designer/prd.md`

**Response from** lore-master:

> APPROVED — no lore concerns. Specifically called out:
> - Rule tune is a pure numeric knob — no NPC/zone/faction/item/dialogue references
> - Era compliance unaffected — rule_values are server config, not content;
>   2x kill XP fits all four locked eras (Classic/Kunark/Velious/Luclin)
> - AA XP unchanged at 3.0x — no lore implications
> - Quest/task XP — global multiplier applies uniformly; no narrative framing altered
> - No issues, no suggestions, no constraints for architect or implementation team

**Outcome:** Lore sign-off recorded. PRD unchanged. Design phase ready to close.

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

### 2026-04-27 — Architect → config-expert: SQL + reload command verification

**From:** architect → **To:** config-expert

> Asked config-expert to confirm three points before freezing the architecture doc:
> 1. The exact UPDATE statement (`UPDATE rule_values SET rule_value = '2' WHERE
>    ruleset_id=1 AND rule_name='Character:ExpMultiplier'`) hits exactly one
>    row, and the current row reads `'3'`.
> 2. `Character:AAExpMultiplier` is also currently `'3'` for ruleset 1 (so the
>    PRD's "AA stays at 3.0x" statement matches the live DB) and is **not**
>    going to be touched by this change.
> 3. `#reloadrules` is the correct GM command and propagates to all running
>    zones (or whether `#reloadworld` is needed).
>
> Bonus: confirm `Character:ExpMultiplier` is not consumed by any quest XP path
> (`quest::exp()`, task rewards) that would surprise the rollback criteria.

**Response from** config-expert:

> Validation complete:
> - **Rule name and current values CONFIRMED** — `Character:ExpMultiplier` =
>   `3.0` and `Character:AAExpMultiplier` = `3.0` on ruleset_id=1 (string
>   format `'3.0'`, not `'3'`).
> - **SQL syntax CONFIRMED** — forward UPDATE sets `'2.0'`, rollback sets
>   `'3.0'`, both with the same scoped WHERE clause.
> - **CORRECTION on reload command** — `#reloadrules` does **not** exist.
>   Verified against `command_settings` and `zone/gm_commands/rules.cpp`. The
>   actual commands are `#reloadallrules` (zone-local) and
>   `#reloadrulesworld` (broadcast to all running zone processes). For an
>   XP rule change across 8 dynamic zones we want `#reloadrulesworld`.
> - **Inactive ruleset note** — ruleset_id=10 also has
>   `Character:ExpMultiplier = 3.0` but is not loaded by any zone; the
>   WHERE `ruleset_id = 1` is correctly scoped.
> - **Quest XP path confirmation** — `Character:ExpMultiplier` is consumed
>   only on the kill-XP path; quest grants and task rewards do not route
>   through it. Companion XP rules are independent custom rules.

**Outcome:** Two corrections incorporated into architecture.md:
1. Reload command upgraded from `#reloadrules` (nonexistent) to
   `#reloadrulesworld` (correct broadcast variant).
2. Rule values quoted as `'2.0'` / `'3.0'` to match the existing string
   format rather than `'2'` / `'3'`.

Architecture phase plan finalized. Single implementation task assigned to
config-expert.

---


### 2026-04-27 — Architect ← config-expert: full deep-dive findings

**From:** config-expert → **To:** architect (follow-up to first response)

> Full validation report against live DB and source. Headline findings:
>
> 1. **UPDATE statement** — confirmed single-row match on PK
>    `(ruleset_id, rule_name)`; current value is the string `'3.0'` (not
>    `'3'`). No triggers on `rule_values`. Forward UPDATE → `'2.0'`,
>    rollback → `'3.0'`.
> 2. **Reload command** — `#reloadrules` does NOT exist. Use
>    `#reloadrulesworld` (broadcast) for the no-restart live apply.
>    `#reloadallrules` is zone-local and would leave 7 of 8 zones stale.
> 3. **Inactive ruleset 10** — also has `Character:ExpMultiplier = 3.0`
>    but is not loaded by any zone; WHERE `ruleset_id = 1` is correctly
>    scoped.
> 4. **Quest XP path — IMPORTANT CORRECTION vs the first response.**
>    `Character:ExpMultiplier` IS applied to `quest::exp()`, Lua
>    `:AddEXP()`, and flat task-reward XP because they all funnel
>    through `Client::AddEXP()` (`exp.cpp:510`) which calls
>    `CalculateExp()` (`exp.cpp:428`) where the multiplier is applied.
>    The exception is `Client::AddLevelBasedExp()` (`exp.cpp:1091`),
>    used by `quest::addlevelbasedexp()` and percentage-typed task
>    rewards — that path uses `FinalExpMultiplier` and `LevelBasedEXPMods`
>    instead and does NOT apply `Character:ExpMultiplier`.

**Outcome:** Three corrections folded into architecture.md:
1. **Existing System Analysis → Current State** rewritten to describe
   `AddEXP()` as the single funnel for flat-XP grants, with
   `AddLevelBasedExp()` called out as the exception.
2. **Compatibility Risks** rewritten — quest grants and flat task
   rewards WILL scale 3.0x → 2.0x; that is consistent with the PRD's
   intent to slow leveling tempo, not a regression. Percentage-based
   grants are unaffected.
3. **Pass 3 Antagonistic** — replaced the erroneous "quest XP doesn't
   route through this rule" bullet with the correct funnel description
   plus a worked example (`quest::exp(1000)` → 2,000 XP after change).
4. **Validation Plan** — added two new checks:
   - Quest XP spot check on a flat `quest::exp()` / `:AddEXP()` reward
     (must drop to ~2/3 of the prior amount).
   - Percentage-quest-XP control check on a `quest::addlevelbasedexp()`
     reward (must be **unchanged** — proves the change did not bleed
     into the `AddLevelBasedExp` path).

This deeper trace is meaningful: the original architecture doc said
`Character:ExpMultiplier` is "consumed only on the kill-XP path." That
was wrong — it covers all flat-XP grants. The corrected version is now
in the doc and is what the implementation team and game-tester should
work from.

---

## Implementation Team Conversations

_Expert-to-expert exchanges during Phase 4._

_(Phase not yet started.)_

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication.
This table is the quick-reference for anyone catching up._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | PRD approved with no lore changes; pure numerical rule tune confirmed era-safe | game-designer, lore-master | 2026-04-27 | Design phase sign-off |
| 2 | Reload command corrected from `#reloadrules` to `#reloadrulesworld`; rule_value format aligned to `'2.0'`/`'3.0'` | architect, config-expert | 2026-04-27 | Architecture phase verification against live DB and `zone/gm_commands/rules.cpp` |
| 3 | `Character:ExpMultiplier` covers all flat-XP grants (kill, `quest::exp()`, Lua `:AddEXP()`, flat task rewards) via `Client::AddEXP()`; `AddLevelBasedExp` path is the exception | architect, config-expert | 2026-04-27 | Source trace through `exp.cpp:428/510/1091` and `task_client_state.cpp:1069/1076` |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| _(none)_ | | | |

### 2026-04-27 — Lore Review v2: Companion XP Parity expanded scope

**From:** game-designer → **To:** lore-master

> Requested re-sign-off on PRD v2 of xp-retune. Scope expanded from v1 (pure
> rule_values numeric tune) to add a second concern: Companion XP Parity —
> a C++ refactor of the companion XP distribution path so a companion in a
> group earns the same per-share XP as the player, in all group sizes (1+1
> through 1+4) and on all flat-XP event types (kill, `quest::exp()`, Lua
> `:AddEXP()`, flat task rewards). Also added a forward-looking design
> constraint: the refactor must leave AA-friendly seams so a future
> companion-AA feature can plug in without re-doing parity. Companion AAs
> are explicitly out of scope for this feature.
>
> Asked lore-master to confirm APPROVED (or flag specific concerns), since
> v1's approval predated the expanded scope.

**Response from** lore-master:

> APPROVED — no lore concerns.
> - Companion narrative dynamic: companion system is wholly custom; no
>   Classic-Luclin lore establishes a power-growth hierarchy between player
>   and recruited NPC companion. XP parity is lore-neutral.
> - Era-pacing concern: none. The four locked eras have no in-world
>   narrative about companion advancement rates — this is a server
>   mechanical concern, not a fiction surface.
> - Quest-flavored interactions: no existing quest scripts reference
>   companion XP accumulation or level progression as a narrative beat.
>   Companion level appears in mechanics (follow, guarding) but not in
>   lore dialogue or quest conditions that would conflict with parity.
> - Issues found: none. Suggestions offered: none.
> - Both scope components (ExpMultiplier rule change + companion XP path
>   refactor) are lore-neutral. No constraints for architect or
>   implementation team.
>
> Lore-master noted no Write tool was available in their session, so they
> could not directly update lore-notes.md or this conversations log. They
> requested game-designer record the sign-off on their behalf.

**Outcome:** Lore sign-off recorded for v2 expanded scope. PRD unchanged
post-review. Design phase v2 ready to close. Game-designer updated
lore-master's lore-notes.md with the v2 sign-off entry on lore-master's
behalf, per their request.
