# Companion Rez Vanish — Agent Conversations Log

> **Feature branch:** `bugfix/companion-rez-vanish`
> **Created:** 2026-05-03

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

### 2026-05-03 — Lore-master excluded by team-lead instruction

**From:** team-lead → **To:** game-designer (and design-team scoping)

> Lore-master is not on the design team for this bug-fix workspace.
> No lore/narrative content in a behavior bug fix.

**Outcome:** game-designer authored the PRD solo. No lore review
performed; not required for this bug-fix workspace. Design Team section
is intentionally otherwise empty for this workspace.

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

### 2026-05-03 — protocol-agent advisory: client packet impact of OLD-entity depop on rez

**From:** architect → **To:** protocol-agent (advisory)

> The proposed fix to BUG-001 rez-vanish is to depop the OLD dead
> Companion entity inside `Companion::ResurrectFromCorpse()` before
> creating the NEW rezzed entity. The OLD entity has a different
> entity_id from the NEW rezzed entity. After Death(), the OLD entity
> is invisible-by-corpse-occlusion (the corpse object renders, OLD's
> ping_timer keeps OLD's stationary position packets going for client
> visibility of the dead body). After Spawn() of NEW, both OLD and the
> corpse are depopped. From the Titanium client's perspective, what
> packets does the proposed change emit/suppress vs the current path?

**Response from protocol-agent:**

> Current path (pre-fix): Death() emits `OP_Death` for OLD's entity_id
> at death time. OLD's ping_timer continues to emit
> `OP_PlayerPositionUpdate` with zero deltas every 5s for OLD's
> entity_id (this is the BUG-002 heartbeat hoist that keeps the
> dead-body entity visible to the Titanium client). On rez,
> `corpse->DepopNPCCorpse()` emits `OP_DeleteSpawn` for the corpse
> entity (separate from OLD). NEW's `Spawn()` emits `OP_NewSpawn` for
> NEW's entity_id and `OP_GroupUpdate` (groupActJoin) for the group
> slot. Eventually OLD's death-timer fires and OLD returns false from
> Process() — at that point the entity reaper emits `OP_DeleteSpawn`
> for OLD's entity_id (visible to client as the dead body fading
> after 30 minutes).
>
> Proposed path (post-fix): same as current path through NEW's Spawn().
> The difference is when `OP_DeleteSpawn` for OLD's entity_id is
> emitted: pre-fix, at T_death + DeathDespawnS (30 min later);
> post-fix, at rez time (immediately after NEW spawns). The Titanium
> client handles `OP_DeleteSpawn` the same way at any time, so this is
> a no-op behavioral change for the client. No new opcodes, no struct
> size changes, no new packet fields.
>
> One minor consideration: at the instant of rez, the player will see
> the dead body of OLD vanish (OP_DeleteSpawn) at the same time as NEW
> appears (OP_NewSpawn). This is the same visual sequence the client
> sees today after a player rez completes. No client UX issue.
>
> No client constraints. APPROVED — no issues.

**Outcome:** Fix design proceeds without protocol changes.

### 2026-05-03 — config-expert advisory: rule changes for OLD-entity depop on rez

**From:** architect → **To:** config-expert (advisory)

> The proposed fix to BUG-001 rez-vanish is purely an entity-management
> change in `Companion::ResurrectFromCorpse()`. Are there existing
> Companions:* rules that the fix should consult? Should the fix be
> rule-gated or always-on?

**Response from config-expert:**

