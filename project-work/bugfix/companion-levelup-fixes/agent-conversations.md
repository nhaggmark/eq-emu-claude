# companion-levelup-fixes — Agent Conversations Log

> **Feature branch:** `bugfix/companion-levelup-fixes`
> **Created:** 2026-03-08

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

_Design phase was skipped for this bug fix. BUG-007 report and user audit
request serve as requirements._

---

## Architecture Team Conversations

_The architect was spawned solo by the user for a direct code audit. Protocol-agent
and config-expert were not co-spawned for this task. The architect performed
all analysis independently, documented below._

### 2026-03-08 — Protocol Analysis (self-assessment, protocol-agent not available)

**Architect self-assessment of protocol concerns:**

> The bug involves missing client packets during companion level-up. The fix
> adds two existing packet calls (`SendHPUpdate()` and `SendAppearancePacket()`)
> that are already used by bots and mercs. No new opcodes, no new packet
> structures, no Titanium translation changes needed.
>
> Titanium constraints verified:
> - `OP_SpawnAppearance` with `AppearanceType::WhoLevel` is a standard packet
>   the Titanium client handles for all entity types (NPCs, bots, mercs, players).
> - `OP_MobHealth` (via `CreateHPPacket()` in `SendHPUpdate()`) is also standard.
> - No new packet structs are introduced.
> - The companion's spawn struct already sets `NPC=0` (player-like) which ensures
>   the Titanium client treats it as a valid group member.

**Outcome:** No protocol concerns. Fix uses existing, well-tested packet types.

### 2026-03-08 — Configuration Analysis (self-assessment, config-expert not available)

**Architect self-assessment of config/rules concerns:**

> The fix does not add, modify, or depend on any rule values. No
> `eqemu_config.json` changes needed. The existing `Companions::MaxLevelOffset`
> rule is read but not modified. No new rules are required — the fix is
> purely about missing packet calls, not tunable behavior.
>
> Checked `common/ruletypes.h` for relevant rules:
> - `Companions::MaxLevelOffset` — used in CheckForLevelUp to cap level. No change needed.
> - `Companions::CompanionsEnabled` — boolean toggle. Not relevant to level-up packets.
> - No "level-up notification" or "group update" rules exist that would make
>   these packet calls configurable. The packet calls are mandatory for correct
>   client behavior, so they should not be behind a rule.

**Outcome:** No configuration concerns. Fix requires no rule changes.

---

## Implementation Team Conversations

_To be populated during Phase 4 (implementation)._

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication.
This table is the quick-reference for anyone catching up._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | No protocol concerns — fix uses existing packet types (SpawnAppearance, MobHealth) | architect (self-assessment) | 2026-03-08 | Protocol-agent not co-spawned; architect verified Titanium compatibility independently |
| 2 | No config/rules concerns — fix is packet-level, not tunable behavior | architect (self-assessment) | 2026-03-08 | Config-expert not co-spawned; architect verified no relevant rules exist |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| | | | |
