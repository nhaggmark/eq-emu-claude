# Companion Rez — Agent Conversations Log

> **Feature branch:** `bugfix/companion-rez`
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

### 2026-04-27 — Early Lore Consult: Companion Auto-Rez Concept

**From:** game-designer → **To:** lore-master

> Kicked off the design phase for the `companion-rez` bugfix. Surfaced the
> locked invariant verbatim ("When we end a fight and one of my NPC companions
> falls, the Cleric NPC companion should be able to rez the party member.
> This is currently broken.") and the Classic-Luclin era lock. Asked four
> questions: (1) era-compliance for Cleric companions auto-rezzing,
> (2) thematic concerns with NPC companions being rezzable targets,
> (3) flavor messaging on auto-rez, (4) deity-specific edge cases (e.g.,
> should an Erudite Cleric of Quellious refuse to rez a Troll). Flagged my
> position that no deity-based restrictions should apply — UX pain for
> 1-3 player groups, not enforced in Classic mechanics.

**Response from** lore-master:

> APPROVED — Cleric auto-rez is lore-clean. Resurrection is a defining
> Classic-launch Cleric ability — every Cleric regardless of race or deity
> has rez as core class identity. No lore or faction constraint blocks rez
> on fallen party members. NPC companions as rez targets is thematically
> fine.
>
> Era compliance — in-scope Cleric spells: Resurrection (lvl 15),
> Reanimation (lvl 29), Revive (lvl 43), Resuscitate (lvl 53) — all
> Classic; Restoration (lvl 65) — Luclin, within era lock.
>
> **HARD STOP — Shaman rez:** Shamans do NOT receive a resurrection spell
> in Classic-Luclin. Any future expansion of auto-rez to Shaman companions
> must be blocked as an era violation.
>
> **Conditional — Necromancer rez:** in-era but mechanically distinct
> (shard corpse / XP penalty). Out of current scope; if ever added must
> reflect the distinction.
>
> Druid Reincarnation (lvl 52, Classic) and Paladin Revive (lvl 44, Kunark)
> are in-era options if future scope expands. Undead-companion edge case
> is game logic, not lore.
>
> Lore-master requested transcription of these findings into lore-notes.md
> (lore-master lacks Write tool). Will sign off formally after reviewing
> the complete PRD draft.

**Outcome:** Lore-master gave unconditional early approval. Three findings
folded into PRD: (1) corrected Cleric spell list in Era Compliance section,
(2) added Shaman HARD STOP note in Era Compliance + Non-Goals, (3) added
Necromancer / Druid / Paladin notes as future-scope flags in Non-Goals.
Findings transcribed to
`/mnt/d/Dev/eq/claude/project-work/companion-rez/lore-master/lore-notes.md`
on lore-master's behalf. Decisions table in this log updated.

---

### 2026-04-27 — Lore-Master Detailed Answers to Four Questions

**From:** lore-master → **To:** game-designer

> Detailed answers to the original four-question consult:
> (1) Era compliance: APPROVED — all Cleric rez spells are Classic-era.
> (2) NPC companions as rez targets: APPROVED — companion fiction
>     supports raisable NPCs, no lore objection.
> (3) Flavor lines on auto-rez: OPTIONAL / out of scope. Silent is fine.
>     Clerics in EQ don't narrate every spell. Don't require a flavor
>     line for this fix.
> (4) Deity-specific rez refusal: AGREED — NO enforcement. Classic
>     mechanics never gate rez on alignment/deity. Enforcing it would
>     be an invented restriction with zero lore payoff.
>
> Reinforced: Shaman rez is a permanent HARD STOP for any future scope
> (Shamans have no rez in Classic-Luclin). Architect should not assume
> "healers ≈ rezzers."

**Response from** game-designer:

> Acknowledged. Folded the flavor-line answer into Open Question #5
> (now RESOLVED in PRD) and into Out-of-Resources Behavior section
> (removed "or chat message" hedge). Shaman HARD STOP was already
> locked in PRD + Non-Goals + Era Compliance + lore-notes.md from
> the earlier consult. Sending revised PRD for final sign-off.

**Outcome:** Open Question #5 (Cleric OOM flavor) RESOLVED — silent /
no chat output. PRD updated. Sending revised draft for formal final
sign-off.

---

### 2026-04-27 — Full PRD Draft for Sign-Off (FINAL APPROVED)

**From:** game-designer → **To:** lore-master

> Sent full PRD draft for review and sign-off. Called out lore-relevant
> sections: Era Compliance (corrected Classic Cleric progression per
> earlier consult — Resurrection 15 / Reanimation 29 / Revive 43 /
> Resuscitate 53 / Restoration 65); Goals + Player Flow (Cleric does
> what a Cleric does, no deity restrictions); Open Question #5 (silent
> vs. flavor line on Cleric OOM); Open Question #6 (quest-NPC rez edge
> case carried forward as architect-awareness); Scenario E (Cleric down
> → graceful no-op). Held the line on no-deity-restriction.

