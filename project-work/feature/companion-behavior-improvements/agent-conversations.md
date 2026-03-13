# Companion Behavior Improvements — Agent Conversations Log

> **Feature branch:** `feature/companion-behavior-improvements`
> **Created:** 2026-03-12

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

_Skipped — bugs were filed directly by user with brainstorm notes as the feature brief._

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

### 2026-03-12 — Protocol feasibility check for BUG-023, BUG-024, BUG-025

**From:** architect → **To:** protocol-agent

> None of the three bugs (BUG-023 rogue positioning, BUG-024 LOM announcement,
> BUG-025 buff party scope) involve client-server packets, new opcodes, or
> Titanium wire format changes. All are server-side AI behavior (C++) and quest
> script logic (Lua). Please confirm no protocol constraints apply.

**Response from** protocol-agent:

> CONFIRMED — no protocol constraints. BUG-023 is purely server-side NPC
> movement (RunTo calls). BUG-024 uses existing CompanionGroupSay which goes
> through GroupMessage (standard group chat packet, already implemented).
> BUG-025 uses CastSpell which sends standard spell cast packets already
> handled by the Titanium client. No new opcodes, struct modifications, or
> translation layer changes needed.

**Outcome:** All three bugs are protocol-safe. No client-side constraints.

### 2026-03-12 — Existing rules check for companion behavior tuning (BUG-023, BUG-024, BUG-025)

**From:** architect → **To:** config-expert

> Three bugs need investigation:
> 1. BUG-023: Is there an existing rule for rogue backstab positioning distance?
> 2. BUG-024: Is there an existing rule for LOM mana threshold?
> 3. BUG-025: Is there a rule or config that affects buff casting behavior?

**Response from** config-expert:

> 1. **RogueBehindMob** (Companions:RogueBehindMob, bool, default true) — gates
>    whether rogue positioning is active at all. No rule for positioning distance.
>    Recommend adding one if the fix needs a tunable distance value. However, a
>    hardcoded small offset (2 units) is acceptable since this is geometry, not
>    game balance.
> 2. **No existing LOM rule.** The closest is Companions:ManaCutoffPct (20%)
>    which controls when DPS casters stop nuking, and Companions:HealerManaConservePct
>    (30%) for healer efficiency mode. Neither covers LOM announcements.
>    Recommend adding Companions:LOMThresholdPct with default 15.
> 3. **No buff casting rules.** The buff timer handler is entirely Lua with no
>    rule governance. No config changes needed for BUG-025 — it's a code logic
>    fix, not a tuning issue.

**Outcome:**
- BUG-023: Use existing RogueBehindMob as the toggle. Hardcode backstab offset
  (target model radius + 2 units). No new rule needed.
- BUG-024: Add new rule Companions:LOMThresholdPct = 15.
- BUG-025: No rule needed — pure Lua logic fix.

### 2026-03-12 — Antagonistic review: CastSpell on NPC targets

**From:** architect → **To:** protocol-agent

> For BUG-025, the buff timer handler calls CastSpell with NPC companions as
> targets. Does the spell system have any filtering that would reject beneficial
> spells cast by an NPC on another NPC? Checking DoCastingChecksOnTarget
> specifically.

**Response from** protocol-agent:

> DoCastingChecksOnTarget performs target validation (valid mob, spell target
> type compatibility, LoS checks). Beneficial spells (buffs) on same-group NPCs
> should pass. The main risk is if the spell's target_type is ST_Target (single
> target) — this should work for any Mob*. Group buffs (ST_Group) auto-target
> the caster's group, which includes NPC companions. No filtering issue expected.
> However, recommend verifying during testing that CastSpell actually lands on
> NPC group members — if it fails, SpellFinished() is the fallback (bypasses
> cast time and mana cost, but guaranteed to apply).

**Outcome:** CastSpell should work for NPC-to-NPC beneficial spells. Added risk
item for validation. SpellFinished() identified as fallback if CastSpell fails.

### 2026-03-12 — Config review: LOMThresholdPct rule design

**From:** architect → **To:** config-expert

> Proposing new rule: Companions:LOMThresholdPct, INT, default 15.
> This controls the mana percentage at which caster companions announce "LOM".
> Setting to 0 would effectively disable the feature. Does this conflict with
> any existing rule or create boundary condition issues?

**Response from** config-expert:

> No conflicts. The existing mana-related rules are:
> - ManaCutoffPct (20%): stops nuking — higher than LOM default, which makes
>   sense (stop casting before announcing LOM)
> - HealerManaConservePct (30%): switches to efficient heals — even higher
> - CompanionManaRegenMult (100%): regen scaling
>
> The ordering is logical: conserve (30%) > stop nuking (20%) > announce LOM (15%).
> Setting LOMThresholdPct to 0 disables cleanly since GetManaRatio() never returns
> negative values. No boundary issues.

**Outcome:** Rule approved. Ordering of mana thresholds is consistent.

### 2026-03-12 — Protocol feasibility check for BUG-026 and BUG-027

**From:** architect → **To:** protocol-agent

> Two new bugs added: BUG-026 (caster LOS positioning) and BUG-027 (always
> meditate regen). BUG-026 adds LOS checks to the caster positioning code in
> companion.cpp using CheckPositioningLosFN — purely server-side AI movement.
> BUG-027 modifies CalcManaRegen() to always use meditate formula — purely
> server-side regen calculation. Neither involves client packets, new opcodes,
> or wire format changes. Please confirm no protocol constraints apply.