> Existing relevant rules in `Companions` category (ruletypes.h:1156+):
> - `Companions:DeathDespawnS` (default 1800) — controls how long the
>   dead body lingers and the auto-dismiss timer. Pre-fix this rule
>   acts as the LATCH for the bug (it determines when the corrupt-DB
>   write happens). Post-fix this rule continues to gate the auto-
>   dismiss path for un-rezzed dead companions, which is correct and
>   should remain.
> - `Companions:RezPostCombatDelayS` (default 10) — gates how long
>   after combat ends before a Cleric companion attempts rez.
>   Unaffected by the fix.
> - `Companions:RezEnabled` — gates the entire rez subsystem. If false,
>   no rez can happen, so this fix is a no-op when rez is disabled.
>   No new rule needed to gate the fix itself.
>
> Recommendation: do NOT introduce a new `Companions:RezDepopOldEntity`
> rule or similar. The fix is correctness, not behavior tuning — it
> should always-on. Adding a rule would just create a footgun where
> someone disables it and rez-vanish returns. Existing rules continue
> to apply with no changes.
>
> No rule changes. APPROVED — no issues.

**Outcome:** Fix is always-on; no rule changes; existing rules continue
to apply unchanged.

### 2026-05-03 — Self-review: enumeration of customized-system consumers

**From:** architect (self-review per refactor-regression discipline)

> Per `feedback_refactor_regression_discipline.md`, every fix to a
> customized-system code path must enumerate adjacent consumers BEFORE
> proposing the fix. The 12-consumer enumeration is in
> `architecture.md` under "Antagonistic / Adjacent System Enumeration."
> Summary: all 12 consumers are either unaffected or strictly improved
> by the fix.

**Outcome:** Enumeration recorded in architecture.md. No additional
consumers identified that require fix-side changes.

---

## Implementation Team Conversations

### 2026-05-03 — c-expert implementation complete

**From:** c-expert (self-log)

**Work completed:**

1. Read BUG-001 report, PRD, architecture.md, and agent-conversations.md per protocol.
2. Added Suite 38 to `eqemu/zone/cli/tests/cli_companion_tests.cpp` — 19 tests across 3 sub-tests:
   - 38.1: documents pre-fix broken state (2 entities share companion_id) + verifies Depop contract
   - 38.2: verifies death-despawn-timer corruption path severed after Depop(false)
   - 38.3: verifies zone-save race resolved (only NEW saves, is_suspended=0, is_dismissed=0)
3. Implemented fix in `eqemu/zone/companion.cpp::ResurrectFromCorpse()`: added 29-line block
   after `corpse_pos` capture (line 3662) that scans `entity_list.GetCompanionList()` for the OLD
   entity matching `(companion_id, owner_char_id)` and calls `Depop(false)` before `new Companion`.
   AC-6 log line: `Companion::ResurrectFromCorpse: depopping OLD dead entity (entity_id={}, companion_id={})`.
4. Built clean: 244/244 ninja targets, no errors or warnings.
5. Tests: 587 PASSED, 1 pre-existing FAIL (Suite 36.4a — unrelated to this fix, pre-existing state issue).
   Suites 35, 36, 37 all GREEN. Suite 38 all 19 tests GREEN.
6. Committed to `bugfix/companion-rez-vanish` branch in eqemu/:
   - `3bd91a645` — test(companion): add Suite 38 TDD tests for BUG-001 rez-vanish OLD entity depop
   - `3ed5f852a` — fix(companion): depop OLD dead entity in ResurrectFromCorpse (BUG-001 rez-vanish)
7. Pushed to remote.

**Note on Suite 38 test design:** `ResurrectFromCorpse` requires a live `Client*` in zone — cannot
be called directly in unit tests (same constraint documented in Suite 29 comment at line 6837).
Suite 38 uses structural tests (same pattern as Suite 36) that verify the fix's invariants: Depop
removes from companion_list, timer corruption path is severed, zone-save race is resolved.
The end-to-end behavioral validation (rez → 30min wait → still alive; rez → zone 3x → still alive)
is delegated to game-tester per the PRD repros A/B/C/D.

**Ready for:** server restart (infra-expert) + game-tester validation against repros A/B/C/D.

---

## Validation Team Conversations

_(Filled in once game-tester runs the four PRD repros.)_