**Response from** lore-master:

> APPROVED — no lore concerns. PRD is clear to hand off to architecture.
>
> Era compliance: APPROVED. Spell roster within Classic-Luclin lock.
> Goals + Player Flow: APPROVED. "Cleric does what a Cleric does" is
> the right framing.
> NPC companions as rez targets: APPROVED — companion-fiction framing
> is sound.
> No deity-based rez restrictions: CONFIRMED. Hold the line.
> Scenario E (Cleric down): APPROVED. Documenting as graceful expected
> behavior is correct.
> Open Question #5: silent is correct (more in keeping with EQ NPC
> terseness; flavor line can be added in a future polish pass).
> Open Question #6: correct framing — architect-awareness flag, not a
> scope expansion. No lore dimension.
> Shaman HARD STOP: already locked in PRD. No further action needed
> from game-designer unless wanting an explicit note to Non-Goals
> (already there).
>
> **Final verdict: APPROVED. No revisions required. Pass to architecture.**

**Outcome:** PRD is APPROVED. Status header updated to "APPROVED —
lore-master signed off 2026-04-27." Design phase is complete pending
status.md update + commit/push. Ready for handoff to architect.

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

---

### 2026-04-27 — lua-expert initial triage → architect

**From:** lua-expert → **To:** architect

**Summary:** Completed Lua-side triage of the companion-rez space. Zero
existing rez or post-combat Lua logic found anywhere in the companion system.

**Key findings:**
- No `event_combat` handler in global_npc.lua or any companion module
- No post-combat scan, no rez CastSpell(), no corpse-targeting logic in Lua
- `companion_culture.lua:484` has a "resurrection" LLM flavor hook — ready to
  use after a rez succeeds, currently never called
- Buff queue pattern (global_npc.lua:441-600) is the closest analogue to
  what a Lua-based rez trigger would look like
- `is_suspended=1` death-state semantic confirmed present and correct in companion.lua

**Outcome:** Flagged two architecture options (Lua event_combat hook vs C++ primary)
for architect decision. Noted buff queue as reusable pattern if Lua trigger is chosen.

---

### 2026-04-27 — architect → lua-expert (detailed 7-question audit)

**From:** architect → **To:** lua-expert

**Summary:** Architect requested detailed Lua audit to confirm the "Lua-untouched"
hypothesis before finalizing architecture. Seven specific questions asked (see
teammate-message in session).

**Outcome:** See lua-expert detailed response below.

---

### 2026-04-27 — lua-expert detailed audit response → architect

**From:** lua-expert → **To:** architect

**Q1 — Lua-side rez hooks audit (file:line citations):**

- `companion_culture.lua:484` — "resurrection" event_type for LLM flavor. Presentation only. Not a trigger. Nothing currently calls this path.
- No `event_combat` handler: zero results in global_npc.lua, companion.lua, or any companion-related module.
- No `event_death` or `event_death_complete` for companions: only `event_death_zone` (global_npc.lua:656) which tracks zone kills for LLM commentary — no rez logic.
- No `rez`, `resurrect`, `revive`, `cleric`, `auto_rez` matches in any functional companion code.

**Q2 — Global NPC handler scan:**

`global_npc.lua` events: say, trade, spawn, timer, level_up, death_zone. **No `event_combat` handler.** No combat-end logic. No Perl global_npc.pl (FILE NOT FOUND — confirmed).

`CompanionOfNecessity.lua` / 2/3/4.lua: these have `event_death` at line 16 casting spells 32141 / 12948. These are old PEQ boss-mechanic scripts — naming is coincidental, unrelated to companion system. **No conflict risk.**

