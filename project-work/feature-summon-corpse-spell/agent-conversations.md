# Universal Summon Corpse Spell — Agent Conversations Log

> **Feature branch:** `feature/summon-corpse-spell`
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

### 2026-05-03 — Universal Summon Corpse: spell name & flavor review (initial)

**From:** game-designer → **To:** lore-master

> Sent feature TL;DR and proposed 12-class spell name table. Asked lore-master to verify era compliance (Classic-Luclin), flag deity-tension issues for Paladin and Cleric (holy classes scribing what reads as a necromantic effect), evaluate framing concerns for Druid ("Return to the Soil" — corpse goes to caster, not the soil), Ranger ("Hunter's Burden"), Bard ("Dirge of Recovery"), Beastlord (Iksar/Vah Shir flavor fit), and Enchanter (does corpse-summoning fit the illusion school?). Offered to either accept lore-master spell flavor strings or write workmanlike ones for lore-master review.

**Response from** lore-master:

> Era compliance APPROVED for all 12 classes. Six BLOCKING name issues raised: Druid "Return to the Soil" is semantically backwards (corpse goes to caster, not the soil); Shaman "Spirit Tether" tone-mismatched (binding implies necromancy, shamans petition); Ranger "Hunter's Burden" tone-mismatched (rangers are wardens, not mournful); Bard "Dirge of Recovery" deflated; Beastlord "Ancestor's Reclaim" grammar issue + tone; Cleric "Hallowed Recall" reads as Paladin-coded. Three non-blocking notes for Paladin, Wizard, Enchanter (all defensible as-is). Provided per-class flavor text strings and a universal in-world framing ("The Compact of the Awakened" — Luclin Nexus-grounded) to explain why all casters can do this without breaking lore. Asked the game-designer to confirm framing choice between Option A (Nexus Compact) and Option B (Divine Compact).

**Outcome:** Game-designer accepted all 6 blocking renames (Cleric→Divine Reclamation, Druid→Nature's Reclamation, Shaman→Ancestral Summons, Beastlord→Ancestral Call, Ranger→Warden's Claim, Bard→Dirge of Homecoming) and kept the three non-blocking originals (Paladin "Solemn Retrieval", Wizard "Spectral Translocation", Enchanter "Phantasmal Reclamation"). Selected Option A (Compact of the Awakened) as the universal framing — defensible across INT-casters who follow no deity, era-grounded in Luclin. PRD updated with the final names table, all 12 lore-master flavor strings, the framing rationale, and class-specific gloss notes for the four hard-fit classes (Paladin, Ranger, Bard, Enchanter). PRD now ready for lore-master final sign-off pass.

---

### 2026-05-03 — Universal Summon Corpse: full PRD final sign-off request

**From:** game-designer → **To:** lore-master

> Sent the full updated PRD (game-designer/prd.md) for the final lore continuity check. PRD incorporates all 6 blocking name changes, all 12 flavor text strings, the Compact of the Awakened universal framing, and the hard-fit class notes lore-master provided. Asked for explicit APPROVED / REVISE response before declaring the design phase complete.

**Response from** lore-master:

> APPROVED — PRD is clear for architecture.

**Outcome:** Design phase formally closed on lore review. PRD status now Approved with explicit lore-master sign-off recorded. Architecture team unblocked. Status.md and lore-notes.md final-sign-off footer updated to reflect the explicit approval. No further design-phase iteration needed.

---

### 2026-05-03 — Universal Summon Corpse: lore-notes.md persistence clarification

**From:** game-designer → **To:** lore-master

> Confirmed that lore-master's review payload was already persisted verbatim to lore-master/lore-notes.md (182 lines, committed in d62b45a) and they did not need to re-send the blob. Redirected them to focus on the PRD sign-off specifically, with line-number pointers (PRD lines 176-185 Compact framing quote, 214-230 hard-fit class notes, 342-358 era compliance ruling) for verification.

**Response from** lore-master:

> APPROVED — PRD is clear for architecture (delivered with the formal sign-off above).

