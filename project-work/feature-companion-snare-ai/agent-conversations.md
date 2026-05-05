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

### 2026-05-04 — Final PRD Review (Post-Addendum)

**From:** lore-master → **To:** game-designer

> Lore-master conducted a final review of the full PRD after the
> Necromancer-naming addendum was committed (`4729182`). Reviewed
> Lore Considerations (PRD lines 237-244), Era Compliance (lines 231-235),
> the Classes Affected table, and the EK Hill Giants example scenario.

**Response from lore-master (final PRD review):**

> APPROVED — Full PRD reviewed. Lore Considerations and Era Compliance
> sections are accurate. All four affected classes correctly
> characterized. Example scenario (EK Hill Giants) is era-appropriate.
> No narrative surface area, no post-Luclin references, no class
> identity concerns. Sign-off complete.
>
> Specific verifications:
> - Lore Considerations: silent-suppression recommendation correctly
>   recorded as confirmed.
> - Era Compliance: all referenced spells are Classic-through-Luclin.
> - Ranger "inherits Druid snare line" is correct to EQ class design.
> - Eastern Karana Hill Giants — correct zone, correct era, correct
>   creature. No lore inconsistency.

**Outcome:** Final lore sign-off on the complete (post-addendum) PRD
recorded. Design phase deliverables are fully reviewed and approved.
Architecture team has a lore-vetted document to work from.

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

### 2026-05-03 — Protocol Sign-Off + Resist Signal Pathway

**From:** protocol-agent → **To:** architect

> Delivered protocol feasibility review and answer to PRD Open Question #5.
>
> Summary of findings:
>
> 1. **Silent suppression is clean.** If the AI gate blocks the cast before
>    `CastSpell()` is called, zero packets are generated — no `OP_BeginCast`,
>    no `OP_Action`, no `OP_ManaChange`. The Titanium client sees nothing.
>
> 2. **No client-pushed AI tick state.** Companion AI ticks are entirely
>    server-internal. No client prediction, nothing to update.
>
> 3. **Q5 answer — resist signal is a pure server-side return value, not a
>    packet.** Path in `eqemu/zone/spells.cpp`: `SpellOnTarget()` calls
>    `ResistSpell()` (lines 4483/4495 — pure server dice roll). On full
>    resist, sends two `MessageString()` chat strings, then
>    `safe_delete(action_packet); return false` (lines 4554–4555). The
>    `false` return value propagates up through `SpellFinished()` →
>    `CastedSpellFinished()`. No packet from the target triggers a resist;
>    the target never "sends" a resist signal. Recommended hook for the
>    resist counter: override or intercept `CastedSpellFinished()` in the
>    Companion class — when `SpellOnTarget()` returns false for a snare-line
>    spell, increment the per-target counter. No existing Bot resist-counter
>    pattern to copy; this needs fresh plumbing.
>
> 4. **No client-prediction coupling.** NPC/companion casts are 100%
>    server-driven.
>
> **APPROVED — No new opcodes, no new packet structs, no Titanium
> translation changes needed.**

**Outcome:** Protocol sign-off delivered. Open Question #5 answered.
Full notes at `/mnt/d/Dev/eq/claude/project-work/feature-companion-snare-ai/protocol-agent/dev-notes.md`.

---

### 2026-05-03 — Namespace Confirmation and Rule Shape (config-expert → architect)

**From:** config-expert → **To:** architect

> Reported findings on Q8 (namespace) and proposed rule shapes:
>
> - **Namespace confirmed: `Companions:*`** — `ruletypes.h` lines 1182–1256 already
>   have ~40 registered rules under this category; live DB has 47 matching rows.
>   Not `Bots:*`, not `AI:*`.
> - **No name collisions** — `SnareHpThreshold` and `SnareResistLimit` are absent
>   from both `ruletypes.h` and the live DB.
> - **Proposed rule shape:**
>   - `RULE_INT(Companions, SnareHpThreshold, 20, ...)` → `RuleI(Companions, SnareHpThreshold)`
>   - `RULE_INT(Companions, SnareResistLimit, 2, ...)` → `RuleI(Companions, SnareResistLimit)`
> - **Open question:** Should `SnareResistLimit = 0` mean "no cap (never give up)"
>   or "never cast snare (always blocked)"? PRD implies 0 = no cap; need architect
>   confirmation for the notes string.
> - **Dependency:** config-expert cannot insert `rule_values` rows until c-expert adds
>   the `RULE_INT` entries to `ruletypes.h` and the server is rebuilt.