**Q3 — Companion command audit:**

COMMANDS table (companion.lua:90-113): passive, balanced, aggressive, follow, guard, recall, tome, flee, equipment, equip, unequip, unequipall, equipmentupgrade, equipmentmissing, stats, status, help, hold, target, assist, buffme, buffs, dismiss. **No `!rez` command. No rez path touches anywhere.**

**Q4 — Mod hook surface:**

Searched all quest Lua files for lua_mod/RegisterMod/MeleeMitigation/HealDamage/CommonDamage/IsImmuneToSpell. **Zero active mod hook registrations found.** `global/script_init.lua` — no mod registrations, no encounter loads. No mod can short-circuit a rez cast.

**Q5 — Lua's role in the fix:**

**CONFIRMED: pure C++ fix. Zero Lua changes required for correctness.**

One optional Lua addition available: `companion_culture.lua:484` "resurrection" LLM flavor hook could fire after C++ confirms rez succeeded. This is a polish item, explicitly out of scope per lore-master (PRD Q5 RESOLVED: "silent is correct").

**Q6 — TDD test plumbing:**

`make test-companion` (Makefile:266-273) runs via `docker exec eqemu-server luajit`. Harness pattern from `test_companion_recruitment.lua` stubs full `eq.*` API, Database(), group/client objects. Test files at `akk-stack/server/quests/tests/`. **Suitable for Lua rez tests if any Lua is added.** Since this is pure C++, C++ CLI test runner (Suite 29) is the right harness. No new Lua tests needed for this fix.

**Q7 — `is_suspended=1` lifecycle continuity:**

Confirmed by direct read: companion.lua lines 397, 403, 409-413, 479, 488, 559. Death-state semantic fully intact post-rerecruit-fix. `is_suspended=1` row preserved on death, Lua layer queries it correctly, C++ `Load()+Unsuspend()` path reads it on re-recruitment. C++ rez path can rely on `companion_data` row persisting through death — **confirmed**.

**Final verdict: "Lua-untouched" hypothesis CONFIRMED.** Zero Lua changes needed.

---

### 2026-04-27 — c-expert Triage Report → architect

**From:** c-expert → **To:** architect

**Summary:** Root cause identified and confirmed. Verdicts on all 7 hypotheses.
Full dev-notes at `companion-rez/c-expert/dev-notes.md`.

**ROOT CAUSE: `zone/spells.cpp:2051` — `ST_Corpse` target validation rejects companion corpses.**

The `SpellFinished()` function validates targets before applying any spell effects.
The `ST_Corpse` case requires `IsPlayerCorpse()`. Companion corpses are NPC corpses
(`IsPlayerCorpse() == false`) so the spell is canceled with `CORPSE_NOT_VALID`
before `SpellEffect::Revive` ever fires. All other rez infrastructure is correct
and complete — this single gate is the broken link.

**Hypothesis verdicts (all 7):**

| # | Hypothesis | Verdict | Evidence |
|---|-----------|---------|---------|
| H1 | NPC pipeline rejects corpse targets | CONFIRMED (root cause) | `spells.cpp:2051` — `ST_Corpse` case: `if(!spell_target \|\| !spell_target->IsPlayerCorpse())` → returns false |
| H2 | `SpellType_Resurrect` not assigned to Cleric rez spells | NOT VERIFIABLE WITHOUT DB — loaded from `companion_spell_sets` table, `spell_type` column. Infrastructure to load and use the type is correct (`companion_ai.cpp:288-348`). Whether rows exist in the table is a data-expert question. |
| H3 | `CastRezz()` hit instead of `ResurrectFromCorpse()` | REJECTED — `spell_effects.cpp:1720` correctly branches on `IsCompanionCorpse()` → `ResurrectFromCorpse()`. But this code is UNREACHABLE because `spells.cpp` kills the spell first. |
| H4 | Companion corpse depops before rez can land | REJECTED — `attack.cpp:2911` sets corpse decay to `DeathDespawnS * 1000` (1800s = 30min). The death despawn timer in `companion.cpp:1911` fires on the LIVE ENTITY (not the corpse) and calls `return false` to remove the entity from zone, not the corpse. Two separate objects, aligned timers. |
| H5 | `FindDeadGroupMemberCorpse` doesn't find player corpses | CONFIRMED — `entity.cpp:2052-2069`: `GetCompanionCorpseByOwnerWithinRange()` only returns companion corpses. Player corpse (AC-2) is a missing code path in `FindDeadGroupMemberCorpse()`. |
| H6 | `AnotherCompanionIsRezzing` deadlocks single-cleric | REJECTED — with only one Cleric companion, `comp_list` iteration finds no OTHER companion casting a rez spell. Returns false (no deadlock). `companion_ai.cpp:1884-1906`. |
| H7 | `IsValidSpellTarget` / bodytype / faction filters out corpses | REJECTED — corpse entities have `IsCorpse()==true` which exempts them from many standard mob checks. The only gate that matters is `ST_Corpse` at `spells.cpp:2051`. |

