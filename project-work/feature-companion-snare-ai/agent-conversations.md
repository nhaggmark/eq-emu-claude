# Companion Snare AI: Combat Restriction — Agent Conversations Log

> **Feature branch:** `feature/companion-snare-ai`
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

### 2026-05-03 — Initial Lore Scoping for Companion Snare AI

**From:** game-designer → **To:** lore-master

> Initial scoping ping. Shared the full feature brief verbatim and flagged
> that this is a pure AI-behavior change with no NPC dialogue, no new spells,
> no new factions, no quest content, and no flavor text. Asked four specific
> questions:
> 1. Era compliance — any spell-name divergence across Druid/Ranger/Necro/
>    Shaman snare implementations to be aware of?
> 2. Companion AI flavor — should declining to snare produce flavor text or
>    stay silent? Recommended silent (emote spam during combat would be
>    worse than the current Ensnare spam).
> 3. Race/class identity — any reason a Druid/Ranger/Necro/Shaman companion
>    would be expected to snare relentlessly that I should account for?
> 4. General sign-off — anything else this touches lore-wise?

**Response from** lore-master:

> _(Initially routed via team-lead as APPROVED. Full per-question answers
> followed in the third exchange below.)_

**Outcome:** Lore-master engaged; sign-off received via team-lead;
detailed per-question answers followed.

---

### 2026-05-03 — Final PRD Sign-Off Request

**From:** game-designer → **To:** lore-master

> Sent pointer to the completed PRD draft at
> `/mnt/d/Dev/eq/claude/project-work/feature-companion-snare-ai/game-designer/prd.md`.
> Highlighted the only narrative-adjacent passages in the document:
> 1. "Lore Considerations" subsection — confirms no narrative surface area
>    and recommends silent suppression (no flavor text/emote when the
>    companion declines to snare).
> 2. "Era Compliance" — all referenced snare-line spells are Classic-Luclin;
>    no new spells/IDs/icons.
> 3. Classes affected — Druid, Ranger, Necromancer, Shaman listed without
>    new lore claims.
> Asked for sign-off or any flagged concerns about silent-decline approach,
> race/class identity, era spell-name accuracy, or other narrative impact.

**Response from** lore-master:

> APPROVED — Lore review for Companion Snare AI: Combat Restriction is
> approved with no issues.
>
> - APPROVED: Era compliance — no post-Luclin references, no new spells, no
>   new content.
> - APPROVED: Class identity — Druid, Ranger, Necro, Shaman snare identities
>   are intact. Restricting WHEN the AI casts does not change WHAT the class
>   is. The spells still exist; the companion just waits for the tactically
>   meaningful moment (fleeing, sub-20% HP). This is more authentic to
>   skilled play of those classes, not a contradiction of it.
> - APPROVED: Scripted encounters — no Classic-Luclin quest or scripted
>   encounter depends on companion AI autonomously casting snare. No
>   conflicts.
> - APPROVED: No flavor text, dialogue, emotes, or in-game messaging
>   changes of any kind.

**Outcome:** Lore-master sign-off recorded. Design phase clear to hand off
to architecture. PRD requires no lore-driven revisions.

---

### 2026-05-03 — Detailed Lore Answers (Follow-Up After Sign-Off)

**From:** lore-master → **To:** game-designer

> Per-question answers to the original four questions, sent after the
> consolidated sign-off so they would land in the conversation log directly:
>
> **1. Era compliance / spell names.** All snare-line spells for the four
> affected classes are solidly within era:
> - Druid: Snare (Classic), Ensnare (Classic/Kunark)
> - Ranger: Snare line (Classic) — inherited from Druid
> - Necromancer: Clinging Darkness / Dooming Darkness line (Classic/Kunark)
>   — these are snare-category even though the name doesn't say "snare"
> - Shaman: Drowsy (Classic) and the Spirit Strike / Turgur's line in
>   later tiers
> No lore divergence between these classes on snare identity. The AI gate
> applies cleanly across all four without any class-specific exception
> needed for lore reasons.
>
> **2. Companion AI flavor text when snare is suppressed.** Stay silent.
> This is the right call and it has precedent: EQ's combat system never
> narrates an NPC *choosing not to cast something*. NPCs act or they don't.
> An emote for a non-event would be both un-EQ in tone and actively worse
> UX than the problem you're solving. No lore expectation or precedent
> for narrating AI restraint.
>
> **3. Race/class identity — relentless snaring.** No. In EQ lore, Druids
> and Rangers use snare as a tactical tool for kiting and escape prevention
> — not as a reflexive combat spam. Necromancers use movement slow as part
> of a methodical kill sequence, not carpet-bombing. Shaman snare is
> situational utility. None of these class identities demand constant
> in-combat snaring. The AI change is, if anything, more consistent with
> how these classes are portrayed in lore than the current spam behavior.
>
> **4. General sign-off.** Nothing else touches lore. No factions, no
> named NPCs, no quest flow, no item text, no zone-specific considerations,
> no era concerns. APPROVED — PRD is clear to finalize.

**Outcome:** Per-question lore context recorded for future reference.
The Necromancer-specific spell-name guidance (Clinging Darkness / Dooming
Darkness) is particularly load-bearing for the architect — these spells
don't have "snare" in the name but ARE in the snare category, so any
classification logic that pattern-matches on spell name would silently
miss them. Architect should classify by spell effect/category, not by
name. PRD updated to call this out explicitly in the Classes Affected
section and the technical appendix.

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

_(empty — phase has not started)_

---

## Implementation Team Conversations

_Expert-to-expert exchanges during Phase 4._

_(empty — phase has not started)_

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication.
This table is the quick-reference for anyone catching up._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | Companion declining to snare under the AI rule produces NO flavor text, dialogue, or emote — silent suppression. | game-designer + lore-master | 2026-05-03 | Adding combat-log emote spam would replace one form of spam (snare casts) with another. Lore-master concurred — EQ has no precedent for narrating an NPC choosing not to cast. |
| 2 | Restricting WHEN companions cast snare does not violate Druid/Ranger/Necro/Shaman class identity. | lore-master | 2026-05-03 | Lore portrays these classes as using snare tactically (kiting, methodical kills, situational utility), not as reflexive spam. The AI change is MORE consistent with lore than current behavior, not less. |
| 3 | No Classic-Luclin scripted encounter depends on companion-autonomous snare casting; no conflicts. | lore-master | 2026-05-03 | Confirmed during sign-off. |
| 4 | Necromancer snare-line spells (Clinging Darkness / Dooming Darkness) do NOT have "snare" in the name. Spell classification must be by effect/category, NOT by name pattern. | lore-master → game-designer | 2026-05-03 | A name-based filter would silently miss Necromancer companions, leaving Necro snare spam in place. Reinforces PRD Open Question #3 — architect must use the proper classification path. |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| _(none)_ | | | |