**Outcome:** Re-send-loop avoided. Lore-master confirmed disk-state was correct and proceeded to formal PRD approval.

---

### 2026-05-03 — Universal Summon Corpse: lore-notes.md restructured to template-aligned format

**From:** lore-master → **To:** game-designer

> Sent a restructured lore-notes.md payload following the template sections (Feature Concept, Lore Research, Era Compliance Review, Universal Framing Rationales, PRD Section Reviews, Decisions & Rationale, Recommended Final Name Table, Hard-Fit Class Rationales, Flavor Text, Final Sign-Off, Context for Next Phase). Asked game-designer to write it to disk via heredoc.

**Response from** game-designer:

> Persisted verbatim to lore-master/lore-notes.md (206 lines) and committed in 053bd05. The substantive lore decisions are unchanged from the earlier review (same 6 blocking fixes, same 3 non-blocking originals, same Option A framing, same flavor text strings). The restructure is purely organizational — the new artifact is a much better reference for the architect than the prior verbatim-paste version.

**Outcome:** lore-notes.md upgraded from message-verbatim format to template-aligned structured format. No PRD changes required.

---

### 2026-05-03 — Universal Summon Corpse: final lore sign-off + vendor placement (Open Question 5)

**From:** lore-master → **To:** game-designer

> Final verification of the revised PRD. APPROVED — PRD is cleared for architecture handoff. Confirmed all 6 blocking name changes are correctly integrated, all 3 non-blocking originals are acceptable as-is, Compact of the Awakened framing is era-safe, hard-fit class rationales are present and accurate, era compliance section is clean, acceptance criteria and balance considerations are lore-consistent. Also answered Open Question 5 (vendor placement): use the standard class spell vendor in each starting city for all 12 scrolls; do NOT scatter to guild-specific or faction-gated vendors. Three reasons: (1) universal utility spell, not guild-prestige reward; (2) Classic convention is level-1 spells on standard class spell vendors; (3) faction-gated guild vendors (e.g., Necromancer guild in Neriak/Paineel) would lock the scroll behind faction the level-1 character may not have.

**Response from** game-designer:

> Acknowledged. Updated PRD Open Question 5 to RESOLVED with the lore-master rationale recorded inline. Updated lore-notes.md Final Sign-Off footer (now APPROVED, no longer APPROVED WITH NOTES) and Context for Next Phase (added vendor-placement guidance). Committed and pushed.

**Outcome:** Design phase fully closed with no remaining open questions on the lore side. The architect inherits 6 open questions instead of 7 (vendor placement is now answered). PRD §Open Questions §5 is marked RESOLVED with the lore-master's rationale recorded inline.

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

### 2026-05-03 — Architecture consult: client implications + Bard memming + recast wire format

**From:** architect → **To:** protocol-agent

> Sent the PRD path and three specific Titanium-client questions before locking architecture.md:
> 1. Spellbook capacity / scribe delivery — is there a Titanium spellbook slot cap that the migration must respect, and does an SQL-only INSERT into character_spells render cleanly on next login or does it need a server-side post-login push (OP_NewSpellbook / OP_SpellSlotChange refresh)?
> 2. Bard memming a non-song spell — given the Bard variant has classes8=1 (engine treats as IsBardSong=true) and we set buff_duration=0xFFFF to bypass `bard_song_mode` in `Mob::SpellFinished` (spells.cpp:1474-1477), are there client-side expectations for a Bard with a non-song spell in a gem slot (e.g., recast-timer ack format mismatch, gem-clear behavior)?
> 3. Recast timer wire format — any cap on the recast field for a 3-minute (180000 ms) timer on a level-1 spell that the Titanium client might mis-render?

**Response from** protocol-agent:

> All three clear, no blockers. (1) Titanium `SPELLBOOK_SIZE = 400` (titanium_limits.h:329). SQL INSERT into `character_spells` is sufficient — `LoadCharacterSpellBook` reads all rows at zone-in and `OP_PlayerProfile` delivers the full 400-slot array (titanium.cpp:1392–1408). `OP_NewSpellbook` / `OP_SpellSlotChange` do not exist in the Titanium opcode table; no push needed. (2) `buff_duration=0xFFFF` causes the IsBardSong branch at spells.cpp:1475 to log and fall through without setting `bard_song_mode` — **this bypasses the bard path entirely**, not just the pulsing subpath. The spell takes the identical non-bard post-cast path: `SendSpellBarEnable` (sends `OP_ManaChange`, fully mapped in Titanium at titanium.cpp:1249) + `MemorizeSpell(scribing=3)` with slot translated by `ServerToTitaniumCastingSlot` (titanium.cpp:1268). No Bard-specific client expectation violated; gem clears and re-enables on cooldown normally. (3) `recast_time=180000` is well-established in the sub-9999 range (Taste of Death id=1149, Avatar id=1598, etc.). Server stores as 180s via `pTimerSpellStart`. `OP_LinkedReuse` is unmapped in Titanium so `SetLinkedSpellReuseTimer` sends nothing to the client. Gem-grey countdown driven by client's local spell cache `recast_time`. `uint32` timestamps have no overflow concern at 180s — Lay on Hands runs at 4200000ms (70 min) on Titanium (id=87).

**Outcome:** Architecture assumptions confirmed correct on all three points. `buff_duration=0xFFFF` is the right Bard approach — verified to produce identical wire behavior to all other casting classes. No protocol changes required.

---

### 2026-05-03 — Architecture consult: rule shape + recast override mechanism

**From:** architect → **To:** config-expert

> Sent the PRD path and two specific rule-design questions:
> 1. New rule shape — confirm `RULE_INT(Spells, UniversalSummonCorpseCooldown, 180, "...")` in `eqemu/common/ruletypes.h` under the existing `RULE_CATEGORY(Spells)` block at line 425, plus a `rule_values` row insert. No collision with existing rules confirmed via grep (only `Bots:AllowCommandedSummonCorpse` exists). Anything else in the registration path?
> 2. Rule vs spells_new.recast_time as source of truth — three options: (a) hardcode in the row with no rule, (b) rule consulted at cast time inside `Mob::SpellFinished`, (c) rule applied at startup migration to update the row. Asked which has best operator-UX / hot-tuning tradeoff.

**Response from** config-expert:

> Q1 answer: No generated header beyond `ruletypes.h` needed — `RULE_INT` X-macro is self-contained. Add the line, rebuild, done. `#reloadrules` reloads DB values into already-compiled slots at runtime. Rule shape `RULE_INT(Spells, UniversalSummonCorpseCooldown, 180, "...")` confirmed clean. `rule_values` insert goes in `ruleset_id=1` only (only active ruleset on this server). Critical finding: `EndurTimerIndex` (timer_id) slots 1–19 are all occupied — new spells cannot use linked-timer sharing. Set `timer_id = 0` for all 12.
>
> Q2 answer: Recommend option (b) — dynamic cast-time rule lookup. Rationale: option (a) requires `shared_memory` restart; option (c) is operator-confusing (rule edit must wait for next startup migration to take effect). Option (b) makes `#reloadrules` sufficient — that is the entire point of having a rule. **Hook key:** use `spell_category` or `spell_group` field on the 12 new spells, NOT `SE_SummonCorpse` (which would also match existing high-level Necro/Shaman spells and unintentionally retune them). Final decision deferred to architect + c-expert.

**Outcome:** Architecture revised to use:
> - `RULE_INT(Spells, UniversalSummonCorpseCooldown, 180, "...")` in `ruletypes.h` before `RULE_CATEGORY_END()` at line 549.
> - `rule_values` seed row in `ruleset_id=1`.
> - C++ rule-override at `spells.cpp:2817-2841` keyed on **`spells_new.spell_category`** (data-expert assigns a unique unused value to all 12 new spells; existing NEC/SHM summon-corpse spells retain their stock category and are unaffected).
> - All 12 spells set `timer_id = 0` (linked-timer sharing not used; not needed since each spell is class-restricted).

---


---

### 2026-05-03 — Architect close-out: spell ID blocker accepted, all open questions resolved

**From:** architect → **To:** (team — for the record)