**Fix:** `spells.cpp:2051` — one added OR-condition:
```
Before: if(!spell_target || !spell_target->IsPlayerCorpse())
After:  if(!spell_target || (!spell_target->IsPlayerCorpse() && !spell_target->IsCompanionCorpse()))
```

**AC-2 (player corpse rez):** `FindDeadGroupMemberCorpse()` needs a second scan
for the owner's player corpse via `entity_list.GetCorpseByOwnerWithinRange(owner, this, rez_range)`
(`entity.cpp:2039`). When found, the existing `CastRezz()` path handles it — routes
through world to `OP_RezzRequest` → player dialog (AC-4 preserved).

**TDD:** Suite 29 exists (13 tests). Need new failing tests 29.14 (ST_Corpse companion
rejection), 29.15 (spell_effects.cpp reachability), and a regression test.

**Outcome:** Root cause confirmed. Fix is minimal and surgical. Architecture decision
needed on: (1) implement AC-2 player rez in this pass or defer, (2) multi-target
ordering policy, (3) whether to run Suite 29 tests in current state to establish
baseline before fix.

---

### 2026-04-27 — architect → c-expert (Follow-up dispatch)

**From:** architect → **To:** c-expert

**Summary:** Comprehensive triage requested on all 7 hypotheses with full pipeline trace.

Full message in teammate-message above — asking for: pipeline trace from
`AI_ResurrectDeadGroupMember` to `SpellEffect::Revive`, verdict on H1-H7,
entity_list player corpse scan verification, spell loading path, test run results,
stuck-state analysis, and what changed between scaffolding and user repro.

**Outcome:** See c-expert response above (sent before this dispatch arrived — all
questions answered from concurrent triage).

---

### 2026-04-27 — data-expert Triage Report → architect

**From:** data-expert → **To:** architect

Full DB audit of the companion rez data layer.

**BOTTOM LINE: The data layer is fully set up and correct. The rez bug has zero DB-layer enforcement. It is purely application-layer.**

Key findings:

1. **No pending rez state in DB.** No rez_requests table, no data_buckets entries (only `soul_wipe_6_*` keys present). Rez request/accept is purely in-memory (opcode-based). NPC corpses do not persist in character_corpses. No DB persistence needed.
2. **companion_data death state is correct, no schema change needed.** `is_suspended=1, is_dismissed=0` = rezzable candidate. Five live companions confirmed all currently active.
3. **Rez spells fully populated in companion_spell_sets under spell_type=65536 for class_id=2.** All nine Classic-Luclin Cleric rez spells present (the five PRD spells plus Reconstitution, Reparation, Renewal, Reviviscence). NOT in npc_spells_entries — companion system uses companion_spell_sets exclusively.
4. **Companions:Rez* rule_values ALREADY EXIST** — `RezEnabled=true`, `RezPostCombatDelayS=10` (answers PRD Q1: N=10s), `RezRange=200`, `RezWaiveReagents=true`. These rules are populated but the feature is broken — the C++ that reads them is either stubbed, broken, or not wired to the actual rez flow.
5. **No AI/cast config in DB gates rez.** Lashun Novashine (npc_type_id=2032) has null npcspecialattks and special_abilities. No rule_values block NPC rez receiving.
6. **Spell details for tier-preference (AC-5):** mana 150→300→500→600→700 by tier, cast time 6s uniform, recast 20s (relevant for AC-6 multi-target: 20-second gaps between rezzes), targettype=15 (corpse), XP return 0%→35%→60%→75%→90%.