**Outcome:** Awaiting architect confirmation before Stage 4.

---

### 2026-05-03 — Full Q1-Q4 Response to Architect (config-expert → architect)

**From:** config-expert → **To:** architect

> Full answers to all four architect questions:
>
> **Q1 (namespace):** `Companions:*` confirmed. `ruletypes.h` lines 1182–1256, ~40 rules,
> 47 live DB rows. No `Bots:*` / `AI:*` / `NPC:*` ambiguity. Grepped for "Snare"/"snare"/"Slow" —
> no collisions. Existing snare rules (`Spells:SnareOverridesSpeedBonuses`, `Bots:PercentChanceToCastSnare`)
> are unrelated.
>
> **Q2 (existing cast-gating rules):** Three existing HP/mana threshold rules gate companion AI casts:
> `HealThresholdPct`, `ManaCutoffPct`, `HealerManaConservePct`. None can be extended — all are
> single-dimension with no flee-state check or per-target resist counter. New rules + new C++ gate
> logic required.
>
> **Q3 (exact definitions):** Provided verbatim `RULE_INT` macro lines and `INSERT INTO rule_values`
> SQL. `SnareResistLimit = 0` documented as "no cap" per PRD intent; flagged to architect for
> confirmation of this semantic.
>
> **Q4 (runtime tunability):** Traced source: `#reloadrules` → `LoadRules()` → `SetRule()` →
> `_FindRule()` which searches compile-time `s_RuleInfo[]`. New rules are **silently ignored** by
> `#reloadrules` until the binary is rebuilt with the new `RULE_INT` entries. After rebuild,
> `#reloadrules` works for runtime tuning — AC-11 will pass.

**Outcome:** Full sign-off delivered. Dependency order documented: c-expert adds macros → rebuild → config-expert inserts DB rows → `#reloadrules` works.

---

### 2026-05-04 — Architect's Initial Pings to Advisors (logged in arrears)

**From:** architect → **To:** protocol-agent

> Sent feature TL;DR. Asserted no protocol implications because the change
> only suppresses some existing OP_CastSpell / OP_Action / OP_Damage flow.
> Asked protocol-agent to confirm or flag any edge case (manual command
> override packet flow, companion-targeting packets, Titanium-specific
> resist messaging).

**Outcome:** protocol-agent had already responded with full sign-off
+ Q5 answer. See entry above (2026-05-03).

---

**From:** architect → **To:** config-expert

> Asked four questions: (Q1) does `Companions:*` namespace exist; (Q2) any
> existing rules already gate companion AI cast behavior we could extend;
> (Q3) draft exact RULE_INT lines and INSERT statements for the two new
> rules; (Q4) confirm `RULE_INT` rules are runtime-changeable for AC-11.

**Outcome:** config-expert had already responded comprehensively.
See entry above (2026-05-03). Architect confirms `SnareResistLimit = 0`
means "no cap" per PRD intent — locked in the architecture doc rule
description and gate code (`if (resist_limit > 0)`).

---

### 2026-05-04 — Architect Resist-Hook Site Decision

**From:** architect → **To:** protocol-agent (response to Q5 answer)

> Acknowledged protocol-agent's recommendation to hook `CastedSpellFinished()`
> in the Companion class. Architect's design choice diverges slightly:
> hook `Mob::SpellOnTarget` instead, inside the existing full-resist branch
> at `spells.cpp:4508-4555`. Reasoning:
>
> 1. **`Mob::SpellOnTarget` is the single source of truth** for "this spell
>    was fully resisted on this target." Works uniformly for single-target,
>    AE, and group spells. `CastedSpellFinished` is broader and would need
>    to differentiate fizzle / interrupt / OOM / resist internally.
>
> 2. **Surgical placement.** The full-resist branch already exists. We add
>    one guarded line: `if (this->IsCompanion()) this->CastToCompanion()->OnSpellResisted(spell_id, spelltar);`.
>    Zero behavioral change for any non-Companion caster (clients, NPCs,
>    bots, mercs). Single comparison overhead per resist.
>
> 3. **Preserves protocol-agent's broader sign-off.** No new packets, no
>    opcodes, no client-visible behavior change. The hook is data-flow
>    only — it does not affect the resist's chat strings, hate add, or
>    `safe_delete(action_packet)`.
>
> protocol-agent's `CastedSpellFinished` recommendation is documented
> as the alternative implementation path. If c-expert hits a complication
> with the `SpellOnTarget` hook (e.g., scope / include challenges),
> falling back to `CastedSpellFinished` is acceptable.

