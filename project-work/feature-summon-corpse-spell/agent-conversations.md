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

### 2026-05-03 — Rule plan: UniversalSummonCorpseCooldown (config-expert proactive outreach)

**From:** config-expert → **To:** architect

> Shared completed Stage 1–2 research. Rule shape: `RULE_INT(Spells, UniversalSummonCorpseCooldown, 180, ...)`, no collision with existing rules. Critical finding: all `EndurTimerIndex` slots 1–19 are fully occupied — the 12 new spells cannot use the linked-timer mechanism for a shared cooldown group. Not a blocker because each spell is class-restricted, so a character can only ever have one of the 12 in their spellbook. Raised three open questions: (1) hot-reload path — dynamic cast-time rule lookup vs. baked into spell row; (2) ruleset scope — `ruleset_id=1` only recommended; (3) route the `ruletypes.h` edit to c-expert.

**Response from** architect:

> Two direct questions: (a) confirm `RULE_INT` macro placement and whether any generated header needs updating beyond `ruletypes.h`; (b) request recommendation on option (a) hardcoded row / (b) dynamic cast-time rule / (c) startup migration.

**Outcome:** See next exchange for config-expert's full answers.

---

### 2026-05-03 — Rule registration and hot-reload path decision

**From:** architect → **To:** config-expert

> Confirmed preferred macro syntax. Asked: (1) does anything beyond `ruletypes.h` need updating for rule registration? (2) Which of three options is preferred for the source-of-truth on cooldown: (a) hardcoded `spells_new.recast_time` row, (b) rule read dynamically at cast time, or (c) rule applied to spell row at startup migration?

**Response from** config-expert:

> Q1 answer: No generated header needs updating — the `RULE_INT` X-macro is self-contained. Add the line, rebuild, done. `#reloadrules` reloads DB values into already-compiled slots at runtime. Collision confirmed clean. `rule_values` insert goes in `ruleset_id=1` only (only active ruleset on this server).
>
> Q2 answer: Recommend option (b) — dynamic cast-time rule lookup. Rationale: option (a) requires a `shared_memory` restart to take effect and the operator path is non-obvious; option (c) is worse (operator edits rule but must also watch startup migration reapply it). Option (b) makes `#reloadrules` sufficient — that is the entire point of having a rule. For the C++ hook key, recommend using `spell_category` or `spell_group` field on the 12 new spells rather than `SE_SummonCorpse` (which would also match the existing high-level Necro/Shaman spells). `EndurTimerIndex` cannot be used as a discriminator — all 19 slots taken. Final decision on hook key deferred to architect + c-expert.

**Outcome:** Rule shape confirmed. Option (b) dynamic cast-time lookup recommended. Architect to decide hook key with c-expert. Config-expert remains in Stage 3 (Socialize), holding for architect sign-off before Stage 4 DB insert.

---

### 2026-05-03 — Protocol feasibility assessment: 5 questions answered

**From:** protocol-agent → **To:** architect

> Completed full protocol research on all 5 questions. Full findings in `protocol-agent/dev-notes.md`. Summary:
>
> **Q1 (Spell ID range) — BLOCKING.** Titanium `SPELL_ID_MAX = 9999` (`titanium_limits.h:328`). The wire format silently drops spells > 9,999 (titanium.cpp:1394). The DB currently has only **3 gaps** (IDs 1348, 5093, 9412) in the sub-9,999 range; we need 12 IDs. Data-expert must find/reclaim 9+ more before spell rows can be assigned.
>
> **Q2 (Auto-scribe delivery) — No special opcode.** A SQL insert into `character_spells` is sufficient. Spells appear on next login via `OP_PlayerProfile` (PlayerProfile_Struct.spell_book[] is loaded from DB by `LoadCharacterSpellBook` in zonedb.cpp:597 on every zone-in).
>
> **Q3 (Scroll scribe class-gate) — No Titanium quirks.** Server checks item `classes` bitmask (`RestrictSpellScribing` rule) and spell `classes[GetClass()-1]` level threshold in `OPMemorizeSpell`. Titanium client also pre-filters merchant inventory client-side by `classes` bitmask.
>
> **Q4 (Bard routing) — Advisory, not blocking.** Any spell with Bard class ≠ 255 triggers `IsBardSong()` (spdat.cpp:855). With `recast_time > 0`, `IsPulsingBardSong()` returns false — no song-loop. Spell casts and cooldowns correctly. Minor cosmetic: `SendSpellBarEnable` is not called after a Bard cast (bard_song_mode branch, spells.cpp:1818). Recommend documenting as known quirk; workarounds (is_discipline=1) cause worse problems.
>
> **Q5 (PvP/zone restriction) — Server-side message sufficient.** `OP_LinkedReuse` is unmapped in `titanium_ops.h` — no linked timer push for Titanium. Cooldown is fully server-side via `pTimerSpellStart + spell_id`. Client gem-greying comes from spell's `recast_time` in local spell cache. Cast-and-fail-with-message matches existing Necro Summon Corpse behavior.

**Response from** architect:

> _(pending)_

**Outcome:** Protocol assessment complete. Architect alerted to spell ID blocker and Bard advisory.

---

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
| 14 | Bard's "Dirge of Homecoming" will be classified as a bard song by `IsBardSong()` (any Bard-scribable spell triggers this); no song-loop because recast_time > 0; minor cosmetic quirk: `SendSpellBarEnable` skipped after Bard cast | protocol-agent | 2026-05-03 | `IsBardSong` (spdat.cpp:855) keys on `classes[Bard-1] < 255`; `IsPulsingBardSong` (spdat.cpp:2376) returns false when `recast_time > 0` |
| 15 | `OP_LinkedReuse` is unmapped in Titanium — cooldown is server-enforced only via `pTimerSpellStart + spell_id`; client gem-grey driven by spell row `recast_time` in local cache | protocol-agent | 2026-05-03 | `titanium_ops.h` has no entry for OP_LinkedReuse; consistent with how other cooldown spells work on Titanium |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| Lore-master final sign-off pass on full PRD | game-designer → lore-master | RESOLVED 2026-05-03 — lore-master replied APPROVED ("PRD is clear for architecture"). No outstanding lore concerns. | No |