**Recommended data changes: NONE.** All schema, spell data, and rule_values are complete. Fix is C++ only (and possibly Lua for post-combat trigger).

**Outcome:** Architect and c-expert have full data-layer picture. The c-expert's root cause analysis (spells.cpp ST_Corpse gate) confirms the data layer is clean — the problem is entirely in the C++ validation path, consistent with these findings.

---

### 2026-04-27 — architect → config-expert (Seven-question rule audit)

**From:** architect → **To:** config-expert

**Summary:** Full rule audit requested — complete Companions/Rez rule list
from ruletypes.h, live vs. default comparison, Spells/NPC/Character rez
rules, eqemu_config.json/.env audit, least-invasive bug analysis, tier-preference
rule recommendation, mid-combat-rez rule recommendation.

---

### 2026-04-27 — config-expert → architect (Seven-question response)

**From:** config-expert → **To:** architect

**Verified from:** `ruletypes.h` lines 1250-1254, 1189, 55, 188-190, 253, 522, 794; live `rule_values` DB query; `eqemu_config.json`; `.env`.

**Key findings:**

1. **Complete Rez rule list in ruletypes.h:** Four Companions:Rez* rules at lines 1250-1254 (with `XPDeathPenaltyPct` at 1253 sitting between them — not a rez rule). `Companions:DeathDespawnS` at line 1189 is rez-adjacent. No other Rez/Resurrect rules in the Companions category. Standard rez rules in other categories: `Character:CorpseResTime` (line 55), `Character:UseResurrectionSickness` (line 188), `Character:ResurrectionSicknessSpellID` (line 190), `Mercs:ResurrectRadius` (line 253), `Spells:ResurrectionEffectBlock` (line 522), `Bots:ResurrectionSickness` (line 794).

2. **Live values vs defaults:** All four Rez rules match ruletypes.h defaults exactly. No divergence. `RezEnabled=true`, `RezPostCombatDelayS=10`, `RezRange=200`, `RezWaiveReagents=true`.

3. **Config-only bug verdict:** NO. The bug cannot be explained by a wrong rule value. Config is clean — `RezEnabled=true` and all values correct. Bug is definitively in C++.

4. **RezPostCombatDelayS=10 (AC-1 N):** CONCUR. Keep as-is. No pushback.

5. **Tier-preference rule:** CONCUR with hardcode. Optional polish only.

6. **Mid-combat-rez disallow rule:** CONCUR — keep hard-coded per AC-8. No override rule needed.

7. **AI timer flag:** `Spells:AI_IdleNoSpellMaxRecast=60000` ms — if the rez trigger hooks into the generic NPC idle spell timer, the 10-second `RezPostCombatDelayS` goal could be gated behind a 60-second AI recast window. Rez trigger must run on its own dedicated timer.

**Outcome:** Config is clean. All rules at correct defaults. Bug is in C++. No rule changes needed for this fix.

---

## Implementation Team Conversations

_Expert-to-expert exchanges during Phase 4._

_(Not yet started.)_

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication.
This table is the quick-reference for anyone catching up._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | No deity-based restrictions on Cleric rez targets (e.g., a Cleric of Quellious rezzing a Troll is allowed) | game-designer + lore-master | 2026-04-27 | CONFIRMED by lore-master: not enforced in Classic mechanics; rez is core Cleric identity regardless of race/deity |
| 2 | Default to SILENT Cleric OOM behavior; no flavor chat line unless lore-master requests one | game-designer (proposed) | 2026-04-27 | Avoids chat spam; awaiting lore-master review on full PRD |
| 3 | Shaman rez is a permanent HARD STOP for any future scope expansion | lore-master | 2026-04-27 | Shamans have no rez spell in Classic-Luclin; era violation if added |
| 4 | Necromancer rez flagged as conditional, NOT included in this fix's scope | lore-master | 2026-04-27 | In-era but mechanically distinct (shard corpse / XP penalty); current fix is Cleric-only |
| 5 | Corrected Cleric spell progression in Era Compliance: Resurrection (15) / Reanimation (29) / Revive (43) / Resuscitate (53) / Restoration (65) | lore-master | 2026-04-27 | Replaces game-designer's initial draft list; ensures era accuracy |
| 6 | Cleric OOM behavior is silent — no flavor chat output as part of this fix | lore-master | 2026-04-27 | More in keeping with EQ NPC terseness; polish pass may add a one-time line later |
| 7 | PRD FINAL APPROVED for handoff to architecture | lore-master | 2026-04-27 | No revisions required; era + thematic + design coherence all confirmed |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| Lore-master initial consult (era, NPC rezzability, flavor, deity edge cases) | game-designer ↔ lore-master | RESOLVED 2026-04-27 — APPROVED with Shaman HARD STOP folded into PRD | No |
| Full PRD review for sign-off | game-designer ↔ lore-master | RESOLVED 2026-04-27 — FINAL APPROVED, no revisions required | No |
| Lua audit / "Lua-untouched" hypothesis | architect ↔ lua-expert | RESOLVED 2026-04-27 — CONFIRMED pure C++ fix, zero Lua changes required for correctness | No |