**Outcome:** Architect's choice locked. Documented in architecture.md.

---

### 2026-05-04 — Architect Confirms Sequence with config-expert

**From:** architect → **To:** config-expert

> Confirms config-expert's flagged dependency: the `RULE_INT` macros must
> land in `ruletypes.h` and the server must be rebuilt BEFORE the
> `INSERT INTO rule_values` rows take effect via `#reloadrules`.
> Architecture doc's task list reflects this:
>
> - Task 1: config-expert lands `RULE_INT` definitions in `ruletypes.h`
> - Task 4-11: c-expert lands C++ implementation
> - Task 12: c-expert builds (compilation requires RULE_INT to exist)
> - Task 2: config-expert lands `INSERT INTO rule_values` rows AFTER
>   rebuild + restart
>
> Task 1 and the c-expert C++ work are technically independent at the
> source level (RULE_INT and the C++ implementation can be staged in
> any order, but BOTH must be present before the build succeeds).
> Easiest serialization: config-expert delivers task 1 first, then
> c-expert proceeds with tasks 4-11.
>
> Confirmed `SnareResistLimit = 0` semantics: "no cap, companion will
> attempt snare every eligible tick." Documented in the rule's notes
> string and in the gate code.

**Outcome:** Sequencing locked. Implementation team has clear ordering.

---



### 2026-05-04 — User-Driven Amendment: Re-Verify AI Routing + Retune Threshold

**From:** team-lead → **To:** architect

> Amendment requested. Two items:
>
> 1. Re-verify the architect's claim that "AI_Druid, AI_Necromancer, and
>    AI_Shaman do NOT currently route SpellType_Snare." This contradicts
>    the user's direct observation that opened the feature ("our ranger
>    and druids tend to spam ensnare constantly during battles"). The
>    user has personally seen Druid companions casting Ensnare spam.
>    Trace the actual code path and report findings.
>
> 2. Retune `Companions:SnareHpThreshold` default from 20 to 25 to align
>    with `Combat:FleeHPRatio` (default 25). Eliminates the awkward
>    25%-to-20% window where mob is fleeing but gate denies snare.

**Architect investigation findings:**

> Re-verified by querying live `companion_spell_sets` and `spells_new`:
>
> 1. **AI routing claim confirmed correct in literal sense:** AI_Druid,
>    AI_Necromancer, AI_Shaman have no `SpellType_Snare` branches today.
>
> 2. **BUT the user's "Druid ensnare spam" is NOT snare-line — it's
>    actual Root spells.** AI_Druid HAS a `SpellType_Root` branch
>    (companion_ai.cpp:1235) that fires at 30% throttle, gated only by
>    `!target->IsRooted()`. The Druid root spell set contains spell IDs
>    76 (Engulfing Roots), 77 (Ensnaring Roots), 249 (Grasping Roots),
>    490 (Enveloping Roots), 1608 (Entrapping Roots), 1719 (Engorging
>    Roots). All have effect ID 99 (Root, full immobilize) — they are
>    NOT snare-line. The user is colloquially calling these "ensnare"
>    because the spell names contain "Ensnaring" / "Engulfing" / etc.
>
> 3. **The PRD scoped roots OUT but the user's actual complaint IS
>    about roots.** Shipping the original architecture (gating only
>    SpellType_Snare) would NOT solve the user's reported behavior.
>
> 4. **Data anomaly noted:** Druid companion_spell_sets entries 3192
>    (Earthen Roots) and 3447 (Savage Roots) are tagged `spell_type=128`
>    (Snare) but their actual effect is Root. Functionally benign with
>    a unified gate; data-expert may correct or leave as-is.
>
> **Architecture amendments applied:**
> - Helper renamed `AI_AttemptSnare` → `AI_AttemptMovementControl(target, type_mask)`
> - Helper accepts SpellType_Snare, SpellType_Root, or both as a mask
> - Gates AI_Druid Root branch (line 1235), AI_Ranger Snare branch
>   (line 1469), AI_Bard Snare branch (line 1789) — three sites total
> - Removed plan to add new SpellType_Snare branches to AI_Druid /
>   AI_Necro / AI_Shaman (those classes don't currently spam those types;
>   adding branches expands behavior beyond user complaint)
> - Default `Companions:SnareHpThreshold` retuned 20 → 25 per user
> - Renamed counter members to `m_movement_control_resist_counts` etc.
>
> **Scope decision required from user before implementation:**
> - Option 1 (strict PRD): gate snare-line only. Druid root spam
>   continues. Likely won't satisfy user's complaint.
> - Option 2 (architect recommendation): gate both snare-line AND
>   root-line. Addresses user's actual reported behavior. PRD scope
>   expanded; lore-master sign-off should be re-confirmed for roots.
> - Option 3: ship Option 1 now, file root-spam follow-up bug-fix.
>
> Architecture document is written to support Option 2 by default. If
> user chooses Option 1 or 3, defer Task 4 (Druid Root branch gating)
> and rename the helper back to `AI_AttemptSnare`.

