# Companion Snare AI: Combat Restriction — Dev Notes: protocol-agent

> **Feature branch:** `feature/companion-snare-ai`
> **Agent:** protocol-agent
> **Task(s):** Protocol feasibility review / resist-signal pathway analysis
> **Date started:** 2026-05-03
> **Current stage:** Complete

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 1 | Confirm no client-server protocol implications | PRD | Complete |
| 2 | Answer Open Question #5: resist-detection signal pathway | PRD | Complete |

---

## Stage 1: Plan

Read brief.md and PRD. Identified four questions to verify:
1. Does silently not casting a spell have wire-format implications?
2. Does the companion AI tick push any client state we need to update?
3. Resist-detection callback path (PRD Open Question #5)
4. Is the companion auto-cast pipeline coupled to client-side prediction?

---

## Stage 2: Research

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `eqemu/zone/spells.cpp` | 3895–4555 | `SpellOnTarget()` — full resist path, packet construction, return value semantics |
| `eqemu/zone/companion.cpp` | 2271–2350 | `AI_EngagedCastCheck`, `AI_PursueCastCheck`, `AIDoSpellCast` — companion spell dispatch chain |
| `claude/docs/topography/PROTOCOL-CODE.md` | Overview | Packet flow, opcode system, Titanium translation layer |

---

## Key Findings

### Finding 1: No protocol implications — silent suppression is clean

This feature is a **pure server-side gate**. The companion's AI tick decides
whether to call `AIDoSpellCast()` at all. If the gate suppresses the cast,
`CastSpell()` is never called, and therefore:

- No `OP_BeginCast` packet is sent (cast never starts)
- No `OP_Action` packet is sent (spell effect never fires)
- No `OP_ManaChange` packet is triggered by the suppressed cast
- The Titanium client sees nothing. There is no "spell skipped" notification
  path and none is needed.

The decision to suppress is entirely internal to the companion's
`AI_EngagedCastCheck` / `AI_PursueCastCheck` → `AICastSpell` decision tree
(`companion.cpp:2271–2319`). This is the correct insertion point for the
gate, and it has zero wire-format surface area.

### Finding 2: Companion AI tick pushes no spell-related client state

The companion AI tick manages casting through `AI_EngagedCastCheck` and
`AI_PursueCastCheck`. These functions are server-internal; they call
`AICastSpell()` which resolves to `AIDoSpellCast()` → `CastSpell()` when
a spell is selected. There is no client-side prediction or pre-notification
about which spell an NPC is about to cast. The client only sees effects
after `SpellOnTarget()` completes successfully.

### Finding 3: Resist-signal pathway (answers PRD Open Question #5)

The resist signal is **pure server-side state — a return value, not a packet**.

Path through `spells.cpp`:

1. `SpellOnTarget()` is called with the target entity and spell ID
2. `spelltar->ResistSpell(...)` is called (`spells.cpp:4483 / 4495`) and
   returns a `spell_effectiveness` value (0–100)
3. If `spell_effectiveness == 0` (full resist): resist messages are sent via
   `MessageString()` to the caster and target (these are chat log strings, not
   gameplay state packets). The `OP_Action` packet (which was already
   constructed) is deleted without being sent to zone clients — `safe_delete(action_packet); return false;` at `spells.cpp:4554–4555`
4. `SpellOnTarget()` returns `false` to its caller (`SpellFinished()` /
   `CastedSpellFinished()`) signaling the resist

**Key point for the architect:** The resist result is not a callback, not an
event, and not a polled flag. It is the **boolean return value of
`SpellOnTarget()`**, which propagates up through `SpellFinished()` →
`CastedSpellFinished()`. To implement the resist counter, the companion's
implementation needs to intercept this return value in its own
`CastedSpellFinished()` override (or an equivalent hook), check whether the
spell that just failed was a snare-line spell, and if so increment the
per-target counter.

There is no `EVENT_SPELL_RESISTED` callback in the quest/Lua event system
for NPC casters. The Bot system does not implement a resist counter either
— the Bot code at `spells.cpp:4519` only sends a chat message to the owner
when `RuleB(Bots, ShowResistMessagesToOwner)` is true; it does not
accumulate a count.

**The Titanium client is not involved in the resist signal at all.** When an
NPC (companion) casts and resists, the only packets that reach any client are
the `MessageString` chat strings ("TARGET_RESISTED" / "YOU_RESIST"). No
gameplay-state packet travels from the target back to the server to trigger
the resist — `ResistSpell()` is a purely server-side dice roll.

### Finding 4: No client-side prediction coupling

NPC/companion auto-cast is entirely server-driven. The Titanium client has no
knowledge of the companion's spell queue, AI tick, or upcoming casts. There
is no client prediction layer to reconcile.

---

## Stage 3: Socialize

Sent findings to architect via SendMessage. See agent-conversations.md for
the full exchange.

---

## Stage 4: Build

No code changes. This is a review-only task. Protocol sign-off recorded.

---

## Protocol Sign-Off

**APPROVED — No client-server protocol implications for this feature.**

The snare gate lives entirely within the companion AI tick, before
`CastSpell()` is ever called. Silent suppression is correct and complete.

**Specific answers to PRD Open Questions this agent can resolve:**

**Q5: Resist-event hookup.** The resist signal is the boolean return value of
`SpellOnTarget()` (`spells.cpp:4554–4555`). It is not a packet from the
target NPC's combat code. It is a purely server-side computation
(`ResistSpell()` dice roll) whose result propagates up as a return value
through `SpellFinished()` / `CastedSpellFinished()`. To hook a resist counter,
override or intercept `CastedSpellFinished()` in the Companion class, check
if the just-finished spell was a snare-line type, and if `SpellOnTarget`
returned false (resist), increment the counter.

**No new opcodes, no new packet structs, no Titanium translation changes
required for this feature.**