### 2026-04-27 — Architect → c-expert: Triage live rez bug

**From:** architect → **To:** c-expert

> Big-picture finding from triage: the companion auto-rez subsystem appears
> to be SUBSTANTIALLY ALREADY IMPLEMENTED in C++ — `Companion::AI_ResurrectDeadGroupMember()`
> (companion_ai.cpp:1927), `m_rez_delay_timer` post-combat trigger
> (companion.cpp:1944), `SpellEffect::Revive` companion-corpse auto-accept dispatch
> (spell_effects.cpp:1707-1730), `Companion::ResurrectFromCorpse` static entry
> (companion.cpp:3547), `Corpse::SetCompanionData` / `IsCompanionCorpse`
> (corpse.cpp:178, corpse.h:104), companion-corpse marking on death
> (attack.cpp:2905-2912), and a 13-test Suite 29 in cli_companion_tests.cpp.
> Rules `Companions:RezEnabled`, `RezPostCombatDelayS=10`, `RezRange=200`,
> `RezWaiveReagents=true` are wired.
>
> Asked c-expert to validate seven hypotheses (H1–H7) by reading actual code
> and cite file:line for every gate the rez cast traverses from
> `AIDoSpellCast(rez_spell, target_corpse)` to `SpellEffect::Revive`.
> Specific asks: (1) walk the cast pipeline gate-by-gate, (2) verdict per
> hypothesis, (3) verify GetCompanionCorpseByOwnerWithinRange handles player
> corpses or only companion corpses, (4) verify m_companion_spells is populated
> with rez spells flagged SpellType_Resurrect for Cleric, (5) run Suite 29
> tests to see what passes/fails, (6) hunt stuck IsRezzed(true) state,
> (7) explain the gap between the existing scaffolding and the user repro.

**Response from** c-expert: _(awaiting reply)_

**Outcome:** Awaiting c-expert's code-grounded triage report.

---

### 2026-04-27 — Architect → lua-expert: Lua hooks involved in companion auto-rez?

**From:** architect → **To:** lua-expert

> Asked lua-expert to audit Lua side: any post-combat / death / rez hooks
> in companion.lua, global_npc.lua, or commands. Whether mod hooks
> (lua_mod.cpp surface) could short-circuit a rez. Whether this fix
> requires Lua changes at all (current architect hypothesis: pure C++,
> Lua untouched). Whether the Lua TDD harness from companion-rerecruit
> is suitable if Lua tests are needed. Confirmation that the
> companion-rerecruit death-state (is_suspended=1 row preserved) still
> holds. Asked for file:line citations and direct file reads, not memory.

**Response from** lua-expert: _(awaiting reply)_

**Outcome:** Awaiting lua-expert audit.

---

### 2026-04-27 — Architect → protocol-agent: Validate Titanium client packet flow for NPC corpse rez

**From:** architect → **To:** protocol-agent