**Response from** protocol-agent:

> CONFIRMED — no protocol constraints for either bug. BUG-026 uses
> CheckPositioningLosFN which does a zone map raycast — entirely server-side,
> no packets involved. The resulting RunTo/StopNavigation calls produce the
> same movement packets (OP_ClientUpdate / position updates) already handled
> by the Titanium client. BUG-027 modifies mana regeneration amounts which
> are applied server-side in NPC::Process(). The client receives ManaChange_Struct
> packets with updated mana values, which already works for all mana changes.
> No new opcodes, struct modifications, or translation layer changes needed.

**Outcome:** Both new bugs are protocol-safe. No client-side constraints.

### 2026-03-12 — Existing rules check for BUG-026 and BUG-027

**From:** architect → **To:** config-expert

> Two new bugs need rule assessment:
> 1. BUG-026: Is there an existing rule for caster LOS positioning behavior?
>    The fix adds CheckPositioningLosFN validation to the caster positioning
>    code. Should this be toggleable via a rule?
> 2. BUG-027: Is there an existing rule for always-meditate regen? The fix
>    bypasses the IsSitting() gate in CalcManaRegen(). The user explicitly
>    chose fun over authenticity. Should this be a rule?

**Response from** config-expert:

> 1. **No existing LOS positioning rule.** The CasterCombatRange rule (default
>    70) controls the desired distance but has no LOS component. Adding LOS
>    validation is a correctness fix, not a behavior toggle — a caster should
>    never intentionally run to a position where it cannot see the target.
>    Recommend: NO new rule for the LOS check itself. It should always be
>    active. The CasterCombatRange=0 disable already makes casters use default
>    melee behavior which doesn't need LOS checking.
> 2. **No existing always-meditate rule.** The closest is CompanionManaRegenMult
>    (100%) which is a multiplier on the regen result — it multiplies whatever
>    CalcManaRegen returns. But multiplying 2 (standing base) still gives much
>    less than the meditate formula output (~38 at level 60). These are
>    complementary, not redundant. Recommend: Add Companions:AlwaysMeditateRegen
>    as a BOOL (default true) since this is an explicit fun-over-authenticity
>    decision. The rule documents the design choice and allows toggling back.

**Outcome:**
- BUG-026: No new rule needed. LOS validation is a correctness fix, always active.
- BUG-027: Add `Companions:AlwaysMeditateRegen` (BOOL, default true).

### 2026-03-12 — Antagonistic review: BUG-026 LOS iteration performance

**From:** architect → **To:** config-expert

> For BUG-026, the LOS fallback iterates up to 6 positions (70% down to 20% of
> CasterCombatRange in 10% steps), calling CheckPositioningLosFN at each step.
> In the worst case this fires every tick (~250ms) for every engaged caster
> companion. With 5 caster companions engaged, that's 30 raycasts per tick.
> Is this a concern? Should the iteration be throttled or limited?

**Response from** config-expert:

> CheckPositioningLosFN performs a single BSP raycast against the zone map.
> These are computationally cheap — the zone map BSP tree is loaded in memory
> and lookups are O(log n). 30 raycasts per tick is negligible compared to the
> aggro scanning (which does LOS checks for every mob in aggro range). The
> PlotPositionAroundTarget function that BUG-023 replaces already does 4 LOS
> checks per iteration for rogues. No throttling needed. The 6-step iteration
> with 20% minimum distance is a reasonable bound.

**Outcome:** No performance concern. LOS raycasts are cheap. No throttling needed.

---

## Implementation Team Conversations

_Expert-to-expert exchanges during Phase 4._

_To be populated during implementation._

---

## Key Decisions from Conversations

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | No protocol changes needed for any of the five bugs | architect, protocol-agent | 2026-03-12 | All bugs are server-side only |
| 2 | Use direct trigonometry instead of PlotPositionAroundTarget for rogue positioning | architect, config-expert | 2026-03-12 | PlotPositionAroundTarget calculates from rogue's position, not target's |
| 3 | Add Companions:LOMThresholdPct rule with default 15 | architect, config-expert | 2026-03-12 | No existing rule covers LOM announcements; 15% fits between ManaCutoffPct(20%) and 0 |
| 4 | Rewrite buff handler as sequential queue, not use SpellFinished | architect, protocol-agent | 2026-03-12 | SpellFinished bypasses mana/fizzle; sequential queue preserves normal casting |
| 5 | Hardcode backstab offset (model radius + 2 units), no new rule | architect, config-expert | 2026-03-12 | Geometry constant, not game balance tunable |
| 6 | No new rule for caster LOS checking — always active as correctness fix | architect, config-expert | 2026-03-12 | Casters should never intentionally run to blind spots; CasterCombatRange=0 disables the whole system |
| 7 | Add Companions:AlwaysMeditateRegen (BOOL, default true) | architect, config-expert | 2026-03-12 | Explicit fun-over-authenticity decision documented as toggleable rule |
| 8 | BUG-026 LOS iteration (max 6 raycasts) has no performance concern | architect, config-expert | 2026-03-12 | BSP raycasts are O(log n) and cheap; aggro scanning does far more |

---

## Unresolved Threads

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| CastSpell NPC-to-NPC validation | architect, protocol-agent | Flagged for testing | No — SpellFinished is fallback |