**Outcome:** Amendment applied. User scope decision pending. Architecture
doc, status.md, agent-conversations.md updated and committed.

---



### 2026-05-04 — Comprehensive AI_<Class> Sweep (User-Driven)

**From:** team-lead → **To:** architect

> User picked Option 2 (gate snare AND root) but added: "make sure
> it's applied across all relevant classes." Concerned other casters
> with snare/root behavior might be left out.
>
> Requested exhaustive sweep of `companion_ai.cpp` for every
> `AI_<Class>` handler that contains a `SpellType_Snare` OR
> `SpellType_Root` branch. For each, confirm the new helper should
> be invoked there. Specifically verify Necromancer, Enchanter,
> Shaman, ShadowKnight, Paladin, Beastlord — and any others.

**Architect sweep methodology:**

1. Listed all 16 `AI_<Class>` functions in `companion_ai.cpp`
2. Direct grep: `grep -nE "SpellType_Snare|SpellType_Root" companion_ai.cpp`
   → returns exactly 6 lines (3 if-checks + 3 SelectFirstSpell calls)
3. Cross-referenced against `companion_spell_sets` SQL query for
   classes with `spell_type IN (4, 128)` to see which classes have
   data that's reached vs. dormant
4. Read each handler not in the initial list to confirm no obscure
   path consumes Root/Snare under a different spell-type alias

**Sweep results — definitive:**

Three (and only three) live branches consume Root or Snare today:

| Class | Branch | File:line | Spells in data |
|-------|--------|-----------|----------------|
| Druid | Root | companion_ai.cpp:1235 | 76, 77, 249, 490, 1608, 1719 (the "Engulfing/Ensnaring/Grasping/Enveloping/Entrapping/Engorging Roots" line — all effect ID 99) |
| Ranger | Snare | companion_ai.cpp:1469 | 242, 512 (Snare, Ensnare) |
| Bard | Snare | companion_ai.cpp:1789 | 738, 1758 (Selo's Consonant/Assonant) |

**Every other class verified to have NO active root/snare branch:**

- AI_Tank (WAR): InCombatBuff only
- AI_Paladin (PAL): Heal/Cure/InCombatBuff/Nuke/Resurrect/Buff — no Root/Snare
- AI_ShadowKnight (SHD): Lifetap/InCombatBuff/DOT/Nuke/Pet/Buff — no Root/Snare
- AI_Cleric (CLR): Heal/Cure/InCombatBuff/Resurrect/Buff — no Root/Snare
- AI_Shaman (SHM): Slow/Heal/Cure/DOT/Cannibalize — no Root/Snare
- AI_Rogue (ROG), AI_Monk (MNK): InCombatBuff only
- AI_Beastlord (BST): Pet/Slow/InCombatBuff/DOT/Buff — no Root/Snare
- AI_Wizard (WIZ): Escape/Nuke/WizardBuff — no Root/Snare
- AI_Magician (MAG): Pet/Nuke/Buff — no Root/Snare
- AI_Necromancer (NEC): Pet/DOT/Lifetap/Nuke/Resurrect/Buff — no Root/Snare
- AI_Enchanter (ENC): Mez/Slow/InCombatBuff/Nuke/Buff — no Root/Snare
- AI_Generic (fallback): Heal/Nuke|Lifetap|DOT/Buff — no Root/Snare

**Dormant data flagged.** Many classes have Root/Snare entries
in `companion_spell_sets` but their AI handlers don't consume
them. These are dead data today:

- CLR/PAL/SHM/NEC/WIZ/ENC have Root entries but no AI Root branch
- SHD/NEC have Snare entries but no AI Snare branch (these are
  the Necro Darkness line shared with SHD)
- DRU has Snare entries (242, 512, 1767, 3192, 3447) but no AI
  Snare branch — only the Root branch fires
- RNG has Root entries (76, 249, 490, 3192) but no AI Root branch

Adding new AI branches to consume the dormant entries is **out of
scope** for this feature. Those classes don't currently spam
roots/snares regardless of data. Listed as "AI completeness"
follow-up potential.

**Conclusion:** the user's concern is satisfied — the gate IS
applied across all relevant classes. The "relevant classes" are
defined empirically as "classes whose AI today actually casts
root or snare." That's exactly the Druid Root branch, Ranger
Snare branch, and Bard Snare branch — three sites, all gated
by the amendment.

**Outcome:** Sweep complete. Architecture doc, agent-conversations,
and status.md updated to record the per-class enumeration. Task
count unchanged (10 tasks). The amendment is now defensible
against the user's concern.

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
| 5 | No client-server protocol implications. Silent suppression (not calling CastSpell) generates zero packets. Titanium client sees nothing. | protocol-agent | 2026-05-03 | Confirmed by reading spells.cpp packet construction path. |
| 6 | Resist signal (PRD Q5) is the boolean return value of SpellOnTarget(), not a packet. Pure server-side dice roll. Hook for resist counter: intercept CastedSpellFinished() in Companion class. No existing Bot pattern to copy — needs fresh plumbing. | protocol-agent | 2026-05-03 | Source: eqemu/zone/spells.cpp lines 4483–4555. |
| 7 | Resist hook site = `Mob::SpellOnTarget` full-resist branch (`spells.cpp:4508-4555`), guarded by `IsCompanion()`. protocol-agent's alternative recommendation of `CastedSpellFinished()` is documented as fallback if scope issues arise. | architect (in dialogue with protocol-agent) | 2026-05-04 | `SpellOnTarget` is the single source of truth for "this spell was fully resisted on this target" — uniform across single-target/AE/group. `CastedSpellFinished` is broader and would need to differentiate fizzle / interrupt / OOM / resist. |
| 8 | `Companions:SnareResistLimit = 0` means "no cap, companion will attempt snare every eligible tick." | architect (confirming config-expert's flagged ambiguity) | 2026-05-04 | Matches PRD intent ("set to 0 to disable the resist counter entirely"). Encoded in the gate as `if (resist_limit > 0)`. |
| 9 | Implementation sequence locked: Task 1 (RULE_INT macros) → tasks 4-11 (C++) → task 12 (build) → Task 2 (rule_values seed via INSERT + #reloadrules). Task 3 (data audit) parallel anywhere. | architect + config-expert | 2026-05-04 | config-expert traced source: `#reloadrules` → `_FindRule()` searches compile-time `s_RuleInfo[]`; new rules silently ignored until rebuilt. |
| 10 | (Superseded by amendment 2026-05-04 — see rows 11-13). Original claim: Druid/Necro/Shaman AI handlers don't route SpellType_Snare; adding branches needed. Re-verification revealed this was technically true but irrelevant to the user's actual complaint (which is Druid Root spam, not Snare). | architect | 2026-05-04 | Original claim survives as a footnote; the amendment supersedes the action. |
| 11 | Architecture amendment 2026-05-04: re-verified AI routing. User's "Druid ensnare spam" is actually Druid casting Root-line spells (Ensnaring Roots, Engulfing Roots, etc.) via the AI_Druid SpellType_Root branch — NOT snare-line. The Druid root spells are named "Ensnaring/Engulfing" but have effect ID 99 (Root) not 3 (MovementSpeed). | architect (re-verification per team-lead) | 2026-05-04 | Verified by querying companion_spell_sets and spells_new. AI_Druid has no SpellType_Snare branch; the spam is on the existing Root branch (line 1235). |
| 12 | Scope expansion under architect recommendation: gate BOTH SpellType_Snare AND SpellType_Root through the same shared helper. Helper renamed AI_AttemptSnare → AI_AttemptMovementControl. PRD scope expanded from "snare-line only" to "movement-control (snare + root)". | architect (recommended; user decision pending) | 2026-05-04 | Without this expansion, the user's actual reported behavior (Druid root spam) is unaddressed. Lore-master should re-confirm "silent suppression" reasoning applies equally to roots — same gate semantics. |
| 13 | Companions:SnareHpThreshold default retuned 20 → 25 to align with Combat:FleeHPRatio default 25. | user direction | 2026-05-04 | Eliminates the 25%-to-20% window where mob is fleeing but gate denies. Operators wanting tighter window can lower it. |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| _(none)_ | | | |