> Asked protocol-agent to validate Titanium-client constraints for both
> rez paths: (1) NPC corpse path (no client UI; corpse depops, NPC
> respawns, group-update — confirm Titanium-safe), (2) player corpse
> path (NPC caster → OP_RezzRequest → OP_RezzAnswer → worldserver flow,
> rezzer_name handling for NPC entity name), (3) cast-packet pipeline
> for corpse-targeted casts (OP_BeginCast / OP_Action / OP_CastSpell
> Titanium translation), (4) IsRezzed(true) state desync risk on rezzed
> corpse, (5) Bot precedent (bot.cpp:11457 / botspellsai.cpp:204 — rez
> on player corpse works in production; confirm Companion rez uses same
> path), (6) OP_RezzComplete back-channel.

**Response from** protocol-agent: 2026-04-27

> All 6 items validated against live source (titanium.cpp, corpse.cpp,
> worldserver.cpp, spell_effects.cpp, companion.cpp, mob.cpp, botspellsai.cpp).
>
> **Item 1 — NPC corpse path: CONFIRMED SAFE.** OP_DeleteSpawn
> (titanium.cpp:472) — pass-through, Decay=0 for instant vanish. OP_NewSpawn
> (titanium.cpp:1292) → ENCODE(OP_ZoneSpawns) (titanium.cpp:2304) — full
> Spawn_Struct field-by-field translation, NPC=1, fresh entity ID. OP_GroupUpdate
> has no titanium entry → pass-through. New companion gets new entity ID;
> corpse ID already retired from client table after OP_DeleteSpawn. No
> collision, no Titanium crash vector. Titanium does not need any rez-specific
> packet for NPC companion rez — DeleteSpawn + NewSpawn + GroupUpdate is
> correct and complete.
>
> **Item 2 — Player corpse path with NPC caster: CONFIRMED SAFE.**
> worldserver.RezzPlayer() (worldserver.cpp:4286) does not inspect caster
> type — takes only EQApplicationPacket + exp + dbid + opcode. ServerOP_RezzPlayer
> handler (worldserver.cpp:909–940) routes by your_name (player char name),
> no caster lookup anywhere. Functionally identical for NPC or player caster.
> rezzer_name at corpse.cpp:2359 uses caster->GetName() which returns the
> numbered entity name (e.g., Hollish_Tnoops00). GetCleanName() (mob.cpp:5169)
> strips the suffix. Recommend GetCleanName() for cleaner rez dialog display
> — cosmetic only, not a correctness issue. OP_RezzRequest has no titanium_ops.h
> entry → pass-through. Resurrect_Struct (228 bytes, eq_packet_structs.h:2968)
> same on wire as internal. Titanium rez dialog renders regardless of whether
> rezzer is NPC or player.
>
> **Item 3 — Cast pipeline with corpse target: CONFIRMED SAFE.** ENCODE(OP_Action)
> at titanium.cpp:151 — simple field copy, no target-type filtering. OP_BeginCast
> absent from titanium_ops.h → pass-through. DECODE(OP_CastSpell) at
> titanium.cpp:2574 is client→server only. No NPC-casts-on-corpse filtering
> anywhere in titanium.cpp. No Titanium crash vector for this scenario.
>
> **Item 4 — IsRezzed(true) before depop: CONFIRMED SAFE.** corpse->IsRezzed(true)
> (companion.cpp:3587) is server-only in-memory — sends no packet. DepopNPCCorpse()
> (corpse.cpp:767–772) sets m_player_corpse_depop=true; Process() returns
> false next tick → entity removal → OP_DeleteSpawn broadcast. No window
> where half-rezzed state is client-visible. No desync risk.
>
> **Item 5 — Bot precedent: PARTIALLY ALIGNED, divergence is intentional.**
> botspellsai.cpp:203–206 guards IsPlayerCorpse() — bots only rez player
> corpses, never companion corpses. The spell_effects.cpp:1720 companion
> branch is the custom divergence. Both share the same SpellEffect::Revive
> entry point. For the player-corpse subpath, Corpse::CastRezz() is identical
> whether triggered by bot or companion AI — bot precedent is valid for that
> subpath. NPC-casts-on-player-corpse is production-proven via bots.
>
> **Item 6 — OP_RezzComplete back-channel: CONFIRMED SAFE.** Handle_OP_RezzAnswer
> (client_packet.cpp:13666) runs on PLAYER's connection only — no caster
> reference. On accept, fires worldserver.RezzPlayer(outapp, 0, 0, OP_RezzComplete).
> World server handles OP_RezzComplete (worldserver.cpp:942–956) by corpse name
> lookup in zone — no caster lookup, no cross-zone concern. Companion and
> player always in same zone. Clean.
>
> **Summary:** No blocking Titanium constraints on either rez path. All Rezz
> opcodes are pass-through. NPC corpse path (DeleteSpawn+NewSpawn+GroupUpdate)
> is standard and safe. Only cosmetic flag: GetCleanName() vs GetName() for
> rezzer_name at corpse.cpp:2359.

