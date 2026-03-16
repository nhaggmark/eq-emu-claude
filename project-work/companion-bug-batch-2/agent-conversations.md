# Companion Bug Batch 2 — Agent Conversations Log

> **Feature branch:** `bugfix/companion-bug-batch-2`
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

_No design team was spawned for this bug-fix batch. Bug reports serve as design input._

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

### 2026-03-15 — BUG-030 Charm Pet Controls: Titanium Client Feasibility

**From:** architect → **To:** protocol-agent

> Consulting on BUG-030 (charm pet controls UX broken on Titanium client).
> Key questions:
> 1. Does OP_Charm correctly activate the pet window on Titanium?
> 2. Does OP_Charm command=0 reliably dismiss the pet UI on Titanium?
> 3. Does Titanium use OP_PetCommands universally for both charmed and summoned pets?
> 4. Is this a known EQEmu issue with Titanium rather than companion-specific?
>
> Server-side code analysis shows charm setup correctly calls SetPet(), sends
> OP_Charm, and pet command handler appears functional for charmed pets (petCharmed
> type passes all petAnimation guards). Charm break sends OP_Charm command=0 and
> clears pet relationship.

**Response from** protocol-agent:

> _(Awaiting response — consultation sent 2026-03-15)_

**Outcome:** Architecture plan includes BUG-030 as an investigation task with
diagnostic logging. If protocol-agent identifies Titanium constraints, the plan
will be updated before implementation begins.

### 2026-03-15 — BUG-029/BUG-031 Configuration Check

**From:** architect → **To:** config-expert

> Checking for existing rules or config that could solve BUG-029 (buffs not
> taking hold) and BUG-031 (gear duplication) without code changes.
>
> BUG-029: Root cause is IsBeneficialAllowed() returning false for Client→Companion.
> Asking about existing rules for beneficial spells on NPCs, AllowBeneficial flag,
> and SpecialAbility::AllowBeneficial.
>
> BUG-031: Root cause is dual event handler firing. Asking about Items:AlwaysReturnHandins
> and trade-related rules.

**Response from** config-expert:

> _(Awaiting response — consultation sent 2026-03-15)_

**Outcome:** Architect independently verified that:
- No existing rule controls beneficial spell targeting for specific NPC types
- AllowBeneficial flag exists and is used for temp pets (npc.cpp:2204) — this is
  the correct pattern for the BUG-029 fix
- Items:AlwaysReturnHandins rule exists (trading.cpp:685) but controls the catch-all
  return path AFTER EVENT_TRADE, which is already bypassed for companions by the
  BUG-018 fix. It doesn't prevent local scripts from returning items.
- No config-only solution exists for either bug; code changes are required.

---

## Implementation Team Conversations

_Expert-to-expert exchanges during Phase 4._

### 2026-03-15 — c-expert: BUG-031 EventNPCGlobal visibility

**From:** c-expert (self-finding during implementation)

> EventNPCGlobal was declared private in quest_parser_collection.h (under the `private:`
> label at line 203). The architect's plan noted this as a potential issue. Resolution:
> moved EventNPCGlobal to public section before `private:` with a default nullptr for
> extra_pointers. This is the cleanest approach — no new wrapper needed.

**Outcome:** quest_parser_collection.h updated. BUG-031 fix compiled and tested successfully.

### 2026-03-15 — c-expert completion notification → team-lead

**From:** c-expert → **To:** team-lead

> All three bugs implemented. BUG-029 fixed (SetAllowBeneficial + group targeting).
> BUG-031 fixed (EventNPCGlobal for companion trades). BUG-030 diagnostic logging added.
> 12 new tests all pass. Zero regressions. Committed and pushed to bugfix/companion-bug-batch-2.

---

## Key Decisions from Conversations

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | Use SetAllowBeneficial(true) pattern for BUG-029 instead of modifying IsBeneficialAllowed() | architect | 2026-03-15 | Matches existing pattern for temp pets (npc.cpp:2204). Simpler and more maintainable than adding companion-specific logic to the complex IsBeneficialAllowed function. |
| 2 | Skip local EVENT_TRADE for companions in FinishTrade() for BUG-031 | architect | 2026-03-15 | All companion trade logic is centralized in global_npc.lua. Local PEQ scripts are unaware of the companion system and cause duplication. |
| 3 | BUG-030 is an investigation task, not a guaranteed fix | architect | 2026-03-15 | Server-side code appears correct. Issue may be Titanium client limitation. Diagnostic logging first, fix only if server-side root cause found. |

---

## Unresolved Threads

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| BUG-030 Titanium charm behavior | architect, protocol-agent | Awaiting protocol-agent response | No — architecture plan accounts for investigation-first approach |
| Config-only alternatives | architect, config-expert | Awaiting config-expert response | No — architect verified independently that code changes are required |