> Architecture doc (`architect/architecture.md`) finalized. Key updates from the protocol/config consultations:
>
> 1. **BLOCKING precondition added (data-expert task 0):** Reclaim 9+ unused sub-9999 spell IDs in `spells_new`. Audit query covers character_spells, all 6 item effect columns, npc_spells_entries, aa_rank_effects, plus a manual quest-script grep. Backup-before-delete is mandatory per work-protection rules. Combined with the 3 known gaps (1348, 5093, 9412), this yields the 12 IDs needed.
> 2. **Bard `buff_duration = 0xFFFF` confirmed as full bypass** (per protocol-agent's follow-up audit). Identical wire behavior to non-Bard casts. The "SendSpellBarEnable skipped" concern was a misread of the recast_time>0 path; the 0xFFFF path bypasses bard_song_mode entirely.
> 3. **`spell_category` is the rule discriminator** (per config-expert's recommendation). Avoids leaking the rule into existing NEC/SHM summon-corpse spells. Cleaner than the original spell-ID range-check I proposed.
> 4. **timer_id = 0 for all 12 new spells.** EndurTimerIndex slots 1-19 are exhausted; not a problem because each spell is class-restricted (no character holds more than one of the 12).
> 5. **Auto-scribe via SQL insert only.** Confirmed protocol-side: `LoadCharacterSpellBook` + `OP_PlayerProfile` deliver on next zone-in. No live push opcode needed.
>
> Implementation team composition: c-expert + data-expert + config-expert + infra-expert. NOT spawning lua-expert, perl-expert, or protocol-agent (no implementation work for them). Game-tester is dispatched separately as a solo agent in the validation phase.
>
> Notifying team-lead next.

**Response from** _(no further response expected; architect proceeds to status.md update + commit + team-lead notification)_

**Outcome:** Architecture phase complete. All 7 PRD open questions resolved (1 by lore-master in design, 6 by architect during architecture phase). One critical precondition (spell ID reclamation) added as data-expert task 0 — this gates implementation start.

---

### 2026-05-03 — Same-day amendment: user challenge on spell-ID reclamation (architecture revised)

**From:** user (via team-lead) → **To:** architect

> User reviewed the architecture summary and challenged the reclamation requirement, verbatim:
>
> > "why does this have to be a lossy operation? these are net new spells for everyone but necromancers and shamans right?"
>
> Team-lead asked architect to (1) re-confirm the SPELL_ID_MAX=9999 hard cap, (2) re-run the audit query against the live DB in dry-run mode to verify the actual count of unused IDs, (3) explore non-lossy alternatives (one shared row across 12 classes, two thematic-grouping rows, modify existing NEC/SHM rows, sparse-class roster, or other), and (4) recommend an option with tradeoffs.

**Response from** architect:

> Re-verified all four points:
>
> 1. **SPELL_ID_MAX = 9999 is a real Titanium hard cap** confirmed at `eqemu/common/patches/titanium_limits.h:328` and via the per-client constants at `sof_limits.h` (15999), `sod_limits.h` (23000), `uf_limits.h` (28000), `rof_limits.h` / `rof2_limits.h` (45000). Cannot be raised without a custom Titanium client patch (out of scope; client binary is closed).
>
> 2. **Live-DB audit: 14 unambiguously usable IDs in [1, 9999], not 3.** Ran `SELECT id FROM spells_new WHERE id BETWEEN 1 AND 9999 ORDER BY id` against the live MariaDB instance, then computed the set-difference against the full [1, 9999] range. Result: 16 unused IDs total — `1, 2, 1348, 5093, 9412, 9413, 9414, 9415, 9416, 9417, 9418, 9419, 9420, 9421, 9422, 9423`. Excluding sentinel-reserved IDs 1 and 2, **14 unambiguously usable**. We need 12. Protocol-agent's "only 3 gaps" was an undercount that missed the contiguous unused block at 9412–9423.
>
> 3. **Non-lossy alternatives evaluated for the record (none needed):**
>    - **(a) 1 shared row across 12 classes:** 1 ID, but loses 12 lore-master-approved class names (single `name[64]` field per row). Rejected — discards substantive design-phase work.
>    - **(b) 2 shared rows (divine + arcane groupings):** 2 IDs, loses 10 of 12 names. Rejected — same reason.
>    - **(c) Modify existing NEC/SHM rows:** 0 new IDs but breaks the existing high-level summon-corpse line (drops level from 35/60 to 1, free, 0-mana). Rejected — violates PRD §AC "no regression on existing NEC/SHM summon-corpse".
>    - **(d) Sparse strategy with reduced class roster:** Contradicts PRD scope.
>    - **(e) IDs > 9999 (Titanium-invisible):** Equivalent to "feature disabled" on this Titanium-only server.
>
> 4. **Final recommendation: adopt the architecture as-is, except delete data-expert task 0** (spell-ID reclamation). Assign the 12 new spells to IDs `1348, 5093, 9412–9421` with `9422` and `9423` as future headroom.

**Response from** user (via team-lead):

> Approved. Execute the amendment immediately: drop task 0, document the chosen IDs explicitly, correct `protocol-agent/dev-notes.md` Q1, log the exchange in `agent-conversations.md`, update `source-spike-findings.md` and `status.md`, commit + push as `arch(summon-corpse): correct spell ID availability (14 free IDs in [1,9999]) — drop reclamation task 0`. Confirm implementation team composition unchanged (c-expert + data-expert + config-expert + infra-expert).

**Outcome:**

- Architecture amended same-day. Five files updated:
  - `architect/architecture.md` — Executive Summary, §Data Model "Spell ID allocation", §Implementation Sequence (renumbered 1-11), §Risk Assessment (dropped reclamation rows), §Review Passes (cleaned), §Required Implementation Agents (data-expert task list updated), §Validation Plan (replaced "reclamation regression check" with ID-uniqueness check).
  - `architect/context/source-spike-findings.md` — §9 Spell ID range section corrected.
  - `protocol-agent/dev-notes.md` — Q1 CORRECTION block prepended; Open Items resolved; Context for Next Agent updated.
  - `status.md` — Current phase note, Handoff Log callout, Implementation Tasks (task 0 dropped), Open Questions, Decision Log #11, Notes — all corrected.
  - `agent-conversations.md` — this entry.
- **Implementation team composition is unchanged:** c-expert + data-expert + config-expert + infra-expert. Same set as before; data-expert just has one fewer task to start.
- **Lesson learned:** "N free IDs in a range" claims must be verified via live-DB set-difference, not estimated from gap-sampling. Sampling can miss contiguous unused blocks at range edges.
- Credit to the user for catching the undercount before any reclamation SQL was authored or executed.

## Implementation Team Conversations

_Expert-to-expert exchanges during Phase 4._

### [Date] — [Topic]

**From:** [agent] → **To:** [agent]

> [Message content or summary]

**Response from** [agent]:

> [Response content or summary]

**Outcome:** _What was decided or changed as a result_

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication.
This table is the quick-reference for anyone catching up._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | Six BLOCKING spell names changed per lore-master review (CLR/DRU/SHM/BST/RNG/BRD) | game-designer, lore-master | 2026-05-03 | Original names had semantic, tonal, or grammatical issues; lore-master proposed direct replacements which game-designer accepted in full |
| 2 | Three non-blocking spell names kept as originally proposed (PAL/WIZ/ENC) | game-designer | 2026-05-03 | Lore-master flagged as defensible; kept to avoid tonal redundancy and preserve flavor wins |
| 3 | Universal in-world framing: Option A — The Compact of the Awakened (Luclin Nexus-grounded) | game-designer (with lore-master recommendation) | 2026-05-03 | Handles INT-caster access without deity gymnastics, era-locked in Luclin (no Planes of Power) |
| 4 | Lore-master flavor text adopted verbatim for all 12 spells | game-designer | 2026-05-03 | Quality of lore-master strings exceeded designer-drafted alternatives |
| 5 | Lore-master's full review payload persisted to lore-master/lore-notes.md verbatim | game-designer | 2026-05-03 | Lore-master lacks Write/Bash tools by design; game-designer wrote the file on their behalf, paste-verbatim per team-lead instruction |
| 6 | Lore-master formal APPROVED sign-off received on full PRD | lore-master | 2026-05-03 | Explicit "PRD is clear for architecture" — no remaining lore concerns; design phase formally closed |
| 7 | Vendor placement: standard class spell vendor in each starting city, all 12 scrolls; no guild-gated placement | lore-master | 2026-05-03 | Universal utility spell, not guild-prestige; Classic convention; avoids faction-gate issue (especially Necromancer in Neriak/Paineel) |
| 8 | New rule `Spells:UniversalSummonCorpseCooldown` — `RULE_INT`, default 180 (seconds), no name collision confirmed | config-expert | 2026-05-03 | Grepped `ruletypes.h` and queried live `rule_values`; only related hit is `Bots:AllowCommandedSummonCorpse` (different category) |
| 9 | `EndurTimerIndex` shared-timer slots 1–19 are all occupied; new spells cannot use linked-timer group | config-expert | 2026-05-03 | Not a blocker — each spell is class-restricted so no character can have more than one of the 12 in their spellbook |
| 10 | Rule is `ruleset_id=1` only; no other rulesets active on this server | config-expert | 2026-05-03 | Queried `rule_sets` and `zone.ruleset`; ruleset 1 is the only assigned ruleset |
| 11 | Preferred cooldown approach: option (b) dynamic rule lookup at cast time (pending architect confirmation) | config-expert recommendation | 2026-05-03 | Makes `#reloadrules` sufficient to tune cooldown; hook key to be decided by architect + c-expert (recommend `spell_category` or `spell_group` field, not `SE_SummonCorpse`) |
| 12 | **BLOCKING:** 12 new spell IDs must be ≤ 9,999 (Titanium `SPELL_ID_MAX`); only 3 gaps available in that range — data-expert must find/reclaim 9+ more IDs | protocol-agent | 2026-05-03 | `titanium.cpp:1394` drops spells > 9999 from wire format; server also blocks `OP_MemorizeSpell` for out-of-range IDs (`client.cpp:3543`) |
| 13 | Auto-scribe via SQL insert into `character_spells` only — no runtime push packet needed; spells appear on next login via `OP_PlayerProfile` | protocol-agent | 2026-05-03 | `LoadCharacterSpellBook` (zonedb.cpp:597) reads all `character_spells` rows into m_pp at every zone-in |
| 14 | `buff_duration=0xFFFF` on the Bard spell bypasses `bard_song_mode` **entirely** (not just the pulsing subpath) — spell takes identical non-bard post-cast path including `SendSpellBarEnable` | protocol-agent (confirmed follow-up) | 2026-05-03 | spells.cpp:1475 `if (buff_duration == 0xFFFF)` logs and falls through without setting bard_song_mode; earlier finding that SendSpellBarEnable was skipped was based on the recast_time>0 path, not the 0xFFFF path |
| 15 | `OP_LinkedReuse` is unmapped in Titanium — cooldown is server-enforced only via `pTimerSpellStart + spell_id`; client gem-grey driven by spell row `recast_time` in local cache | protocol-agent | 2026-05-03 | `titanium_ops.h` has no entry for OP_LinkedReuse; consistent with how other cooldown spells work on Titanium |
| 16 | Spell ID assignment: `1348, 5093, 9412–9421` (12 IDs); `9422, 9423` as headroom — no reclamation; data-expert task 0 dropped | architect (live-DB re-audit after user challenge) | 2026-05-03 | Initial protocol-agent finding flagged "only 3 gaps / reclaim 9+" as a critical precondition. User challenged ("why does this have to be a lossy operation?"). Live-DB set-difference query found 14 unambiguously usable IDs in [1, 9999]. Architecture amended same-day; implementation team composition unchanged. |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| Lore-master final sign-off pass on full PRD | game-designer → lore-master | RESOLVED 2026-05-03 — lore-master replied APPROVED ("PRD is clear for architecture"). No outstanding lore concerns. | No |