**Outcome:** All 6 items confirmed. No blocking Titanium constraints. One
cosmetic recommendation: use GetCleanName() for rezzer_name at corpse.cpp:2359.

---

### 2026-04-27 — Architect → data-expert: DB audit for companion rez subsystem

**From:** architect → **To:** data-expert

> Asked data-expert to audit: (1) npc_spells_entries — do live Cleric
> NPCs have rez spells with SpellType_Resurrect flag set?
> (2) spells_new — pull rows for the in-era rez spells (Resurrection
> 15, Reanimation 29, Revive 43, Resuscitate 53, Restoration 65) and
> confirm effect_id=Revive, mana, cast_time, targettype, expansion gates;
> (3) companion_data schema sanity check; (4) live state — any
> is_suspended=1 rows, any cur_hp=0 not suspended (which would be a bug);
> (5) live rule_values for all Companions:Rez* and related;
> (6) data_buckets for stuck pending-rez state; (7) confirm companion
> corpses are entity-only (no character_corpses storage); (8) era /
> expansion filtering on rez spells.

**Response from** data-expert: _(awaiting reply)_

**Outcome:** Awaiting data-expert DB audit report.

---

### 2026-04-27 — Architect → config-expert: Companion rez rule audit and least-invasive layer check

**From:** architect → **To:** config-expert

> Asked config-expert for rule audit: full list of Companions:Rez* rules
> in ruletypes.h, live rule_values vs defaults, related rules in Character
> / Spells / NPC categories, eqemu_config.json check, and the critical
> least-invasive question — could the bug be explained by a wrongly-set
> rule alone (RezEnabled=false, RezRange=0, etc.)? If yes, fix is
> config-only. Architect's intent: keep RezPostCombatDelayS=10, hardcode
> tier-preference and multi-target ordering policies (no rule), no rule
> for mid-combat-rez disallow (AC-8 contract). Asked config-expert to
> push back on any of these.

**Response from** config-expert: Sent 2026-04-27. Full audit verified from `ruletypes.h` and live DB.

Key findings:
- Q1: Four Companions:Rez* rules confirmed at lines 1250/1251/1252/1254. `XPDeathPenaltyPct` (line 1253) is co-located but not a rez rule. `DeathDespawnS` (line 1189) is rez-adjacent. No other Rez/Resurrect rules in the Companions category. Full cross-category list provided (Character:CorpseResTime, Character:UseResurrectionSickness, Mercs:ResurrectRadius, Spells:ResurrectionEffectBlock, Bots:ResurrectionSickness*).
- Q2: All rules match ruletypes.h defaults exactly. Zero live/default divergence anywhere in the rez stack.
- Q3: No rule gates rez spells in Spells or NPC categories. `Spells:ResurrectionEffectBlock=2` is buff-slot behavior only, not a rez blocker.
- Q4: eqemu_config.json and .env — confirmed clean, no rez-related entries.
- Q5 (least-invasive verdict): **NO** — wrong rule values would prevent the cast from starting. The user's repro shows the cast initiating and completing, then failing silently at effect application. Config cannot produce "cast goes off but nothing happens." Code changes required.
- Q6: CONCUR — keep `RezPostCombatDelayS=10`, hardcode tier-preference policy. No new rule needed.
- Q7: CONCUR — keep mid-combat-rez disallow hard-coded per AC-8. No override rule.
- Flag: `Spells:AI_IdleNoSpellMaxRecast=60000` ms — rez trigger must run on its own dedicated timer, independent of the NPC idle spell AI loop, or the 10-second delay goal could be gated behind a 60-second AI recast window.

**Outcome:** Config is definitively not the bug. All rules at correct defaults. Code changes required. No rule changes needed for this fix. Tier-preference and mid-combat-rez policies stay hard-coded. AI timer independence is an implementation constraint for c-expert.

