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

### 2026-04-27 — architect → data-expert (Round-2 DB audit, 8 specific questions)

**From:** architect → **To:** data-expert

Eight specific questions: (1) npc_spells/npc_spells_entries for Cleric rez spells and SpellType_Resurrect bitmask value; (2) spells_new full row details for 5 rez spells including effectid1/2, effect_base_value1, mana, recast, targettype, goodEffect, expansion flags; (3) companion_data schema confirmation and live counts including zero-HP check; (4) live death-state repro; (5) rule_values for 7 specific companion rez/death rules; (6) data_buckets pending rez state; (7) companion corpse DB representation; (8) expansion gates on rez spells.

---

### 2026-04-27 — data-expert Round-2 Response → architect

**From:** data-expert → **To:** architect

Full artifact at `data-expert/context/db-audit-round2.md`.

**Item 1 — npc_spells/npc_spells_entries:** All Cleric NPCs use `npc_spells_id=1`. Zero rez spells in list 1 (`effectid1=81` query returns 0 rows). Zero rez spell entries across ALL spell lists. This is by design — companion rez runs through `companion_spell_sets` exclusively.

`SpellType_Resurrect = (1<<16) = 65536` confirmed from `common/spdat.h:648`. The DB `companion_spell_sets.spell_type=65536` is an exact match. Full SpellType enum documented in artifact.

`LoadCompanionSpells()` at `companion_ai.cpp:288–308` query verified against live schema — correct column selection, correct WHERE clause.

**Item 2 — spells_new:** 5/5 spells loaded. effectid1=81 (SE_Revive), goodEffect=1, targettype=15 (ST_Corpse). Mana 150→300→500→600→700, recast 20s uniform, cast 6s uniform, XP return 0%→35%→60%→75%→90%. `spells_new` has NO `min_expansion`/`max_expansion` columns on this schema.

**Item 3 — companion_data:** All expected columns confirmed. Live: 5 rows, 0 suspended, 0 dismissed, 0 cur_hp=0. Clean state.

**Item 4:** No dead companions currently. Cannot repro live.

**Item 5 — rule_values:** All 7 rules present and correctly set. `RezEnabled=true` is NOT the bug.

**Item 6 — data_buckets:** Zero rez-related keys.

**Item 7 — companion corpse:** No companion_corpse table. Corpses entity-only, zone memory only.

**Item 8 — expansion gates:** No expansion columns in `spells_new` or `companion_spell_sets`. `npc_spells_entries` has columns but all = -1 (all eras). No expansion gate anywhere in the data layer.

**Flag raised:** `SpellType_Resurrect` is absent from both `SPELL_TYPES_BENEFICIAL` and `SPELL_TYPES_DETRIMENTAL` at `spdat.h:899`. If any dispatch path gates on `SPELL_TYPES_BENEFICIAL`, the rez call would be silently skipped. Architect to verify in companion_ai.cpp dispatch path.

**Overall verdict: data layer fully correct and aligned with C++ pipeline. Fix is C++ only.**

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

### 2026-04-27 — infra-expert → c-expert: Ready for Task 5; waiting on Task 4 completion

**From:** infra-expert → **To:** c-expert

> infra-expert has read the architecture doc and documented the full-stack
> restart plan in `infra-expert/dev-notes.md`. Ready to execute Task 5
> (`make restart` + full server process startup) as soon as Task 4 is complete.
>
> Requested confirmation when ALL of the following are true:
> 1. Suite 29 tests 29.14, 29.15, 29.16, 29.17 PASS
> 2. All 13 existing Suite 29 tests still PASS (no regression)
> 3. eqemu changes committed and pushed to `bugfix/companion-rez`

**Response from** c-expert: 2026-04-27

> Tasks 1-4 complete. Suite 29 new cases 29.14, 29.15, 29.16, 29.17 — ALL PASS post-fix.
> All 13 existing Suite 29 tests — ALL PASS. Full 35-suite companion test suite green,
> zero regressions. eqemu committed and pushed to bugfix/companion-rez:
> - 30f6d6ef5 — TDD red commit (4 failing tests)
> - 83a96f655 — production fix (spells.cpp + companion_ai.cpp)
> Zone binary at /home/eqemu/server/bin/zone is fresh. Clear to execute Task 5.

**Outcome:** infra-expert executed full-stack restart. Results:
- `make restart` — all containers up cleanly
- MariaDB — ready immediately on first ping
- shared_memory — ran to completion (1048 rules, 618 zones, items, spells loaded)
- loginserver — PID confirmed running after 3s
- world — PID confirmed running after 8s
- 8 dynamic zones — count confirmed (ps count = 8, world log shows zone_count [8])
- Binary verified — zone binary dated Apr 28 13:46 (c-expert's build); `strings` confirms new Suite 29 test code compiled in
- Server is healthy and ready for game-tester (Task 6)

---

---

## Architecture Team Conversations — V2

_Atomicity and BUG-028 scoping for the post-v1 rez chain hardening._

---

### 2026-04-27 — architect → data-expert: V2 atomicity and BUG-028 scoping

**From:** architect → **To:** data-expert

Four questions: (Q1) can the rez chain be made atomic — Option A (defer UPDATE), Option B
(MariaDB transaction), or Option C (rez_state column); (Q2) orphaned-row scenarios on
server crash between each step; (Q3) BUG-028 entity-id-0 scope and whether stale
companion pointer at death could corrupt corpse's companion_id; (Q4) cross-zone rez
state persistence (advisory).

---

### 2026-04-27 — data-expert → architect: V2 atomicity findings

**From:** data-expert → **To:** architect

**Q1 — Atomicity:**

DB write sequence confirmed from source (companion.cpp:3547-3700):
1. `corpse->IsRezzed(true)` — in-memory only (line 3587)
2. `CompanionDataRepository::UpdateOne` sets `is_suspended=0` — **DB WRITE** (line 3624)
3. `corpse->DepopNPCCorpse()` — corpse gone, no DB row (line 3630)
4. `new Companion(...)` + `entity_list.AddNPC(new_comp)` (lines 3633–3647)
5. Entity setup (AI_Start, Load, LoadEquipment, CalcBonuses, ScaleStatsToLevel)
6. `new_comp->CompanionJoinClientGroup()` — can fail if group at MAX_GROUP_MEMBERS=6
   (groups.cpp:235); failure path calls `Suspend()` → `Save()` → writes `is_suspended=1` back

`is_suspended=0` is written BEFORE the corpse is deleted and BEFORE the new entity spawns.
Failure at step 6 leaves DB at `is_suspended=1` (technically valid) but the corpse is gone.

**MariaDB transactions (Option B):** All companion tables are InnoDB — transactions
are supported. But a transaction does NOT help here. The DB always ends in a valid state
(`is_suspended=0` success, `is_suspended=1` via Suspend() on failure). The problem is
the in-memory corpse entity is permanently gone after step 3. A ROLLBACK can restore the
DB write but cannot un-DepopNPCCorpse. Transactions are the wrong tool.

**Option A (defer UPDATE):** Correct direction but incomplete. Deferring the UPDATE
until after entity spawn + group join means no DB write if group join fails — the corpse
can be retried. However, this changes the crash-safety guarantee documented at
companion.cpp:3617-3620: if we crash after entity spawn but before the UPDATE, the
companion is in zone with no DB record. That's worse than the current crash window.

**Recommended: Option D + Option C (two-part fix):**
- **Option D (primary):** Pre-flight group-capacity check at the top of
  `ResurrectFromCorpse` or `AI_ResurrectDeadGroupMember` — bail BEFORE any DB write
  or corpse deletion if the group is at MAX_GROUP_MEMBERS=6 with no companion slot to
  free. This closes the most common failure mode (group full) before the chain starts.
- **Option C (defense-in-depth):** Defer `corpse->DepopNPCCorpse()` to AFTER
  `CompanionJoinClientGroup()` returns true. On failure: skip depop (corpse stays),
  roll back the DB write (direct UPDATE sets `is_suspended=1`, subtracts `xp_restore`),
  Depop the new entity. Corpse remains rezzable. This closes all late-failure modes.
  Crash-safety is preserved: if crash happens after UPDATE but before depop, the corpse
  still exists and the next rez attempt sees `is_suspended=0` — correctly treats it as
  "rez was in progress" and can re-run from corpse position.
- One cosmetic flag: if `entity_list.AddNPC(new_comp)` fires before group join, clients
  see the companion flash into existence then vanish on failure. If this is unacceptable,
  defer AddNPC as well.

**No new columns needed.** No schema migration. The Option C rollback is a direct SQL
UPDATE, not a DB transaction.

**Q2 — Crash scenarios:**

- **Crash between step 2 (DB UPDATE) and step 3 (corpse depop):** DB says `is_suspended=0`,
  corpse still in zone (entity memory, lost on restart anyway). On next zone boot, no
  corpse exists (entity-only). Companion appears "alive" in DB with no entity. Player
  `!unsuspend` re-spawns it normally — this is recoverable. No orphaned DB rows.
- **Crash between step 3 (corpse depop) and step 6 (entity add):** DB says `is_suspended=0`,
  no corpse, no entity. Same as above — player `!unsuspend` recovers it. The current
  architecture doc at companion.cpp:3617-3620 explicitly acknowledges this window and
  calls it acceptable given `!unsuspend` as the recovery path. Agreed.
- **Should we add `last_rez_attempt_at`?** No. The extra column doesn't enable a
  materially better recovery path than `!unsuspend`. The only win would be automated
  zone-boot reconciliation, which would need C++ to act on the column anyway — that's a
  future enhancement if the user finds `!unsuspend` too manual. Out of scope for v2.

**No companion_corpses table.** Confirmed — corpses are entity-only (zone memory).
No DB row survives a zone restart for any companion corpse.

**Q3 — BUG-028 entity-id-0 scope:**

BUG-028 is a defensive fallback already in place (companion.cpp:662-701). When
`GetID() == 0` at death time, the code skips the ORM `Save()` path and issues a
direct targeted `UPDATE companion_data SET is_suspended=1 ... WHERE id={companion_id}`.
This guarantees the death state is persisted even if entity state is corrupt.

**Does entity-id-0 corrupt the corpse?** Checking the death-to-corpse path: at
`attack.cpp:2899-2912`, `corpse->SetCompanionData(comp->GetCompanionID(), comp->GetOwnerCharacterID())`
is called using `comp->GetCompanionID()` and `comp->GetOwnerCharacterID()` — both are
plain integer members (`m_companion_id`, `m_owner_char_id`) that do NOT depend on the
entity ID. Entity ID is the zone entity list slot number; `companion_id` is the
`companion_data.id` PK. They are independent. So even if entity ID is 0, the corpse
gets correct `companion_id` and `owner_char_id` values. `IsCompanionCorpse()` checks
`m_companion_id > 0` — unaffected. `ResurrectFromCorpse`'s `companion_data` lookup
uses `companion_id` — unaffected.

**BUG-028 root cause within v2 scope?** No. The root cause (whatever produces entity
id=0 at death) is a separate, pre-existing issue in the entity list / zone spawn
pipeline. It is not caused by the rez chain and fixing it is not required for v2
atomicity. The fallback at companion.cpp:662-701 already contains the damage. BUG-028
should remain in the backlog as a separate investigation rather than being dragged
into v2.

**Q4 — Cross-zone rez state (advisory):**

No cross-zone rez mechanism exists today, and none is needed for v2. When the owner
zones out: `Companion::Zone()` fires, `Save()` persists `is_suspended=1` (if dead) or
current state (if alive), then `Depop()`. On zone-in, `LoadCompanions()` reads all
`is_suspended=1, is_dismissed=0` rows and marks them as dead-awaiting-rez. The
companion AI checks for dead companions only once back in zone. So "pending rez"
is implicitly preserved via the `is_suspended=1` row — no new column or table needed.

The scenario where this breaks: owner zones out mid-rez-cast (after step 2 but before
step 6). Owner zones back in; `is_suspended=0` row found; `LoadCompanions()` spawns
the companion as if alive. That's actually correct behavior — the companion was
successfully rezzed from the DB's perspective, and the entity will spawn at the save
position. If the entity ends up in a broken state (no group, etc.), `!unsuspend` fixes it.

No schema changes recommended for cross-zone rez. The existing `is_suspended` flag is
sufficient.

**Overall DB verdict for v2:** No new columns. No new tables. No schema migration.
No MariaDB transactions. Fix is two-part C++ application logic (Option D + Option C).
BUG-028 stays in backlog, separate from v2.

**Outcome:** Findings sent to architect. Dev-notes updated. Committed and pushed to
`bugfix/companion-rez` (commit 0169943).

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


---

### 2026-04-27 — c-expert → architect: ROOT CAUSE FOUND (spells.cpp:2051)

**From:** c-expert → **To:** architect

> **ROOT CAUSE CONFIRMED:** `eqemu/zone/spells.cpp:2049-2062` — the `case
> ST_Corpse:` branch in `Mob::DetermineSpellTargets()` rejects any rez cast
> whose target is not `IsPlayerCorpse()`. NPC companion corpses fail this
> check, the spell is canceled with `CORPSE_NOT_VALID` BEFORE
> `SpellEffect::Revive` can run.
>
> The downstream pipeline is correct and complete: `SpellEffect::Revive`
> at `spell_effects.cpp:1707-1730` already routes companion corpses to
> `Companion::ResurrectFromCorpse()` (auto-accept, no UI). The
> `AI_ResurrectDeadGroupMember()` AI pipeline is wired into
> `AI_Cleric` idle branch. `Corpse::SetCompanionData()` is called on
> companion death at `attack.cpp:2908`. Suite 29 (13 unit tests) covers
> rules / penalty / corpse metadata / AI gates pre-fix.
>
> **Fix is one logical addition at spells.cpp:2051:**
> `if(!spell_target || (!spell_target->IsPlayerCorpse() && !spell_target->IsCompanionCorpse()))`
>
> Risks reviewed: charm/swarm/merc corpses unaffected (no companion_id),
> mid-combat AC-8 already enforced by idle-only call site, multi-target
> AC-6 works as one-corpse-per-tick.
>
> AC-2 player rez is a SEPARATE, ADDITIVE gap: `FindDeadGroupMemberCorpse`
> only searches companion corpses. Architect to decide whether to wire
> player-corpse search into the same scan or defer.

**Outcome:** Root cause identified with file:line. Architect's plan must
include the `spells.cpp:2051` extension, plus a decision on AC-2 player
rez scope.

---

### 2026-04-27 — lua-expert → architect: NO Lua-side rez logic; pure-C++ fix is appropriate

**From:** lua-expert → **To:** architect

> Audit results:
> - `companion.lua` (~1512 lines): no `event_combat`, no `event_death`,
>   no rez logic, no rez command. The COMMANDS table has 23 commands;
>   none touch rez.
> - `global_npc.lua` (~712 lines): no `event_combat` handler. `event_death_zone`
>   is for LLM-commentary kill-tracking only, not rez.
> - `companion_culture.lua:484-495`: a "resurrection" event_type STUB exists
>   for LLM commentary AFTER a rez succeeds — presentation only, not a trigger.
> - `script_init.lua`: standard module bootstrap, no encounter or mod
>   registrations relevant to rez.
> - The buff queue pattern in `global_npc.lua:441-600` is the closest
>   analogue to what a Lua-side rez queue would look like, but reusing it
>   is unnecessary if C++ already handles trigger + execution.
>
> **Verdict:** Lua-side has zero involvement in this fix. The c-expert
> root cause (`spells.cpp:2051`) is in C++. No Lua changes required.
> The companion-rerecruit `is_suspended=1` death-state semantic still
> holds (verified — no Lua change broke it).
>
> Optional future polish: fire `companion_culture.lua` rez-event LLM
> commentary AFTER a successful rez. Out of scope for this fix.

**Outcome:** Lua-expert confirms the architect hypothesis: pure-C++ fix.
No Lua changes in this bugfix.

---

### 2026-04-27 — protocol-agent → architect: Titanium clean; companion bypass already in place

**From:** protocol-agent → **To:** architect

> Mapped both rez paths end-to-end:
> 1. **Player corpse path** (existing, functional): `Corpse::CastRezz` →
>    `OP_RezzRequest` (228-byte `Resurrect_Struct`) → `worldserver.RezzPlayer` →
>    cross-zone routing → Titanium client dialog → `OP_RezzAnswer` back →
>    `OPRezzAnswer()` applies rez. Titanium translation: NO `E()` or `D()`
>    entry in `titanium_ops.h` — pass-through wire format. Bot precedent
>    works the same way (botspellsai.cpp:204), confirming NPC casters are
>    valid in this flow.
> 2. **Companion corpse path** (server-side direct, no packets):
>    `spell_effects.cpp:1720` → `Companion::ResurrectFromCorpse` →
>    DB UPDATE → corpse depop → new entity spawn at corpse pos → group
>    rejoin. ZERO opcodes touched. `OP_RezzRequest` is NEVER sent.
>
> **Verdict on user hypothesis:** "NPC corpses lack UI to confirm rez" is
> accurate — and the bypass for that exact gap is ALREADY IN PLACE at
> `spell_effects.cpp:1720`. The protocol layer is correct.
>
> **The remaining failure is upstream of `SpellEffect::Revive`** — i.e.,
> in spell_target validation or AI initiation. (This matches c-expert's
> root-cause finding at `spells.cpp:2051` — the spell never reaches
> `SpellEffect::Revive` because `DetermineSpellTargets` cancels it.)
>
> No Titanium-specific concern. No translation-layer changes. No new
> opcodes needed. No client-side modifications.

**Outcome:** Protocol-clean. Bot precedent confirms NPC casters in player
rez flow work in production. Companion bypass already protocol-correct.

---

### 2026-04-27 — data-expert → architect: DB clean; companion_spell_sets has rez tier under spell_type=65536

**From:** data-expert → **To:** architect

> Live DB audit:
> - **No pending-rez state in DB** (`data_buckets`, `character_corpses`).
>   Rez request/accept is in-memory opcode flow, no persistence.
> - **No rez-blocking tables.** `SHOW TABLES LIKE '%rez%'` returns zero.
> - **`companion_data` death state correct.** 5 active companion rows for
>   character "Chelon" (owner_id=6); `is_suspended=0` for all (none dead
>   right now); `is_dismissed=0`; cur_hp populated. No schema change needed.
> - **Rez spells ARE populated in `companion_spell_sets` with
>   `spell_type=65536`** (this is the companion system's custom rez bitmask,
>   distinct from `npc_spells_entries`):
>   - 9 Cleric rez spells in scope, ids 388/391/392/2168/2169/2170/2171/2172/1524
>   - covers Reanimation (lvl 12) through Reviviscence (lvl 56)
>   - PRD's 5 canonical spells all present (ids 392/2168/391/388/2172)
>   - `min_hp_pct=0, max_hp_pct=0` (correct for rez — no HP gate)
>   - The C++ AI uses `companion_spell_sets` (not `npc_spells_entries`).
> - **Companions:Rez* rules already exist in `rule_values`** with sane
>   values: `RezEnabled=true`, `RezPostCombatDelayS=10` (answers AC-1 N=10),
>   `RezRange=200`, `RezWaiveReagents=true`. These were inserted in advance
>   of (or alongside) the C++ scaffold.
> - **PRD's 5 spell rows in `spells_new`:**
>     | id | name | mana | cast_t | recast_t | targettype | effectid1 | xp_return |
>     | 2168 | Reanimation | 150 | 6s | 20s | 15 | 81 | 0% |
>     | 391 | Revive | 300 | 6s | 20s | 15 | 81 | 35% |
>     | 388 | Resuscitate | 500 | 6s | 20s | 15 | 81 | 60% |
>     | 2172 | Restoration | 600 | 6s | 20s | 15 | 81 | 75% |
>     | 392 | Resurrection | 700 | 6s | 20s | 15 | 81 | 90% |
>   - `targettype=15` = corpse-target (this is the `ST_Corpse` enum).
>   - `effectid1=81` = Revive (corresponds to `SpellEffect::Revive`).
>
> **Verdict:** Data layer is complete and clean. Bug is purely
> application-layer (C++). No DB changes needed for the fix.

**Outcome:** Data layer clean. `companion_spell_sets` has all required
rez spells, rules pre-defined. Architect can rely on the data layer as-is.

---

### 2026-04-27 — config-expert → architect: All rules clean; no config-only fix possible

**From:** config-expert → **To:** architect

> Rule audit complete:
> - All 4 `Companions:Rez*` rules exist with sane defaults
>   (`RezEnabled=true`, `RezPostCombatDelayS=10`, `RezRange=200`,
>   `RezWaiveReagents=true`). No misconfiguration.
> - `Companions:DeathDespawnS=1800` (30 min) — corpse persistence is
>   plenty long for the 10-second rez delay window.
> - `NPC:MinorNPCCorpseDecayTime=450000` (7.5 min) — even if the NPC
>   corpse path used these timers (it doesn't, per attack.cpp:2911 which
>   overrides to `Companions:DeathDespawnS`), 7.5 min is plenty.
> - `Spells:AI_IdleBeneficialChance=100` — NPCs have full chance to cast
>   beneficial spells while idle (post-combat). The AI casting pipeline
>   is NOT gating rez.
> - **No rule could explain the bug.** A wrong rule alone cannot produce
>   "cleric attempts rez but nothing happens." The fix is in C++.
>
> **No new rules recommended for this fix.** Architect intent to keep
> `RezPostCombatDelayS=10` (matching DB) is fine. Hardcoding tier-preference
> and multi-target ordering policies is fine — fewer knobs is better,
> consistent with the YAGNI principle.
>
> One observation: `Spells:AI_IdleNoSpellMaxRecast=60000ms` could in
> theory delay rez attempts by up to 60s. Architect should confirm
> whether `AI_ResurrectDeadGroupMember()` runs independently of this
> timer or hooks into it.

**Outcome:** Config clean. Architect's hardcode-the-policies approach is
endorsed. Rules already in place support AC-1 (N=10), AC-3 (rezenabled),
AC-7 (resource gates), and AC-8 (corpse window).

---

## v2 Architecture Team Conversations (companion-rez-architecture-v2)

_Exchanges after in-game validation revealed three deeper bugs in ResurrectFromCorpse._

---

### 2026-04-27 — c-expert → architect: v2 production debug — three deeper bugs

**From:** c-expert → **To:** architect

**Summary:** Code-grounded investigation of three bugs after v1 fix landed in-game.

**Bug v2-1 — `ResurrectFromCorpse` uses `AddNPC` instead of `AddCompanion`** (`companion.cpp:3647`):
- `AddNPC` adds to `npc_list`+`mob_list` but NOT `companion_list`. Rezzed entity invisible to all companion-list queries and AI companion paths.
- Also skips name normalization (`companion.cpp:2403-2404`) — Titanium client can't target the rezzed companion (group window click-resolution fails).
- Also skips immunity strip (`companion.cpp:2432-2440`) — boss-NPCs re-gain invulnerability after rez.
- Fix: route through `Spawn(owner)` instead of manual `AddNPC`+`AI_Start`. Call order: `Load()` → `Spawn(owner)` → `LoadEquipment()` → `CalcBonuses()` → `ScaleStatsToLevel()` → post-rez stats.
- Dependency: v2-2 must be fixed first — `Spawn()` calls `CompanionJoinClientGroup()` → `AddMember()` which fails until group slot is cleared.

**Bug v2-2 — Group slot NOT freed at death** (`groups.cpp:1184,277`, `companion.cpp:713-718`):
- `MemberZoned()` clears `members[i]` (pointer) but NOT `membername[i]` (name string). `GroupCount()` counts name slots, so dead companion still counted.
- `AddMember` fails on rez via capacity check (full group) OR name-collision check (`groups.cpp:277`) for any group size.
- Fix: in `Companion::Death()` after `g->MemberZoned(this)`, iterate `g->membername[]` and null the slot matching `GetCleanName()`. Done in `companion.cpp`, not `groups.cpp`, to avoid breaking cross-zone living-member group tracking.

**Bug v2-3 — Owner zones out while companion is dead** (`companion.cpp:4155`):
- `SpawnCompanionsOnZone()` skips `is_suspended=1`. Dead companion never re-triggered on zone-in.
- If corpse was `IsRezzed(true)` pre-zone-out (partial failure path), corpse is gone; companion stuck at `is_suspended=1` forever with no automatic recovery.
- Fix options: (a) auto-revive at 10% HP on zone-in when no corpse in current zone; (b) announce and let player `!unsuspend`; (c) defer.
- Push-back: v2-3 is outside the existing AC-10 contract; needs game-designer scope decision.

**BUG-028:** Pre-existing `entity id=0` guard (`companion.cpp:669-701`) is working. No further action.

**v2 TDD:** Suite 30 (new), 3 failing-first tests: 30.1 entity in companion_list, 30.2 name normalized, 30.3 group slot freed.

**Dev-notes:** committed at `8a0d689` on `bugfix/companion-rez`.

**Outcome:** Awaiting architect v2 architecture doc and task dispatch.

---

### 2026-04-27 — architect → c-expert: Stage 5 formal citation request (6 questions)

**From:** architect → **To:** c-expert

Six specific questions: (1) R-1 exact file:line for AddNPC, CompanionJoinClientGroup, name normalization, Suspend/Depop failure path, and whether dead companion occupies group slot at rez time; (2) R-2 GetCompanionOwner body, zone-out event hook, cross-zone persistence options; (3) R-3 entity id=0 sequence and whether it corrupts corpse m_companion_id; (4) Fix sites A/B/C with dependency order and subtleties; (5) Any fourth bug candidate; (6) Cross-zone resilience recommendation.

---

### 2026-04-27 — c-expert → architect: Stage 5 response — full citations, DB corruption detail, R-4 candidate

**From:** c-expert → **To:** architect

**Q1 confirmed (R-1):**
- `companion.cpp:3647` — AddNPC (wrong list)
- `companion.cpp:3680` — CompanionJoinClientGroup
- `companion.cpp:2403-2404` — name normalization in Spawn() (skipped)
- `companion.cpp:2693-2711` — existing-group AddMember failure → Suspend() at 2709
- DB corruption confirmed: Suspend()/Save() at line 2470 overwrites the `is_suspended=0` + XP restore written by ResurrectFromCorpse at 3624. XP permanently lost.
- Group slot confirmed occupied: MemberZoned() (`groups.cpp:596-637`) clears pointer only; GroupCount() counts name strings → still counts dead companion. AddMember fails via capacity (groups.cpp:235) OR name-collision (groups.cpp:277-280) for ALL group sizes. DelMember (which does clear name at groups.cpp:720) is never called at death because Depop() is blocked by SetDepop(false) at companion.cpp:627.

**Q2 confirmed (R-2):**
- `companion.cpp:3903-3906` — GetCompanionOwner returns entity_list.GetClientByCharID(m_owner_char_id)
- No zone-out hook in companion system; dead companion sits until DeathDespawnS timer
- Cross-zone fix hook: `companion.cpp:4155` in SpawnCompanionsOnZone(); recommendation: auto-unsuspend at 10% HP on zone-in for is_suspended=1 companions (no schema change needed)

**Q3 confirmed (R-3):**
- entity id=0 does NOT corrupt corpse m_companion_id — separate fields (entity list ID vs m_companion_id plain int)
- attack.cpp:2908 uses GetCompanionID() which reads m_companion_id, not entity ID
- R-3 is not a rez-path blocker; existing BUG-028 fallback sufficient

**Q4 — Fix dependency order: Fix A → Fix B → Fix C:**
- Fix A: `companion.cpp:713-718` — clear membername[] slot at death (companion.cpp only, no groups.cpp change)
- Fix B: `companion.cpp:3632-3680` — route through Spawn(); don't double-call AI_Start()
- Fix C: `companion.cpp:3616-3680` — defer DB UPDATE + DepopNPCCorpse until after Spawn() succeeds; reset IsRezzed(false) on Spawn() failure

**Q5 — R-4 candidate: Dead Cleric self-rez:**
Dead entity stays in mob_list with AI ticking (SetDepop(false)). A dead Cleric could call AI_ResurrectDeadGroupMember() which finds its own corpse. Need guard `if (GetHP() <= 0 || IsDead()) return false` at companion_ai.cpp:1927. Severity: low (Clerics rarely the dead entity when there's another rez-capable companion), but flagged for architect verification.

**Q6 — Cross-zone: recommend auto-unsuspend at 10% HP in SpawnCompanionsOnZone; defer data_buckets Option B to separate pass.**

**Dev-notes Stage 5:** committed at `fc63bc2` on `bugfix/companion-rez`.

**Outcome:** Architect has all citations needed for v2 architecture doc.

---

### 2026-04-27 — architect → c-expert: R-4 verification + v2 plan steel-man request

**From:** architect → **To:** c-expert

Requested: (1) open `companion_ai.cpp:1927-2011` and confirm whether `IsAlive()`/`GetHP()>0` guard exists at top of `AI_ResurrectDeadGroupMember`, (2) confirm whether `Companion::Process()` calls AI ticks on dead companions (SetDepop(false) keeps entity — does Process() still call AI_Process()?), (3) confirm whether `FindDeadGroupMemberCorpse()` finds the dead Cleric's own corpse. Also provided v2 plan (Fixes A/B/C/D + R2 + R4) for steel-man review.

---

### 2026-04-27 — c-expert → architect: R-4 confirmed real + steel-man + fix recommendation

**From:** c-expert → **To:** architect

**R-4 CONFIRMED REAL.** Full trace:
- `AI_ResurrectDeadGroupMember` (`companion_ai.cpp:1935`): no HP/alive guard. First check is `RezEnabled` rule only.
- `Companion::Process()` (`companion.cpp:1893`): HP=0 safety net sets `m_suspended` but does NOT return false. Continues to `NPC::Process()` at line 2227.
- `NPC::Process()` (`npc.cpp:581`): only guards on `p_depop`. Dead companion has `p_depop=false`.
- `Mob::AI_Process()` (`mob_ai.cpp:1412`): idle path `AI_IdleCastCheck()` — no HP gate.
- `Mob::CastSpell()` (`spells.cpp:146`): no `IsDead()` guard in NPC path.
- `FindDeadGroupMemberCorpse()` (`companion_ai.cpp:1882`): YES, finds own corpse by `owner->CharacterID()`.

**Practical:** OOM path prevents actual rez in normal case (dead entity has 0 mana). But mana-at-death edge case (single large hit, HP→0 before mana→0) can leave residual mana → dead Cleric attempts Reanimation on its own corpse → undefined behavior.

**Fix (two lines):** `if (GetHP() <= 0) return false;` at `companion_ai.cpp:1935`; `if (GetHP() <= 0) return NPC::Process();` at `companion.cpp:1908`. Second line prevents ALL AI from firing on dead companions.

**Option D (group cap pre-flight):** confirmed viable. `GetGroupByClient(GetCompanionOwner())` + `GroupCount() >= MAX_GROUP_MEMBERS` check implementable at top of `AI_ResurrectDeadGroupMember`.

**Steel-man push-backs:**
1. Fix order: A → R4 → B → C → R2. R-4 should land before B.
2. Fix C: `IsRezzed(true)` must still be called EARLY (before Spawn) as race guard; reset to false on Spawn() failure. Explicitly document in v2 spec.
3. Test 30.5 (cross-zone): structural no-crash only in unit tests; live validation = game-tester.
4. No other push-back. Plan is sound.

**Dev-notes Stage 6:** `0d667ae` on `bugfix/companion-rez`.

**Outcome:** Architect has complete R-4 picture and steel-man for v2 plan finalization.

---

### 2026-04-27 — architect → c-expert: Final R-4 verification + v2 plan agreement check

**From:** architect → **To:** c-expert

Three specific verification questions: (1) does `AI_ResurrectDeadGroupMember` open with an alive guard, (2) does `Companion::Process()` gate `AI_Process()` on `!IsDead()`, (3) R-4 confirmed real? Also presented the full v2 plan (Fixes A/B/C/D/E + R-3 non-issue) for final sign-off and steel-man.

---

### 2026-04-27 — c-expert → architect: Final R-4 confirmed + Fix C rollback refinement

**From:** c-expert → **To:** architect

**All three questions answered from existing Stage 6 source reads (no re-read needed):**

1. NO — `companion_ai.cpp:1935` opens with `!RuleB(Companions, RezEnabled)` only. No alive guard.
2. NO — `companion.cpp:1893` safety net does NOT return early. Falls through to `NPC::Process()` at 2227. `NPC::Process()` only checks `p_depop`.
3. R-4 CONFIRMED REAL.

**Fix D agreed:** `if (!IsAlive()) return false;` at `companion_ai.cpp:1935`. Independent, one-liner.

**One refinement on Fix C rollback:** If `Spawn()` fails and we need to roll back `is_suspended=0`+XP, do NOT go through `Suspend()/Save()` — it writes the full ORM state from a partially-constructed entity (garbage HP/mana/position). Use a direct targeted SQL UPDATE: `UPDATE companion_data SET is_suspended=1, experience=experience-xp_restore WHERE id=X`. This matches the pattern used by BUG-028 fallback and avoids clobbering clean fields with stale values.

**Option D (group-cap pre-flight) confirmed viable:** `GetGroupByClient(GetCompanionOwner())` + `GroupCount() >= MAX_GROUP_MEMBERS` — add after alive guard, before `AnotherCompanionIsRezzing`.

**No fifth bug identified. Plan is sound. No other push-back.**

**Outcome:** Architect has final sign-off. v2 architecture doc can be written.

---

### 2026-04-27 — architect → c-expert: v2 plan locked, Subtlety 4 added, implementation order confirmed

**From:** architect → **To:** c-expert

v2 architecture locked and pushed at `9a0ae7b` + refinement at `17bd8c9` on `bugfix/companion-rez`. Fix C rollback refinement incorporated as Subtlety 4 (direct SQL UPDATE, not Suspend()/Save(), matches BUG-028 fallback pattern). Implementation order confirmed: V2.1 (failing tests) → V2.2/V2.3/V2.6 (Fixes A, R4, R2 — parallel) → V2.4 (Fix B) → V2.5 (Fix C + Option D) → V2.7-V2.10 (build/verify/restart/validate/commit). Awaiting team-lead/user approval before implementation team spawns.

**Outcome:** c-expert standing by for V2.1–V2.10 task assignments.

---

## V3 Regression Triage — Implementation Team Conversations

_2026-04-28: BUG-002 (visibility heartbeat) and BUG-003 (regen regression) triage_

### 2026-04-28 — c-expert → architect: V3 regression triage complete

**From:** c-expert → **To:** architect

Complete code-grounded triage of BUG-002 and BUG-003. Findings:

**Is Spawn() shared with normal recruit?**
YES. Three call sites: `lua_client.cpp:3666` (first-time recruit), `companion.cpp:4255`
(SpawnCompanionsOnZone zone-in), `companion.cpp:3703` (V2 Fix B: ResurrectFromCorpse).
Spawn() itself was NOT modified by V2. Fix B only added Spawn() as a call site — it replaced
the broken AddNPC sequence. This confirms BUG-002/003 cannot be caused by Fix B affecting
first-time recruit or zone-in companions.

**Prior heartbeat fix SHA:** `9e4b7dfd1` (2026-03-09) — "fix(companions): enable caster spell
casting and prevent client-side vanishing." Added `m_ping_timer` to `Companion`, added the
5-second `SentPositionPacket()` block at what is now `companion.cpp:2128-2142`.
**What V2 changed about it:** NOTHING. Zero mentions of ping_timer, SentPositionPacket, or
position-update code in the V2 diff. Heartbeat code is intact in HEAD.

**BUG-002 root cause (CONFIRMED):**
Fix R4 at `companion.cpp:1933-1935` adds `if (GetHP() <= 0) return NPC::Process()`.
For DEAD companions (HP=0, kept alive by SetDepop(false) in Death()), this short-circuits
the heartbeat block at line 2128. Pre-V2, dead companions ran the full Companion::Process()
body including the ping timer and sent SentPositionPacket() every 5 seconds. Post-V2, dead
companions jump to NPC::Process() which has no SentPositionPacket() call. Titanium client
culls entities without position updates after ~5-10 seconds → "companion vanishes."
The heartbeat for ALIVE companions is completely unchanged and intact.

**Fix for BUG-002:** Least invasive: add `SentPositionPacket(0,0,0,0,0)` in the Fix R4
dead-companion branch, on the existing m_ping_timer cadence. OR move the ping timer block
to before the Fix R4 guard so all companions (alive or dead) get heartbeats.
Risk: zero — only affects the dead-companion code path.

**BUG-003 root cause (INCONCLUSIVE — likely not a V2 regression):**
CalcManaRegen(), tic_timer, and m_mana_report_timer are all unchanged by V2. Rule values
confirmed in DB: AlwaysMeditateRegen=true, CompanionManaRegenMult=100, ManaRegenMultiplier=175.
The "~1%/report" observation is numerically consistent with a rezzed companion starting at
0 mana with a large max_mana pool (e.g. 2000+ mana, 1%=20 mana, 3 tic_timer ticks in 15s × ~7/tick = ~21 mana ≈ 1%). This is expected post-rez behavior, not a regression.
DB shows possible duplicate rows for some rules (NPC:OOCRegen, Character:RestRegenTimeToActivate
appear twice) — recommend data-expert check for duplicate Companions:CompanionManaRegenMult rows.
Recommend game-tester verify BUG-003 with a companion that was NOT recently rezzed. If it
replicates on a fresh session companion, escalate to data-expert.

**Fourth-bug scan results:** Clean except two items:
1. Latent range bug: `entity.cpp:2044` `GetCorpseByOwnerWithinRange` uses `< range` (not `< range²`).
   V1 fix passed `rez_range * rez_range = 40000`. Since the function does `< range` (not `< range²`),
   effective range = sqrt(40000) = 200 units — accidentally correct at RezRange=200. Fragile if
   RezRange rule is changed. Not a V2 regression, pre-existing.
2. Fix A cross-zone group risk: clearing membername[] at death could disrupt world-side cross-zone
   group records for a companion dying at the moment of a zone transition. Low real-world risk
   (companions are zone-local NPCs), but flagging.

**All four triage items documented in dev-notes.md Stage 6 (V3 Regression Triage).**
Commit: `9468488` on bugfix/companion-rez in claude repo.

**Outcome:** BUG-002 has a confirmed fix. BUG-003 needs game-tester verification before code fix.

---

## Architecture Team Conversations — V3 (BUG-002 Visibility Heartbeat)

_Protocol-agent triage of companion visibility regression reported post-V2._

---

### 2026-04-28 — protocol-agent → architect: BUG-002 heartbeat triage complete

**From:** protocol-agent → **To:** architect

**Summary:** Full protocol-level investigation of BUG-002 (companion visibility
heartbeat regression). Findings written to `protocol-agent/dev-notes.md`
(BUG-002 Triage section).

**Key findings:**

1. **Prior heartbeat fix:** Commit `9e4b7dfd1` added `m_ping_timer` (5s interval)
   to `Companion::Process()`. When `!IsMoving()`, fires `SentPositionPacket(0,0,0,0,0)`
   via `entity_list.QueueClients()` every 5s. Titanium client cull window: ~10s.
   Source: `companion.cpp:2128–2142`, `companion.h:522`.

2. **V2 did NOT directly break the heartbeat.** V2's `Fix R4` added
   `if (GetHP() <= 0) return NPC::Process()` at line 1933 — before the ping timer
   at line 2128. For live companions in BALANCED/AGGRESSIVE stance in combat, this
   guard does not fire and the ping timer path is reached normally. V2 made no other
   changes to `Process()` between the HP guard and the ping timer.

3. **Position update dedup (`25826c668`) does not block the heartbeat.** The dedup
   (`m_last_seen_mob_position`) is in `MobMovementManager::SendCommandToClients` and
   `CheckSendBulkNpcPositions`. The heartbeat uses `entity_list.QueueClients()` which
   is a separate direct path — not gated by the dedup.

4. **V2 Spawn() path (Fix B) is protocol-equivalent.** `AddCompanion` adds to both
   `companion_list` and `mob_list`. `MobProcess()` iterates `mob_list` and calls
   `Companion::Process()` via virtual dispatch. Heartbeat fires correctly for
   rezzed companions via this path.

5. **Root cause NOT found via static analysis.** Heartbeat code is present, correctly
   placed, and logically sound. Regression is real but source is unclear from code
   reading alone.

**Key hypothesis for c-expert:**
`NPC::Process()` → `Mob::AI_Process()` may call `RotateTo()` to face-track the target
every tick. `RotateTo()` goes through `MobMovementManager` which sets `moving = true`.
If `moving = true` persists to the top of the next `Companion::Process()` tick, the
ping timer `Disable()` call at line 2134 resets the 5-second window on every combat tick.
If this happens on most ticks, the ping timer never fires — it gets repeatedly disabled
before it can check. The result: heartbeat silently dead in combat.

Files to check: `zone/mob_ai.cpp`, `zone/mob_movement_manager.cpp` (RotateToCommand),
`zone/mob.h:SetMoving()`.

**Recommendation:** c-expert to verify `IsMoving()` state at the top of
`Companion::Process()` for an engaged stationary companion, and whether
`NPC::AI_Process()` sets `moving = true` via rotation.

---

### 2026-04-28 — protocol-agent → c-expert: IsMoving() investigation request

**From:** protocol-agent → **To:** c-expert

**Summary:** Forwarded hypothesis that `NPC::Process()` → `Mob::AI_Process()` →
`RotateTo()` may be setting `moving = true` on combat ticks, continuously resetting
the `m_ping_timer` window before it can fire. If combat AI sets `moving = true` on
most ticks to face-track the target, the ping timer disable at `companion.cpp:2134`
prevents any heartbeat packet from ever sending.

**Suggested fix direction (if hypothesis confirmed):** Either (a) capture `IsMoving()`
state BEFORE calling `NPC::Process()` and use that value for the ping timer check, or
(b) change the ping timer to not be gated on `IsMoving()` when
`m_hold_combat_position = true`.

**Outcome:** Awaiting c-expert investigation.

---

### 2026-04-28 — c-expert → protocol-agent + architect: IsMoving() hypothesis RULED OUT

**From:** c-expert → **To:** protocol-agent, architect

Investigated the RotateTo → IsMoving() hypothesis fully. Here is the verdict:

**RotateToCommand completes in one movement manager tick:**
At `rotate_to_speed=200` (running), `td = 200 * 19 * frame_time ≈ 380` per ~0.1s frame. Max heading diff is 256. Since `td(380) >= dist(≤256)`, `SetMoving(false)` fires in the SAME `RotateToCommand::Process()` call that set it true. No multi-tick `moving=true` state from rotation.

**Main loop ordering:**
1. `entity_list.MobProcess()` — Companion::Process() fires, AI queues RotateToCommand
2. `zone->Process()` → `mMovementManager->Process()` — RotateToCommand runs AND completes in one tick → `SetMoving(false)`

So at the START of the next `Companion::Process()` tick: `IsMoving()=false`. Ping timer fires normally.

**For casters at spell range (the stationary-in-combat scenario):**
Path: `mob_ai.cpp:1360-1364` — `FaceTarget()` called when `!IsMoving()`. If target is stationary, `current_heading == new_heading` at `mob.cpp:4951` → early return, no rotation, no SetMoving. If target moved slightly, rotation fires and completes in one tick → next tick `IsMoving()=false`.

**Conclusion:** The IsMoving() hypothesis does not explain a V2-specific regression. This behavior is identical pre-V2 and post-V2. The ping timer was working correctly before V2 and continues to work correctly for alive companions after V2.

My original BUG-002 root cause stands:

Fix R4 at `companion.cpp:1933-1935` stops the heartbeat for DEAD companion entities (HP=0, kept alive via SetDepop(false)). Pre-V2 they ran full Process() body including the ping timer. Post-V2 they early-return to NPC::Process() which has no SentPositionPacket call.

The protocol-agent's position update dedup finding (commit 25826c668) is also not the cause — the heartbeat uses `entity_list.QueueClients()` which bypasses that dedup path.

**Outcome:** IsMoving() hypothesis ruled out. BUG-002 root cause confirmed as Fix R4 dead-companion heartbeat regression. Fixes committed to dev-notes.md.


---

## Architecture Team Conversations — V3 (Architect-side log)

_2026-04-28: Architect's V3 dispatch and synthesis_

---

### 2026-04-28 — architect → c-expert: V3 regression investigation kickoff

**From:** architect → **To:** c-expert

**Summary:** Dispatched 7 specific investigation tasks for V3:
1. Read `Companion::Process()` end-to-end; describe what runs before/after the V2 Fix R4 guard
2. Trace regen tick path (CalcHPRegen, CalcManaRegen, tic_timer cadence)
3. Find the prior heartbeat fix in git history; verify intact post-V2
4. Trace `Mob::SendPosUpdate` and visibility paths
5. Confirm whether `Spawn()` is shared with normal recruit / zone-in / rez
6. Check if any V2 fix inadvertently disabled a timer/callback
7. Find the gsay reporting mechanism

**Outcome:** Full triage delivered — see `c-expert/dev-notes.md` Stage 6
(V3 Regression Triage). Root cause for BUG-002 confirmed: V2 Fix R4 at
`companion.cpp:1933-1935` short-circuits the prior heartbeat at `companion.cpp:2128-2142`
for HP=0 entities. Pre-V2, dead companions ran the full Process() body; post-V2 they
return early via `NPC::Process()` which has no `SentPositionPacket()` call. BUG-003
likely not a V2 regression — math consistent with freshly-rezzed companion at 0 mana.

**Filed:** Two latent bugs flagged for future scope — `entity.cpp:2044` range fragility
and Fix A cross-zone group risk.

---

### 2026-04-28 — architect → protocol-agent: V3 BUG-002 packet trace

**From:** architect → **To:** protocol-agent

**Summary:** Dispatched 8 specific protocol-side investigation tasks for BUG-002:
heartbeat opcode, client cull window, AddCompanion vs AddNPC differences, dont_queue
parameter semantics, position update emission paths, packet capture suggestions.

**Outcome:** Full triage delivered — see `protocol-agent/dev-notes.md` (BUG-002 Triage).
Heartbeat mechanism confirmed intact in code (`m_ping_timer` at `companion.cpp:2128`,
`Mob::SentPositionPacket` emits `OP_ClientUpdate` via `entity_list.QueueClients`,
Titanium cull ~10s, 5s heartbeat = 2× margin). Position update dedup at `25826c668`
does NOT block the heartbeat (heartbeat bypasses `MobMovementManager` dedup via
direct QueueClients call). Spawn path is protocol-equivalent for entity visibility.

**Open hypothesis:** `NPC::AI_Process()` may set `moving=true` on combat ticks via
face-tracking rotation, which would Disable the ping timer and prevent heartbeats.
Not confirmed via static analysis but defensive.

**V3 plan addresses both:** (1) the confirmed dead-entity heartbeat skip via Fix V
Option A restructure, and (2) the open hypothesis defensively via the
`m_hold_combat_position` bypass at the heartbeat block.

---

### 2026-04-28 — architect → lua-expert: V3 BUG-003 reporting cadence

**From:** architect → **To:** lua-expert

**Summary:** Dispatched 7 Lua-side investigation tasks for BUG-003:
find gsay-mana-report mechanism, verify V2 didn't change cadence, sanity-check Fix R4
guard reach for alive companions, recommend empirical differentiation tests, list
adjacent functionality that depends on the same mechanism.

**Outcome:** Full triage delivered — see `lua-expert/dev-notes.md` (BUG-003 Lua-Side Triage
+ Deep Dive Architect Follow-Up). Reporting is **entirely C++** (`m_mana_report_timer(15000)`
in `companion.cpp:57`, fires inside `Companion::Process()` lines 2028-2034 / 2162-2168).
No Lua hooks. V2 made no change to `Sit()`, `Stand()`, the report timer, or `CalcManaRegen()`.
Empirical math: level 54 cleric, meditate=295 → `final_regen=36/tick` (live diagnostic logs).
"1%/report at 15s" is consistent with freshly-rezzed companion at 0 mana climbing toward
a 1800-mana pool — first few reports show 4-6% increments which feel slow. **Hypothesis
ranking: most-likely cause is post-rez climb-from-zero misperception; least-likely cause
is actual regen rate regression (no V2 code change touches CalcManaRegen).**

**V3 plan response:** BUG-003 deferred to game-tester empirical verification (V3-5 + V3-6
sustained-sit baselines). No code change in V3 unless verification confirms regression.

---

### 2026-04-28 — architect: V3 synthesis and Fix V design

**From:** architect (decision log)

After receiving all three advisor triages plus c-expert's complete v3 dev-notes Stage 6,
the architect synthesized:

**Confirmed root cause for BUG-002:** V2 Fix R4 at `companion.cpp:1933-1935` blanket
early-return for HP=0 entities skips the heartbeat block at line 2128 (and the
death-despawn timer block at line 1938). Pre-V2 baseline: `Companion::Death()` calls
`SetDepop(false)` to keep the dead entity in the world for the rez window; pre-V2
`Companion::Process()` ran the full body for HP=0 entities (no top-level guard); the
heartbeat fired every 5s and Titanium kept rendering the body. Post-V2, dead entities
skip the heartbeat → Titanium culls after 5-10s → user perceives "companion vanished
mid-combat." Secondary contract break: the despawn timer also never fires for HP=0
entities, so 30-min auto-dismiss is broken (entity leaks until rez or zone restart).

**Fix V Option A (RECOMMENDED):** restructure `Companion::Process()` top-section.
Capture `bool is_dead = (GetHP() <= 0);` instead of early-returning. Wrap AI-dispatch-only
sections in `if (!is_dead)`. Leave heartbeat, despawn timer, sitting regen, mana report,
and fleeing-immunity sync unguarded — they already gate on alive-only conditions in
practice. Defensive layer at the heartbeat block: bypass `IsMoving()` when
`m_hold_combat_position == true` to close protocol-agent's open hypothesis.

**Fix V Option B (FALLBACK):** keep early-return guard, inline the heartbeat + despawn
calls before delegation. Uglier (code duplication of despawn body) but simpler structurally.

**BUG-003 deferred:** game-tester runs sustained-sit baselines (V3-5 + V3-6). Architect
decides at V3.6 whether to scope a V3-followup or close as misperception.

**V3 architecture posted to architecture.md as new section "V3: Visibility & Regen
Regression Fix" — preserves V1 + V2 sections intact.**

---

---

### 2026-04-29 — c-expert → architect: protocol-agent IsMoving() hypothesis ruled out

**From:** c-expert → **To:** architect

**Summary:** Investigated protocol-agent's open hypothesis (NPC::AI_Process may set `moving=true` via face-tracking rotation, leaving the ping timer continuously disabled in combat). **Hypothesis RULED OUT** with code-grounded math.

**Empirical analysis:**
- RotateToCommand at running speed: `td = 200 × 19 × frame_time ≈ 380` heading units per frame
- Max heading delta: 256 units (full circle)
- Since `td ≈ 380 ≥ dist ≤ 256`, rotation completes in ONE movement-manager tick — `SetMoving(false)` runs in the same `RotateToCommand::Process()` that set true
- Main loop ordering (`main.cpp:601-617`): MobProcess() runs → AI queues RotateToCommand → mMovementManager->Process() runs AND completes the command → SetMoving(false). Next Companion::Process() tick sees `IsMoving()=false`. Heartbeat fires.
- For caster/healer holding position (`m_hold_combat_position=true`): FaceTarget only fires when `!IsMoving()` (`mob_ai.cpp:1361`); stationary target → `current_heading==new_heading` (`mob.cpp:4951`) → no rotation; moving target → completes in one tick. Either way, `IsMoving()=false` at next tick.

**Conclusion:** This would have been pre-V2 behavior — V2 changed nothing about it. Heartbeat works correctly for alive companions before and after V2. BUG-002 root cause is solely the V2 Fix R4 dead-companion heartbeat skip.

**Logged at commit 985524d on bugfix/companion-rez (claude repo).**

---

### 2026-04-29 — architect → V3 implementation team: V3 amendment locked

**From:** architect (decision log)

Per c-expert's IsMoving() hypothesis ruling-out, V3 plan amended:

**REMOVED from V3 scope:**
- Fix V Subtlety #2 (defensive `m_hold_combat_position` heartbeat bypass) — was protective dead weight against a now-disproven hypothesis
- Test V3.3 (defensive-heartbeat-in-held-position) — no fix, no test

**V3 Fix V is now strictly Option A:** restructure `Companion::Process()` top-section to capture `bool is_dead = (GetHP() <= 0);` and wrap AI-dispatch-only sections in `if (!is_dead)` guards. Heartbeat block at `companion.cpp:2128-2142` left exactly as-is (no `m_hold_combat_position` bypass added).

**V3 implementation surface is 3 new tests + 1 C++ change.** Tests renumbered: V3.1 (heartbeat-for-dead), V3.2 (despawn-timer-for-dead), V3.3 (alive-companion-regression-guard). Implementation tasks renumbered: V3.1 (failing tests), V3.2 (Fix V Option A), V3.3 (rebuild + verify), V3.4 (server restart), V3.5 (game-tester scenarios), V3.6 (BUG-003 decision), V3.7 (commit + push).

**BUG-003 empirical-first approach unchanged.** game-tester V3-5 + V3-6 sustained-sit baselines before any code change.

**V3 plan is now FINAL.** Per regression-discipline principle: defensive changes without empirical justification are risk surface for zero gain. YAGNI applied.


---

# V3 Re-Triage Architecture Conversations

> Started: 2026-04-29
>
> The earlier V3 architecture cycle is SUPERSEDED. The user directed a complete
> re-process of BUG-002, BUG-003, and BUG-004 together, with explicit emphasis
> on the customized NPC and Spawn systems and their downstream consumers.
>
> **Architect lead:** architect agent (this thread)
> **Advisors:** c-expert, protocol-agent, lua-expert, data-expert, config-expert
>
> Every consultation with advisors MUST be logged here, including responses.
> If an advisor reports "no constraints" or "no existing rules", that finding
> is logged — it is as valuable as a found constraint.

---

### 2026-04-29 — protocol-agent: Ready (Initial Briefing Acknowledgment)

**From:** protocol-agent → **To:** architect

protocol-agent has completed initial reading:
- `PROTOCOL-CODE.md` (full) — opcode catalog, struct catalog, Titanium translation layer, position update structs, entity/spawn packet types, AoE/spell target packet structures
- `C-CODE.md` (networking and entity-hierarchy sections) — entity list structure, spawn system, group/raid tracking, AI tick architecture
- All three bug reports (BUG-002, BUG-003, BUG-004)
- `status.md` V3 Re-Triage section and V3 Amendment (IsMoving() hypothesis ruled out)
- `architecture.md` — V1, V2, prior V3 plan, and V3 Amendment

**Protocol-layer pre-analysis (before architect queries):**

BUG-002 (visibility heartbeat): Squarely in my lane. The Titanium client culls stationary entities when it stops receiving `OP_ClientUpdate`-equivalent position heartbeats for that entity. The relevant struct is `PlayerPositionUpdateServer_Struct` (line 1392 of `eq_packet_structs.h`), sent via `Mob::SendPosUpdate` / `SentPositionPacket`. The prior fix (commit `9e4b7dfd1`) used `m_ping_timer(5000)` to send a keepalive `SentPositionPacket(0,0,0,0,0)` every 5 seconds. V2's Fix R4 blanket early-return for HP=0 entities in `Companion::Process()` bypasses this heartbeat. The prior V3 plan had the correct root cause. The V3 Re-Triage may or may not change the fix shape — that depends on whether the customized-system enumeration reveals a shared root cause with BUG-004.

BUG-004 (AoE friend/foe filter): Has client-side implications. The server-side AoE sweep (`EntityList::AESpell`) builds the target list before sending damage packets. What reaches the Titanium client is the result list, not the filter decision itself — the client does not independently compute AoE targets; it receives `OP_Damage` (`CombatDamage_Struct`) for each affected entity. So the BUG-004 fix is entirely server-side: if the server stops sending `OP_Damage` for companions, the Titanium client will not show companions as being hit. No client-side packet change is needed for BUG-004.

BUG-003 (regen): Primarily not in my lane. Regen cadence and gsay reporting are server-side computations. The client displays the result of what the server sends via `MobHealth` (`OP_MobHealth`, 3 bytes: entity_id, hp_pct) and potentially mana-change packets. If regen is slow, the client just shows it slowly. No protocol constraint blocks or causes BUG-003.

**Ready for architect consultation.** Standing by for Round 1 query on entity-list registration packets and group/pet membership flags.

---

### 2026-04-29 — lua-expert → architect: Ready + pre-analysis

**From:** lua-expert → **To:** architect

lua-expert completed initial reading of all three bug reports, status.md V3 Re-Triage section, prior V3 architecture plan, V3 Amendment, and agent-conversations.md V3 Re-Triage section. Also audited all Lua modules in `akk-stack/server/quests/lua_modules/` and `global/global_npc.lua`.

**Key findings delivered:**

**BUG-003 gsay cadence — definitive answer:** The mana gsay reports are entirely C++-driven via `m_mana_report_timer(15000)` (`companion.cpp:57`). `Sit()` at line 4012 starts the 15-second timer; `Stand()` at line 4018 disables it. The report fires at lines 2029-2034 (passive stance) and 2163-2168 (active stance, gated on `!IsEngaged()`). Zero Lua involvement. Prior V3 verdict ("reporting code unchanged") confirmed.

**Lua consumers of companion identity / group / owner pointer — full enumeration:**
- `global_npc.lua`: `IsCompanion()` (identity), `GetOwnerCharacterID()` (owner pointer for timer handlers), `owner:GetGroup()` + `group:GroupMessage()` (group membership for LLM delivery), `group:GetMember(i)` + `member:IsCompanion()` (zone death tracking)
- `companion.lua`: `GetOwnerCharacterID()` (all command handlers), `GetHP/MaxHP/Mana/MaxMana()` (!status display only — not periodic), `IsSitting()` (status display), `GetManaRatio()` (buff-gating), `owner:GetGroup()` / `group:GroupMessage()` (buff queue routing)
- No mod hooks, no encounter system, no script_init.lua for companions

**No Lua code touches regen tick rate, heartbeat, or AoE targeting.** Lua paths only affected by V2 if `IsCompanion()`, `GetOwnerCharacterID()`, or `GetGroup()` return wrong values — those are C++ methods unchanged by V2.

**Outcome:** lua-expert ready for Round 1 queries. Standing by.

---

### 2026-04-29 — c-expert → architect: Ready + preliminary findings

**From:** c-expert → **To:** architect

c-expert completed initial reading of all three bug reports, status.md V3 Re-Triage section, architecture.md V2 section and prior V3 plan, V3 Amendment. Warmed up on: companion.cpp (full Process(), Spawn(), Death(), ResurrectFromCorpse(), IsFriendlyTarget(), IsAttackAllowed()), companion_ai.cpp (AI_ResurrectDeadGroupMember), spells.cpp (DetermineSpellTargets, SpellOnTarget), effects.cpp (AESpell), aggro.cpp (Mob::IsAttackAllowed), groups.cpp (IsGroupMember), entity.cpp (GetTargetsForConeArea, AESpell caller paths).

**Key preliminary findings delivered to architect:**

**BUG-002 (visibility heartbeat):**
Prior V3 diagnosis confirmed correct from code. Fix R4 at companion.cpp:1933-1935 returns `NPC::Process()` immediately for HP<=0 entities, bypassing the `m_ping_timer` heartbeat block at companion.cpp:2128-2142. Fix V (Option A — restructure with `bool is_dead` + `if (!is_dead)` guards) remains correct approach.

**BUG-004 (player AoE hits companions) — root cause found:**
Pre-existing gap, NOT a V2 regression (though V2's Fix B making rezzed companions properly registered in companion_list may have exposed it more consistently post-rez).

Root cause: `entity_list.AESpell()` (effects.cpp:1199) calls `caster_mob->IsAttackAllowed(current_mob, true)` for the AoE detrimental target filter. When the caster is a Client, `Mob::IsAttackAllowed` (aggro.cpp:732) is called — the base implementation, not Companion's override. The base function reduces `mob1 = client` (no ownerid) and `mob2 = companion NPC`. The macro `_NPC(x)` = `x->IsNPC() && !x->GetOwnerID()`. Companions use `m_owner_char_id` (custom tracking), NOT the standard `ownerid` field from `SetOwnerID()`. So `_NPC(companion) = true`, and the `_CLIENT vs _NPC` matrix branch at aggro.cpp:867 unconditionally returns `true` — client IS allowed to hit companion.

Companion's own `IsAttackAllowed` override (companion.cpp:832) blocks this correctly, but that override only fires when the COMPANION is the caster. A Client casting AoE goes through the base `Mob::IsAttackAllowed` which has no companion-awareness.

**BUG-003 (regen):**
No V2-caused code path change found for alive sitting companions. The sitting-regen block at companion.cpp:2237-2252 and the mana-report timer at companion.cpp:2163-2168 are both still reachable for alive entities (Fix R4 only skips HP<=0). Prior V3 verdict ("likely misperception for freshly-rezzed companion at 0 mana") still holds as the leading hypothesis. Empirical SQL polling of mana field vs gsay frequency is the mandatory gate before any code change.

**Summary to architect:** Three bugs appear to have independent (not shared) root causes. BUG-002 = V2 Fix R4 early-return bypasses heartbeat. BUG-004 = pre-existing Client base `IsAttackAllowed` blind to companion ownership. BUG-003 = likely misperception, needs empirical gate.

**Outcome:** c-expert ready for Round 1 formal enumeration query. Standing by.

---

### 2026-04-29 — config-expert → architect: Ready + Round 1 Rule Enumeration

**From:** config-expert → **To:** architect

config-expert completed initial reading of all three bug reports, status.md V3 Re-Triage section, and queried both the live `rule_values` table and `ruletypes.h` for all namespaces in the briefing: `Pets:*`, `Spells:*`, `Aggro:*`, `Range:*`, `Character:*`, `Companions:*`.

**BUG-004 (AoE friend/foe) — rule findings:**

`Pets:AESpellHittingPet` does NOT exist in ruletypes.h or rule_values. It was a hypothesis in the bug report, not a real rule. No existing rule controls companion-specific AoE exclusion. AoE target-count rules (`Spells:TargetedAOEMaxTargets`=4, `Spells:PointBlankAOEMaxTargets`=0, `Spells:DefaultAOEMaxTargets`=0) only cap target counts, not friend-foe filtering. **BUG-004 requires a C++ fix — no rule toggle is available.**

Additional code-path finding (consistent with c-expert): Traced `effects.cpp:1198-1213` — detrimental AoE gates on `caster_mob->IsAttackAllowed(current_mob, true)`. For a Client caster vs a Companion target, `Mob::IsAttackAllowed` (`aggro.cpp:837-868`) resolves `mob2=companion` with no ownerid (companions use `m_owner_char_id`, not `SetOwnerID()`/`GetPetID()` chains checked at `mob.cpp:4547-4559`). So `_NPC(mob2)=true` → returns `true` → player is allowed to attack their own companions.

NOTE: `GetTargetsForConeArea` at `entity.cpp:5636` DOES have companion-awareness (`pcnpc==1` filter excludes `IsCompanion()`), but `EntityList::AESpell` in `effects.cpp` does NOT use that function — it uses `GetCloseMobList` with its own filter. Cone AoEs may already be partially filtered; PBAE/TargetedAoE are not.

**New rule offer for BUG-004:** A `Companions:AoEExcludesCompanions` (bool, default true) rule would be appropriate if server-operator tuning is desired. Requires ruletypes.h addition (c-expert) + rule_values INSERT (config-expert) + C++ check in the AoE filter. Architect decides whether to create it or hardcode.

**BUG-003 (regen) — rule findings:**

All regen-related rules are at expected values:
- `Companions:HPRegenPerTic` = 1
- `Companions:CompanionManaRegenMult` = 100
- `Companions:SittingRegenMult` = 200
- `Companions:OOCRegenPct` = 5
- `Companions:AlwaysMeditateRegen` = true
- `Character:HPRegenMultiplier` = 200
- `Character:ManaRegenMultiplier` = 175
- `Character:RestRegenEnabled` = true, `Character:RestRegenTimeToActivate` = 15

No rule is misconfigured. BUG-003 is not a rule issue. Empirical SQL-polling gate is the correct first step.

Flag: `Companions:CompanionManaRegenMult`=100 (no scaling). If the prior "fast regen" fix was a rule value bump on this multiplier that was somehow reset, that would explain the regression. c-expert should check git history for changes to this rule's default in ruletypes.h.

**BUG-002 (visibility heartbeat) — rule findings:**

No rules control heartbeat timer cadence or visibility behavior. `m_ping_timer(5000)` is hardcoded. Config-expert has no role in the BUG-002 fix.

**Summary table:**

| Bug | Rule fix possible? | New rule recommended? | C++ required? |
|-----|-------------------|----------------------|---------------|
| BUG-002 (heartbeat) | No | No | Yes (Fix V Option A) |
| BUG-003 (regen) | No — rules correct | No (pending empirical) | TBD |
| BUG-004 (AoE) | No existing rule | Optional toggle | Yes (`IsAttackAllowed` path) |

**Outcome:** config-expert standing by for Round 2 queries. Will design `Companions:AoEExcludesCompanions` rule spec if architect requests it.

---

## Round 1 — Customized-System Enumeration (parallel dispatch)

### 2026-04-29 — architect → all five advisors: Round 1 enumeration queries dispatched

**Dispatch type:** Five parallel SendMessage queries, one to each advisor, each scoped to that advisor's domain. The framing is identical across queries — triage cluster of BUG-002, BUG-003, BUG-004; V2 changes (Fix A `membername[]` clear at Death, Fix B `Spawn(owner)` reroute on rez, Fix R4 alive-guard, Fix C atomic rez); customized-system enumeration is the PRIMARY architecture deliverable, fix shape secondary; user has been burned twice by V2 silently breaking adjacent behaviors.

**Per-advisor scope:**

| Advisor | Domain | Areas enumerated |
|---|---|---|
| c-expert | C++ engine | (A) Spawn pipeline / entity-list registration, (B) AI tick loop, (C) Group-membership system, (D) AoE friend/foe filter, (E) Death/suspension model, (F) Spell target validation, (G) Save/load/zone-in, (H) Hate-list / faction / EVENT_DEATH dispatch / IsCompanion chain |
| protocol-agent | Titanium client/packet layer | (A) Position-update / visibility heartbeat packets, (B) Group/raid/party display packets, (C) AoE spell target packets, (D) Mana/HP update packets, (E) Pet/companion identification packets, (F) Spawn-struct fields, (G) Titanium-specific constraints |
| lua-expert | Lua scripting | (A) gsay reporting cadence (BUG-003 critical), (B) companion.lua dispatch and event hooks, (C) global_npc.lua / global_player.lua + `@CompanionName` parsing, (D) Mod hook system, (E) data_buckets keys, (F) Buff/regen Lua hooks, (G) AoE friend/foe Lua-side filtering, (H) thread_manager / encounters |
| data-expert | SQL / data layer | (A) companion_data row lifecycle through Death→rez, (B) data_buckets keys for companion state, (C) Group/membership tables, (D) character_pet_* tables, (E) faction_values, (F) inventory tables, (G) Buff persistence, (H) Rules table snapshots, (I) Schema migrations between V1→V2 ship, (J) **BUG-003 empirical-first measurement plan** (mandatory dedicated answer per V3R Architecture Mandate 3) |
| config-expert | Rules / configuration | (A) `Pets:*`, (B) `Companions:*`, (C) `Spells:*`, (D) `Aggro:*` / `Combat:*` / `NPC:*`, (E) `Character:*` / `Range:*`, (F) Combat regen rules, (G) Position-update / visibility / corpse-decay tuning, (H) `Group:*` / `Raid:*`, (I) Empirical-first BUG-003 rule angle |

**Format mandated for all advisor responses:** numbered consumer entries with `Consumes / Regression mode / V2 touchpoint / File path` fields. "No existing rule for X" / "no existing consumer for X" findings are explicitly required — null findings are as valuable as positive ones.

**Constraint specified to all advisors:** "What I do NOT need from you in Round 1: the fix, a verdict on which bug maps to which consumer, an opinion on the prior V3 plan." — Round 1 is enumeration-only. Joint root-cause analysis happens in Round 2.

**Empty enumeration = workflow violation** — explicitly stated to each advisor.

**Awaiting:** five enumeration responses. Each will be logged here as it arrives.

### 2026-04-29 — protocol-agent → architect: pre-analysis findings + ready signal

protocol-agent has completed reading priming materials (three bug reports, V3 Re-Triage status.md section, prior V3 plan + Amendment, architecture.md V1/V2, PROTOCOL-CODE.md, C-CODE networking sections) and provided three pre-analysis findings before the formal Round 1 enumeration:

**Pre-finding P-1 — BUG-002 root cause locked at protocol layer:**
Titanium culls a stationary entity when it stops receiving periodic position update packets (`PlayerPositionUpdateServer_Struct` at `eq_packet_structs.h:1392`). The prior fix at commit `9e4b7dfd1` (2026-03-09) sent a keepalive via `SentPositionPacket(0,0,0,0,0)` driven by a 5-second `m_ping_timer`. V2's Fix R4 blanket early-return for HP=0 entities in `Companion::Process()` bypasses this heartbeat. **The prior V3 root-cause analysis was correct on this single point.** Whether the Re-Triage changes the fix shape depends on whether the joint customized-system enumeration surfaces a shared structural root cause with BUG-004 — i.e., we may end up with the same fix at the same site, or a wider restructure if BUG-002 + BUG-004 + BUG-003 share a deeper structural cause.

**Pre-finding P-2 — BUG-004 has ZERO client-side protocol constraint:**
The Titanium client does NOT compute AoE target lists independently. `EntityList::AESpell` builds the target list server-side, then `OP_Damage` (`CombatDamage_Struct`) packets are sent to each affected entity's client. If the server incorrectly includes a companion in the AoE sweep, the companion's `OP_Damage` is real and the client faithfully renders the hit. **The BUG-004 fix is entirely server-side** — no Titanium packet changes, no new opcodes, no struct changes needed. This is a major scope constraint: BUG-004 does not constrain the architecture from the client side, so we have full server-side latitude.

**Pre-finding P-3 — BUG-003 is NOT a protocol-layer issue:**
Regen display is driven by `OP_MobHealth` (3 bytes: entity_id + hp_pct) and `ManaChange_Struct`. The client displays whatever the server sends. If regen is slow server-side, the client faithfully shows it slow. **No protocol constraint causes or blocks BUG-003.** Eliminates one branch of the BUG-003 diagnosis tree (we cannot blame Titanium client interpolation; it does not interpolate regen).

**Architect response:** All three pre-findings logged. P-1 reaffirms V2's Fix R4 as the BUG-002 mechanism (the prior V3 plan was right on that single point — though I am not deferring to the prior V3 plan as gospel; the joint enumeration may reveal a deeper restructure is warranted). P-2 simplifies the BUG-004 scope substantially — no client-side packet changes needed, fix surface is purely server. P-3 narrows BUG-003's diagnosis tree to two branches: (a) actual server-side regen tick rate broken, or (b) Lua-side gsay reporting cadence broken. The empirical measurement plan I asked data-expert for in Section J of his Round 1 query is exactly the discriminator.

**Still required from protocol-agent:** the formal Round 1 enumeration response in the (A) Position-update heartbeat / (B) Group/raid display / (C) AoE spell target packets / (D) Mana/HP update packets / (E) Pet/Companion identification / (F) Spawn-struct fields / (G) Titanium-specific constraints structure with the per-consumer table format. The pre-findings are valuable but they are pre-findings — the structured enumeration is the formal Round 1 deliverable that becomes the input to Round 2 joint root-cause analysis and the foundation for the adjacent-system regression coverage in the validation plan.


---

### 2026-04-29 — data-expert → architect: Round 1 enumeration complete

**From:** data-expert → **To:** architect

Full DB-layer enumeration of every SQL/repository consumer of companion-related state relevant to the triage cluster (BUG-002, BUG-003, BUG-004). Format: numbered consumer entries per architect spec.

---

#### (A) companion_data row lifecycle through Death → rez

**A-1 — `companion_data.is_suspended` (death gate)**
- Consumes: C++ writes `is_suspended=1` at `companion.cpp:662-701` (BUG-028 fallback path via direct UPDATE) and `companion.cpp:~2470` (Suspend()/Save()). C++ reads `is_suspended` at zone-in (`SpawnCompanionsOnZone()`) to determine alive/dead state.
- Regression mode: if rez writes `is_suspended=0` but the entity fails to spawn (Fix B/C path), `is_suspended=0` persists in DB with no in-zone entity → next zone-in spawns a "ghost" companion with no group membership.
- V2 touchpoint: Fix C introduces pre-flight group-capacity check (Option D) and deferred corpse depop (Option C). The is_suspended rollback on Spawn() failure uses direct SQL UPDATE (not ORM Save()), per V2 data-expert findings.
- File: `common/repositories/companion_data_repository.h` (auto-generated ORM)

**A-2 — `companion_data.cur_hp` / `cur_mana` / `cur_endurance`**
- Consumes: Written periodically by C++ Save() calls. Read at zone-in by `Load()` to restore HP/mana state.
- Regression mode: If `cur_mana` is saved incorrectly at death (BUG-003 candidate — companion dying at low mana saves near-0 mana, then regen starts from that low baseline on rez).
- V2 touchpoint: V2 Fix B routes rez through `Spawn(owner)` which calls `Load()` — reads `cur_mana` from DB. If `companion_data.cur_mana` was saved as 0 at death time, rezzed companion starts at 0 mana regardless of rez XP recovery.
- File: `companion_data` table, `companion_data_repository.h`

**A-3 — `companion_data.zone_id` / x / y / z / heading**
- Consumes: Written at death / zone-out. Read at rez to determine spawn position (companion spawns at corpse position post-rez, not at saved DB position — but if DB position is used as fallback, a mismatch could cause visual oddities).
- V2 touchpoint: Fix B replaces manual entity setup with `Spawn(owner)` — `Spawn()` reads from companion_data.zone_id/x/y/z. If corpse position differs significantly from last-saved DB position, the spawned companion may appear in the wrong location.
- File: `companion_data` table

**A-4 — `companion_data.stance`**
- Consumes: Read at zone-in to restore AI stance. Written on `!passive`, `!balanced`, `!aggressive` commands.
- Regression mode: If rezzed companion spawns in wrong stance (PASSIVE when it was BALANCED pre-death), the AI tick behavior changes — companion may not re-engage in combat. Not a confirmed V3 bug but a potential adjacent regression.
- V2 touchpoint: V2 Fix B (`Spawn(owner)`) calls `Load()` which reads stance. If Load() reads from a stale DB row where stance was last saved differently, rezzed companion gets wrong stance.
- File: `companion_data` table

---

#### (B) data_buckets keys for companion state

**B-1 — Companion cooldown keys**
- Consumes: `RecallCooldownS` and `RecruitCooldownS` rules use `data_buckets` with `key` pattern containing companion identifiers, `character_id=0`. Currently 0 active companion cooldown rows in DB.
- Regression mode: Not directly related to V3 bugs. However, if a re-recruit attempt after rez is made, the cooldown bucket check could block re-recruitment if a stale bucket exists.
- V2 touchpoint: None. Cooldown buckets are written by recruit/recall flows, not rez flow.
- File: `data_buckets` table; key pattern from companion.cpp or companion.lua

**B-2 — Current state (confirmed null findings)**
- Zero companion-related keys in `data_buckets` as of 2026-04-29.
- Zero rez-state persistence in `data_buckets`.
- The `soul_wipe_6_*` keys (8 rows) are unrelated to companion system.
- **NULL FINDING:** No rez-in-progress state is ever persisted to DB. If the server restarts mid-rez, the companion returns to `is_suspended=0` or `is_suspended=1` depending on which DB write landed last — `!unsuspend` is the recovery path.

---

#### (C) Group/membership tables

**C-1 — `group_id` table**
- Schema: `group_id`, `name`, `character_id`, `bot_id`, `merc_id` (NO companion-specific column).
- Current state: 0 rows (player offline).
- Consumes: Standard EQEmu group membership persistence for player characters. C++ reads this at world-login to restore group state.
- Regression mode: Companions are NOT persisted via `group_id`. They join via in-memory `CompanionJoinClientGroup()`. This means after a zone restart, all companion group membership is re-established by `SpawnCompanionsOnZone()` → `CompanionJoinClientGroup()`. If that path is broken, companions spawn but are not in the group.
- V2 touchpoint: Fix A cleared `membername[]` at Death — this is in-memory only, no `group_id` DB row to clear. The DB group table is not involved in companion death/rez.
- **NULL FINDING:** `group_id` table has no companion_id column. Companion group membership has zero DB persistence. It is entirely reconstructed at runtime from `companion_data` + `SpawnCompanionsOnZone()`.
- File: `common/repositories/group_id_repository.h`

**C-2 — `group_leaders` table**
- Schema: group leadership state (in-memory group leader info and assist targets).
- Current state: 0 rows.
- **NULL FINDING:** Not relevant to companion death/rez flow. Companions do not become group leaders.

---

#### (D) character_pet_* tables

**D-1 — `character_pet_info` / `character_pet_buffs` / `character_pet_inventory`**
- Consumes: Standard pet suspend/resume state for player-summoned pets (Magician, Necromancer, etc.).
- **NULL FINDING:** Companions do NOT use `character_pet_info` or related pet tables. The companion system is parallel to (not derived from) the standard pet system. This is the core reason the AoE friend/foe filter (BUG-004) is broken — the standard `IsOwnerID()` / `GetPetID()` ownership chain that the pet system uses for AoE exclusion does not apply to companions.
- File: `common/repositories/character_pet_info_repository.h`

---

#### (E) faction_values

**E-1 — Per-companion faction rows**
- Consumes: `faction_values` stores per-character faction standings. Companions use their source NPC's `npc_faction_id` → `npc_faction.primaryfaction` → `faction_list.id`. Factions for current companions: Dismal Rage (271), Freeport Militia (330), Storm Reapers (355), Highpass Guards (332), Priests of Life (341).
- Regression mode: AoE friend/foe filtering in vanilla EQ uses faction relationships (is this NPC on the same faction as the player?). If the custom companion system relies on faction checks for AoE exclusion, and companion faction data is wrong, BUG-004 could be faction-related.
- **Key finding:** Companions are registered in `npc_faction` under their original faction — NOT a "friendly companion" faction. So any AoE filter that checks `faction_values.current_value > KINDLY` to exclude targets would NOT exclude companions. The AoE exclusion must be based on ownership/group membership, not faction.
- V2 touchpoint: None. Faction data not touched by V2.
- File: `faction_values`, `npc_faction`, `faction_list`

---

#### (F) inventory tables

**F-1 — `companion_inventories`**
- 72 rows, all linked to companion_data.id via `companion_id`.
- Consumes: `Companions:EquipmentPersistsThroughDeath=true` rule — equipment retained after death. Written by equip commands; read at `Load()` time.
- Regression mode: If `Load()` is called on a freshly-rezzed companion before `LoadEquipment()`, the companion spawns naked. Fix B ordering: `Load()` → `Spawn(owner)` → `LoadEquipment()` → ... This ordering must be preserved.
- V2 touchpoint: Fix B changed the rez spawn ordering. If `LoadEquipment()` is called after `Spawn()` (which is correct), equipment should be applied. If it was accidentally dropped in the V2 rewrite, companions rez naked.
- File: `companion_inventories_repository.h`

---

#### (G) companion_buffs

**G-1 — Buff persistence**
- Currently 0 rows (no buffs saved for any companion).
- Consumes: Written at zone-out / `Save()`. Read at zone-in / `Load()`.
- **NULL FINDING:** No buff rows currently exist. Buffs are likely transient (cast by group members in-zone, not persisted across zone boundaries by default unless `persistent=1`).
- Regression mode: Not directly relevant to V3 triage bugs. Buff state is not involved in heartbeat, regen, or AoE filtering.

---

#### (H) rule_values — Full snapshot relevant to V3 bugs

**Regen rules (BUG-003):**
| Rule | Value | Ruleset |
|------|-------|---------|
| `Companions:AlwaysMeditateRegen` | true | 1 |
| `Companions:CompanionManaRegenMult` | 100 | 1 |
| `Companions:SittingRegenMult` | 200 | 1 |
| `Companions:OOCRegenPct` | 5 | 1 |
| `Companions:HPRegenPerTic` | 1 | 1 |
| `Character:ManaRegenMultiplier` | 175 | 1 |
| `Character:HPRegenMultiplier` | 200 | 1 |
| `NPC:OOCRegen` | 1 | 1 (active) |
| `NPC:OOCRegen` | 0 | 10 (inactive) |
| `NPC:UseMeditateBasedManaRegen` | false | 1 |

**AoE rules (BUG-004):**
- `Pets:AESpellHittingPet` — **DOES NOT EXIST** in rule_values or ruletypes.h.
- No existing rule controls AoE companion exclusion. Fix is pure C++.

**Visibility/heartbeat rules (BUG-002):**
- No rules control heartbeat timer cadence. `m_ping_timer(5000)` is hardcoded in companion.cpp:57.

---

#### (I) Schema migrations between V1→V2

No schema migrations were added between V1 and V2 ships for the `companion_data`, `companion_buffs`, `companion_inventories`, or `companion_spell_sets` tables. V2 was pure C++ changes (Fix A/B/C/R4). The `db_version.custom_version` field tracks custom migrations — no change between V1 and V2 deployment per architecture.md V2 "No DB schema changes" confirmation.

---

#### (J) BUG-003 empirical-first measurement protocol (mandatory per V3R Architecture Mandate 3)

**Objective:** Differentiate "actual regen is slow" from "gsay reporting cadence is slow."

**SQL polling query** (run every 5 seconds while companion sits):
```sql
SELECT id, name, cur_mana, UNIX_TIMESTAMP() AS ts
FROM companion_data
WHERE owner_id = 6
ORDER BY id;
```

**Expected values at level 54 Cleric (Lashun Novashine, cur_mana=7907):**
- Prior V3 formula: `final_regen ≈ 36/tick` at meditate=295, `AlwaysMeditateRegen=true`
- With `ManaRegenMultiplier=175`: 36 × 1.75 = 63 mana/tick
- At 15s gsay cadence: ~2.5 ticks × 63 = ~157 mana per gsay report
- As % of 7907-mana pool: ~2% per report
- "1%/report" user observation = ~79 mana/15s → diverges from formula by ~2×

**Proposed test sequence for game-tester:**
1. Sit with Lashun Novashine (cur_mana=7907 baseline, full-mana companion, not recently rezzed).
2. Open second terminal; run the SQL polling query every 5s for 2 minutes.
3. Simultaneously record gsay mana% at each 15s report.
4. Calculate actual mana delta per tick from SQL deltas.
5. If SQL-observed regen ≈ formula → gsay perception is the discrepancy (or pool larger than expected).
6. If SQL-observed regen < formula → actual regen is broken; escalate to C++ investigation.

**Repeat with Jimble Woodentoe** after `!unsuspend` (post-rez, climbing from saved cur_mana) to compare climb-from-low behavior vs. full-mana baseline.

---

**OVERALL DB VERDICT FOR V3 RE-TRIAGE**

- No DB schema changes required for any of the three bugs.
- All companion_data rule_values are at expected defaults; no misconfiguration found.
- Jimble `is_suspended=1` is an artifact of the V2 in-game test; no action needed now.
- Group membership has zero DB persistence for companions — entirely runtime-reconstructed.
- Companions do NOT use `character_pet_*` tables or `GetOwnerID()`/`SetOwnerID()` ownership chain — this is the DB-layer confirmation of why BUG-004 (AoE friend/foe) is broken at the C++ layer.
- The BUG-003 measurement protocol is ready; game-tester can execute as a prerequisite to any code fix decision.


### 2026-04-29 — lua-expert → architect: pre-analysis + Round 1 enumeration delivered

lua-expert has completed reading the three bug reports, V3 Re-Triage status.md section, prior V3 plan + Amendment, agent-conversations.md V3R section, and completed a full Lua-side audit. The response delivers both pre-analysis findings AND the Round 1 enumeration in a combined message. Logging the substantive findings:

**Major finding L-1 — BUG-003 gsay reporting is ENTIRELY C++-driven (definitive Lua-side verdict):**

The companion HP/mana gsay regen reports are driven by C++ in `companion.cpp`, not Lua. lua-expert pinned the call chain:

| File:line | Code |
|---|---|
| `companion.cpp:57` | `m_mana_report_timer(15000)` initialized in Companion constructor — 15-second interval |
| `companion.cpp:4012` | `Sit()` calls `m_mana_report_timer.Start(15000)` |
| `companion.cpp:4018` | `Stand()` calls `m_mana_report_timer.Disable()` |
| `companion.cpp:2029-2034` | passive-stance mana report fires on `IsSitting() && m_mana_report_timer.Check()` |
| `companion.cpp:2163-2168` | engaged-stance equivalent — already guards on `!IsEngaged()` |

**There is zero Lua code that drives, schedules, or emits the mana/HP regen gsay report.** The prior V3 verdict ("reporting code unchanged") is independently confirmed.

**Architect interpretation:** Combined with protocol-agent's pre-finding P-3 (regen display is `OP_MobHealth` faithfully rendering whatever the server sends — no client interpolation), the BUG-003 diagnosis tree narrows from two branches to one:
- ~~Branch (b): Lua-side gsay reporting cadence broken~~ → ELIMINATED. Lua does not drive gsay reporting. The 15s cadence is hardcoded in C++ and unchanged by V2.
- **Branch (a) — actual server-side regen tick rate broken or always-was-this-way + misperception** is the only remaining branch.

The 15s `m_mana_report_timer` interval interacts with the report-then-regen ordering at companion.cpp:2163-2168 (this ordering predates V2). The lua-expert reading "1%/report consistent with freshly-rezzed companion climbing from cur_mana=0 against large max_mana pool" matches the prior V3 empirical math finding (level 54 cleric, meditate=295, final_regen=36/tick → mana fills at rate consistent with what user observed if observation began at cur_mana=0).

**This makes the BUG-003 empirical measurement plan in data-expert's Section J even more critical.** The empirical question is now narrowed to: "When a companion has been sitting for 5+ minutes (well past the freshly-rezzed climb), what is the actual mana-tick rate vs what is the gsay-reported rate?" If the actual mana-tick is fast and gsay reports a slow climb, that means gsay timing is misaligned (15s interval against tick-rate may produce a perceived-slow report rate even when regen is correct). If the actual mana-tick is slow AND gsay matches, then regen itself regressed and the V2 changes are implicated even though the regen code path appears unchanged on inspection.

**Major finding L-2 — Complete Lua-side enumeration of companion identity / group / owner pointer consumers:**

lua-expert audited every Lua call site in `lua_modules/` that touches companion identity, group membership, or owner pointer. Findings:

**`global_npc.lua` consumers:**
- `e.self:IsCompanion()` — identity check for !-command dispatch and commentary timer start (event_say, event_spawn)
- `e.self:GetOwnerCharacterID()` — owner pointer used in gsay_deliver timer and buff_request timer to locate the owner client
- `owner:GetGroup()` then `group:GroupMessage(e.self, ...)` — group membership for staggered LLM response delivery and buff delivery
- `group:GetMember(i)` then `member:IsCompanion()` — group scan in event_death_zone for recent-kill context

**`companion.lua` consumers** (!-command dispatch library):
- `npc:GetOwnerCharacterID()` — ownership check in every command handler
- `npc:GetHP()` / `npc:GetMaxHP()` / `npc:GetMana()` / `npc:GetMaxMana()` — for the on-demand !status command (NOT the periodic gsay)
- `npc:IsSitting()` — status display and guard
- `npc:GetManaRatio()` — mana-below-10% gate for !buffme / !buffs
- `owner:GetGroup()` / `group:GroupMessage()` — buff queue + status routing

**Architect interpretation:** None of these Lua consumers were changed by V1, V2, or earlier branch work. They would only be affected by V2 if V2 broke `IsCompanion()`, `GetOwnerCharacterID()`, or `GetGroup()` returning wrong values — but those are unchanged C++ methods on the Companion/Client objects, untouched by Fix A / B / R4 / C.

**However, there is a subtle Round 2 item to investigate:** `owner:GetGroup()` — does it return non-null while a companion is in `is_suspended=1` state? If V2 Fix A clearing `membername[]` at Death also affects what `GetGroup()` returns (e.g., the group registration is in-memory shared), then any Lua consumer downstream that calls `GroupMessage()` could be silently no-op'd until rez restores the slot. This would manifest as gsay messages being dropped during the dead-window — a transient visibility gap, not a regen rate change. **Flag for Round 2 cross-reference with c-expert's enumeration** — specifically what state Fix A clearing `membername[]` actually invalidates from the Lua-callable Group methods' perspective.

**Major finding L-3 — Mod hooks not relevant:**

No `lua_modules/` file registers Lua mod hooks (combat, XP, damage, spell, regen overrides). Engine-level Lua mod hook system is unused for companions. **Eliminates Lua mod hooks as a vector for any of the three bugs.**

**Major finding L-4 — Encounter system not relevant:**

No companion-related `script_init.lua` or encounter-system scripts exist. **Eliminates encounter system as a vector for any of the three bugs.**

**Architect response — Round 1 Lua enumeration accepted as complete.** The structured findings cover the (A)–(H) areas requested. No formal table-format follow-up needed — the prose is dense and code-grounded, with file:line references. Round 1 Lua-side closed.

**Net advisor count so far:** 1 of 5 closed (lua-expert). Awaiting c-expert, protocol-agent (formal enumeration), data-expert, config-expert.


### 2026-04-29 — c-expert → architect: pre-analysis findings on all three bugs (HYPOTHESIS-REFUTING FINDING)

c-expert has read all three bug reports, V2 architecture history, and warm-coded companion.cpp, companion_ai.cpp, spells.cpp, effects.cpp, aggro.cpp, groups.cpp, entity.cpp. Delivered preliminary findings before formal Round 1 enumeration. **The findings partially refute the architect's working hypothesis that all three bugs share a single V2 root cause.**

**Major finding C-1 — BUG-002 root cause confirmed (V2 regression):**

Fix R4 at `companion.cpp:1933-1935` returns `NPC::Process()` immediately for `HP<=0` entities, skipping the `m_ping_timer` heartbeat block at `companion.cpp:2128-2142`. The prior V3 diagnosis was correct on this point. **Fix V Option A — restructure `Process()` top-section with `bool is_dead = (GetHP() <= 0);` capture + `if (!is_dead)` guards on AI dispatch sections — remains the correct approach.**

c-expert flags one nuance: dead companions are also skipping sitting-regen and mana-report timer paths during the dead-window. This may or may not matter for the eventual fix (a dead entity probably should not regen, and probably should not gsay-report mana, so leaving those skipped is likely correct — but I want this confirmed in Round 2).

**Major finding C-2 — BUG-004 root cause is PRE-EXISTING, NOT a V2 regression:**

c-expert traced the AoE path directly:

```
entity_list.AESpell() (effects.cpp:1199)
  → caster_mob->IsAttackAllowed(current_mob, true)
  → for detrimental spells, mob is skipped if IsAttackAllowed returns false
  → Client caster calls Mob::IsAttackAllowed (base, aggro.cpp:732)
  → that function:
     - reduces mob1 = our_owner ? our_owner : this
     - reduces mob2 = target_owner ? target_owner : target
     - uses _CLIENT(mob1) vs _NPC(mob2) matrix
  → macro _NPC(x) = x->IsNPC() && !x->GetOwnerID()
  → Companions NEVER call SetOwnerID() — they use their own m_owner_char_id
    field, NOT the standard ownerid field
  → so _NPC(companion) = TRUE
  → _CLIENT vs _NPC branch unconditionally returns TRUE
  → the client IS allowed to attack the companion
  → AoE sweep includes the companion as a valid target
  → companion gets the mez/stun
```

The `Companion` class has its own `IsAttackAllowed` override at `companion.cpp:832` that calls `IsFriendlyTarget()` — **but that override only fires when the COMPANION is the caster, not when the CLIENT is the caster against the companion.** The client casting goes through the base `Mob::IsAttackAllowed` which doesn't know about `m_owner_char_id`.

**This is a pre-existing gap, NOT introduced by V2 Fix A or Fix B.** c-expert's hypothesis: V2 may have *exposed* the gap by ensuring rezzed companions are now properly registered in entity lists (Fix B's `Spawn(owner)` path) — meaning they participate in AoE sweeps as live entities post-rez where they may have previously been ignored due to entity-list registration drift. He flagged a follow-up: "I need to check whether V2 changed the entity-list registration that previously caused companions to have a different type classification."

**Architect interpretation:** This is a major scope reframing. BUG-004 is not a refactor regression — it's a pre-existing latent bug exposed by V2's correctness. Two possible fix shapes:
- **Fix shape α:** Override `Mob::IsAttackAllowed` for the Client-caster-against-Companion case so companions are recognized as friendly via `m_owner_char_id`. Could be done via a new Companion check inside `_NPC(x)` macro / `IsAttackAllowed` base, or via a Client-side override.
- **Fix shape β:** Have companions properly call `SetOwnerID(owner_entity_id)` during `Spawn(owner)` so the existing `_NPC(x) = x->IsNPC() && !x->GetOwnerID()` correctly excludes them. This could ALSO trigger downstream consequences — anywhere `GetOwnerID()` is read could now suddenly see a non-zero value for companions for the first time. **This is the customized-system enumeration concern in microcosm — fix shape β is exactly the kind of "fix that subtly breaks adjacent functionality" pattern the V3R Architecture Mandates exist to prevent.**

I need c-expert's formal enumeration to confirm what reads `GetOwnerID()` for NPC-type entities before I can choose between α and β.

**Major finding C-3 — BUG-003 likely misperception (verdict preserved as hypothesis):**

`Companion::Process()` regen path at `companion.cpp:2237-2252` is gated behind `IsSitting() && !IsEngaged()`. This still runs for alive companions (Fix R4 only skips HP<=0). Mana-report timer at `companion.cpp:2163-2168` also still runs for alive companions. **No code path that would cause regen to slow for alive sitting companions due to V2 changes.** The prior V3 verdict (misperception / freshly-rezzed climb from 0 mana) holds as the leading hypothesis.

Combined with lua-expert's L-1 (gsay reporting is C++-driven) and protocol-agent's P-3 (no client interpolation), **all three independent advisor reads converge on "BUG-003 is most likely misperception / freshly-rezzed climb."** The empirical measurement plan from data-expert (Section J of his Round 1 query) is the single discriminator. **Per V3R Architecture Mandate 3, the verdict is held as a hypothesis until empirical measurement runs.**

**Major finding C-4 — Three bugs likely DO NOT share a single root cause (working hypothesis REFUTED):**

The architect's working hypothesis at the start of this re-triage was: "all three bugs share a root cause in V2's entity-registration / Spawn-pipeline changes." c-expert's findings refute this:

| Bug | Root cause (per c-expert) | V2 regression? | Fix scope |
|---|---|---|---|
| BUG-002 | Fix R4 top-of-Process early-return skipping heartbeat | YES (V2-introduced) | Restructure Process() top-section |
| BUG-003 | Likely misperception (freshly-rezzed climb from 0 mana) | NO (preserved hypothesis) | Empirical measurement before any code change |
| BUG-004 | Pre-existing gap — base `Mob::IsAttackAllowed` blind to companion `m_owner_char_id` | EXPOSED BY V2 (entity-list registration correctness), but the gap pre-dates V2 | Fix shape α (override IsAttackAllowed for companion case) OR β (SetOwnerID on Spawn(owner)) |

**Architect interpretation:** This is a positive reframing. The V3 Re-Triage was kicked off because the architect agent definition was updated and a re-process was directed; "all three bugs share a root cause" was a working hypothesis to confirm or refute. Refuting it means the fix shape becomes clearer: **three independent fix surfaces, each scoped narrowly, each independently testable**, rather than a single broad restructure that the prior V3 plan was approaching.

**Critical for Round 2 cross-reference:** If c-expert's enumeration confirms that BUG-004 fix shape β (calling `SetOwnerID()` on companion Spawn) has wide downstream blast radius, fix shape α (narrowing the `IsAttackAllowed` matrix at the consumer) is preferred per the V3R Architecture Mandate principle of minimum blast radius into customized systems.

**Architect response — pre-analysis ACCEPTED, formal enumeration STILL REQUIRED.** The pre-findings are solid and significantly reframe the fix shape. The formal Round 1 enumeration is still needed because:

1. The (B) AI tick / regen / heartbeat enumeration determines whether c-expert's "regen path is unchanged" claim survives scrutiny when cross-referenced against config-expert's rule enumeration (e.g., is there a `Pets:*` rule that scales companion regen?)
2. The (D) AoE friend/foe filter enumeration must list every consumer of `GetOwnerID()`, `m_owner`, group membership, pet status — to inform the α vs β choice in BUG-004
3. The (G) save/load enumeration must confirm whether BUG-004 fix shape β would persist or affect the rehydration path
4. The (H) IsCompanion chain enumeration is the most direct input to fix shape α design

---

### 2026-04-29 — config-expert → architect: Round 1 Full Rule Enumeration (Categories A–I)

**From:** config-expert → **To:** architect

Full structured enumeration across all requested categories (A–I) per architect's Round 1 query format. Source: `ruletypes.h` defaults cross-referenced against live `rule_values` table (active ruleset_id=1 "default"). All non-default live values explicitly flagged.

**Key findings by category:**

**A. Pets:* — BUG-004:** `Pets:AESpellHittingPet` **DOES NOT EXIST** in ruletypes.h or rule_values. All 10 Pets rules enumerated; zero control AoE friend/foe filtering. C++ fix required for BUG-004.

**B. Companions:* — full enumeration (47 rules):** All at expected values except two intentional non-defaults: `LevelRange`=50 (default 3, intentional server tuning) and `BaseRecruitChance`=100 (default 50, intentional). All regen-related rules correct: `CompanionManaRegenMult`=100, `SittingRegenMult`=200, `AlwaysMeditateRegen`=true, `HPRegenPerTic`=1, `OOCRegenPct`=5. No Companions rule governs AoE exclusion or visibility heartbeat.

**C. Spells:* — BUG-004:** `Spells:AEHateOwner` and `Spells:AESpellHittingPet` **DO NOT EXIST**. `TargetedAOEMaxTargets`=4, `PointBlankAOEMaxTargets`=0, `DefaultAOEMaxTargets`=0 — count caps only, not friend/foe. Zero Spells rules control AoE exclusion.

**D. NPC:* — BUG-003 diagnostic key finding:** `NPC:OOCRegen`=1 on active ruleset (ruletypes.h default=0). Server has base NPC OOC regen enabled for all NPCs. If V2 caused companions to fall through to the base NPC regen path instead of the custom Companions path, `NPC:OOCRegen=1` produces "1 HP/tick" baseline instead of `Companions:OOCRegenPct=5%` amplification. Diagnostic: `NPC:OOCRegen`=0 + `#reloadrules` → if companion HP regen stops, they're on the NPC path.

**E. Character:* — BUG-003 highest-priority rule-only finding:** `Character:ManaRegenMultiplier`=175 (1.75x, default 100). `Character:HPRegenMultiplier`=200 (2x, default 100). These multipliers are tuned for the player. Companions are NPCs (not Characters) — if `Character:ManaRegenMultiplier` does NOT apply to companions (c-expert to confirm), then `Companions:CompanionManaRegenMult`=100 means companions get unscaled NPC mana regen while the player gets 1.75x. **This is the most plausible rule-only explanation for BUG-003 — a tuning divergence, not a V2 regression.** Fix candidate without code change: raise `Companions:CompanionManaRegenMult` to ~175 and test parity. This is the single highest-leverage rule lever for BUG-003.

**F. Combat:* — zero regen rules.** Combat category covers melee/proc/flee/crit only. No regen rules in this category.

**G. Heartbeat (BUG-002) — no rules.** Zero rules control `m_ping_timer(5000)` cadence or NPC visibility. `Range:ClientPositionUpdates`=300 controls movement-triggered updates for clients only, not stationary NPC heartbeat. BUG-002 requires C++ fix.

**H. Group:* — ZERO rules exist.** Confirmed: no `Group:*` rules in ruletypes.h. Group behavior is C++ constants only.

**I. Empirical-first BUG-003 test plan (rule-only):**
1. UPDATE `Companions:CompanionManaRegenMult` = 175 in rule_values (data-expert 1-row UPDATE) → `#reloadrules` → test mana regen parity with player
2. If still slow: UPDATE `NPC:OOCRegen` = 0 → `#reloadrules` → test HP regen path (does companion regen stop? → they're on NPC path, not companion path)

**Confirmed non-existent rules (hypothesized in bug reports):**
- `Pets:AESpellHittingPet` — does not exist
- `Spells:AEHateOwner` — does not exist
- Any `Group:*` rules — category is empty in ruletypes.h

**Rule-only fix paths:**
- BUG-002: NONE — C++ required
- BUG-003: POSSIBLE via `Companions:CompanionManaRegenMult` → empirical test first (aligns with V3R Architecture Mandate 3)
- BUG-004: NONE (no existing rule); new `Companions:AoEExcludesCompanions` rule could be created alongside a C++ fix as a server-operator toggle

**Outcome:** Round 1 complete. Standing by for Round 2 queries.


### 2026-04-29 — config-expert → architect: Round 1 rule enumeration delivered

config-expert has read all three bug reports, V3 Re-Triage status.md, and queried both the live `rule_values` table and `ruletypes.h` across every namespace listed in the Round 1 query.

**Major finding G-1 — `Pets:AESpellHittingPet` does NOT exist in this codebase:**

The bug report for BUG-004 mentioned `RuleB(Pets, AESpellHittingPet)` as a potential toggle. **config-expert has confirmed this rule does NOT exist** — neither in `ruletypes.h` nor in `rule_values`. It was a hypothesis from the bug report, not a confirmed rule. **Eliminates the easiest BUG-004 fix path** ("just toggle a rule").

**Major finding G-2 — Live AoE-related rules don't gate friend/foe (only target counts):**

| Rule | Live Value | Controls |
|---|---|---|
| `Spells:TargetedAOEMaxTargets` | 4 | Max targets for targeted AoE detrimental |
| `Spells:PointBlankAOEMaxTargets` | 0 (no limit) | Max targets for PBAE detrimental |
| `Spells:DefaultAOEMaxTargets` | 0 (no limit) | Max targets for other AoE |
| `Spells:SwarmPetTargetLock` | false | Swarm pet target locking (not relevant) |

None gate friend/foe — only count caps. **No existing rule can fix BUG-004.** C++ change required.

**Major finding G-3 — config-expert independently confirmed c-expert's BUG-004 trace:**

config-expert traced `effects.cpp:1198-1213` → `Mob::IsAttackAllowed` at `aggro.cpp:837-868` and added a key code-grounded detail: **`GetOwner()` at `mob.cpp:4547-4559` requires `GetPetID()==GetID()` — companions are NOT registered as pets in the NPC pet system.** This is the technical reason why the standard pet-ownership check fails for companions. So in the `_CLIENT vs _NPC` matrix, the companion falls through to `_NPC(mob2)` at line 867 → returns `true` → player is allowed to attack their own companions.

**Two-advisor convergence on BUG-004 root cause:** c-expert (C-2) and config-expert (G-3) independently traced the same path and identified the same gap. **Root cause locked.**

**Major finding G-4 — Cone AoE may already be partially companion-aware (`entity.cpp:5636`):**

`GetTargetsForConeArea` at `entity.cpp:5636` has a companion-aware filter: `pcnpc==1` excludes `IsCompanion()` from the NPC bucket. **But `EntityList::AESpell` in `effects.cpp` does NOT use `GetTargetsForConeArea`** — it uses `GetCloseMobList` with its own filter. So cone AoE might already exclude companions correctly, but PBAE / TargetedAoE / regular AoE detrimentals do not.

**Architect interpretation:** This is a partial precedent. The fact that someone already wrote `IsCompanion()`-exclusion logic in `GetTargetsForConeArea` for cone AoE means the project already has a pattern for "exclude companion from owner-cast AoE." The fix for the other AoE paths can follow the same pattern. **This argues for fix shape α (narrow IsAttackAllowed-or-similar override) over fix shape β (SetOwnerID).** β would have wide blast radius across all `GetOwnerID()` consumers; α follows an established pattern in the same codebase.

**Major finding G-5 — Five `Companions:*` regen rules at expected values:**

| Rule | Live Value | What it controls |
|---|---|---|
| `Companions:HPRegenPerTic` | 1 | Minimum HP regen per 6-second tick |
| `Companions:CompanionManaRegenMult` | 100 | Mana regen multiplier (100 = no scaling), applied after `Character:ManaRegenMultiplier` |
| `Companions:SittingRegenMult` | 200 | Sitting regen multiplier (200 = 2x while sitting) |
| `Companions:OOCRegenPct` | 5 | OOC HP regen as % of max HP per tick |
| `Companions:AlwaysMeditateRegen` | true | Whether companions always get meditate-level mana regen |

Plus global `Character:HPRegenMultiplier=200`, `Character:ManaRegenMultiplier=175`, `Character:RestRegenEnabled=true`, `Character:RestRegenTimeToActivate=15`.

**All rules at expected/intended values.** No rule is misconfigured. If BUG-003 is a real regression, it is NOT a rule issue.

**Round 2 carry-forward flag G-5a:** config-expert correctly notes that `Companions:CompanionManaRegenMult=100` is worth flagging — IF the prior "fast regen" baseline was achieved by setting this multiplier higher than 100, and IF that value was somehow reset, that would explain the regression. **Current live value is 100. config-expert cannot confirm from this snapshot alone whether it was ever higher** — c-expert (or git history check) needs to confirm whether ruletypes.h's default for `CompanionManaRegenMult` ever changed, OR whether someone's runtime modification was reset by a server restart. This is a Round 2 cross-reference: data-expert should pull `rule_values` rowtimestamps if available, c-expert should check git log for `CompanionManaRegenMult`.

**Major finding G-6 — BUG-002 has no rule lever:**

`m_ping_timer(5000)` at `companion.cpp:57` is hardcoded. No existing rule controls heartbeat cadence or visibility for companions. **Config-expert has no role in the BUG-002 fix.** Pure C++ restructure (Fix V Option A pattern from prior V3) is required.

**Major finding G-7 — Recommendation: optional new rule `Companions:AoEExcludesCompanions`:**

config-expert proposes that BUG-004's fix could include an optional new rule `RuleB(Companions, AoEExcludesCompanions)`, default true, to give server operators a toggle without recompilation. This is OPTIONAL — the fix can be hardcoded. **Architect decides.** The benefit is future-proofing; the cost is one more rule to maintain. Per V3R principle of minimum surface, I am leaning toward NOT adding the rule unless the user signals operator-tuning is a concern.

---

**Summary (config-expert verdict):**

| Bug | Rule fix possible? | New rule recommended? | C++ required? |
|---|---|---|---|
| BUG-002 (visibility heartbeat) | No | No | Yes (Fix V Option A pattern) |
| BUG-003 (regen) | No — rules at correct values | No (pending empirical) | TBD after empirical measurement |
| BUG-004 (AoE friend/foe) | No existing rule | Optional toggle (architect decides) | Yes — `IsAttackAllowed` path or AoE filter |

---

**Architect response — Round 1 config-expert closed.** Findings G-1 through G-7 logged. Notable outcomes:

- **G-1 + G-2 eliminate the "tune a rule" fix path entirely for BUG-004** — only C++ change is viable
- **G-3 confirms c-expert's BUG-004 trace independently** (two-advisor convergence on root cause)
- **G-4 argues for fix shape α over β** for BUG-004 — the codebase already has an `IsCompanion()`-exclusion pattern in `GetTargetsForConeArea`; replicating that pattern in the other AoE filter paths is a precedent-following fix, narrower than β's `SetOwnerID()` change
- **G-5 confirms no rule misconfiguration explains BUG-003**; no live rule needs to be touched
- **G-5a** is a Round 2 antagonistic flag — was `CompanionManaRegenMult` ever higher than 100? c-expert + data-expert cross-reference required
- **G-7** the optional `Companions:AoEExcludesCompanions` rule will be reviewed in Round 3 fix-shape design — leaning NO unless the user signals operator-tuning need

**Net advisor count so far:** 2 of 5 closed (lua-expert, config-expert). Awaiting c-expert formal enumeration, protocol-agent formal enumeration, data-expert.

---

### 2026-04-29 — config-expert → architect: Round 2 carry-forward G-5a check (rule_values timestamp audit)

**From:** config-expert → **To:** architect

Ran `DESCRIBE rule_values` against the live DB. Schema:

```
ruleset_id  tinyint(3) unsigned  PK
rule_name   varchar(64)          PK
rule_value  text
notes       text
```

**No timestamp columns exist.** `rule_values` has no `created_at`, `updated_at`, or any row-modification history. There is no DB-layer record of when `Companions:CompanionManaRegenMult` was last written or whether it was ever different from its current value of 100.

**Branch G-5a / G-2 (rule_values timestamp audit) is definitively closed — null finding.** Cannot determine from DB whether this rule was ever set higher between V1 and V2.

Rely solely on c-expert's git audit of `ruletypes.h` default history. That is the only remaining path to resolve the G-5a carry-forward flag.

Standing by for Round 2.


### 2026-04-29 — lua-expert → architect: Round 1 FORMAL ENUMERATION DELIVERED (18 consumers + critical architectural finding)

lua-expert has now delivered the structured Round 1 enumeration covering all (A)–(H) sections. 18 numbered consumers across 8 categories, with file:line precision throughout. **Substantively closes the Lua side of Round 1** (the L-1/L-2/L-3/L-4 pre-findings are now fully backed by code-grounded enumeration).

**Key new findings from the formal enumeration:**

**Major finding L-5 — `members[]` vs `membername[]` are SEPARATE arrays (load-bearing for Round 2):**

Critical architectural detail surfaced in C.3 (`HandleGroupChatMentions` analysis):
- `Group::members[ci]` is a `Mob*` pointer array
- `Group::membername[ci]` is a `char[64]` string array
- These are SEPARATE arrays in the Group struct

`HandleGroupChatMentions` at `client.cpp:1745-1746` walks `group->members[ci]` (pointer), NOT `membername[ci]` (string). Fix A clears `membername[]` but does NOT touch `members[]`. **Therefore Fix A clearing `membername[]` does NOT break @mention dispatch.**

**Architect interpretation:** This is the answer to my Round 2 carry-forward Q4 to c-expert. Lua-expert has independently traced enough of the Group struct to confirm that the `membername[]` slot Fix A clears is a string-only field. Two implications:

1. **Lua-side L-2 question (whether `owner:GetGroup()` returns non-null with companion still in members[]) is RESOLVED:** The companion's `Mob*` pointer in `members[]` is independent of `membername[]`. Fix A does not affect group-pointer-iteration paths.

2. **Critical architectural question raised by L-5 for Round 2:** "**Does the AoE friend/foe C++ filter use `group->members[ci]` or `group->membername[ci]`? If it uses the string array, Fix A clearing the slot would be a BUG-004 root cause vector."** — **This is the Round 2 question for c-expert.** The lua-expert has flagged a specific branch of the BUG-004 root-cause that c-expert's pre-finding C-2 did not address.

**Major finding L-6 — Lua regression risks are mostly LOW or NONE for the three bugs:**

Of 18 enumerated consumers, only one has HIGH risk relative to V2 changes:
- **B.1 — `dispatch_prefix_command` ownership check** — HIGH if Fix B `Spawn(owner)` doesn't persist `m_owner_char_id` correctly. Every !-command would be rejected with "That is not your companion."

Other risks are LOW or NONE:
- A.2/A.3/A.4 (gsay/buff/commentary timers) — silent drop on `GetOwnerCharacterID()=0` or `GetGroup()=nil`. Cosmetic, not blocking.
- B.2 (response routing) — falls back to `Say()` instead of `GroupMessage()` if group is nil. Cosmetic channel regression.
- B.6 (`!buffs` group scan) — MEDIUM if Fix A broke group membership; companions silently skipped from buff targets.
- C.1 (event_spawn timer setup) — orphaned `comp_commentary_<old_id>` timer from dead entity is pre-existing.
- C.2 (kill tracking) — companion loses recent-kill context after rez (entity vars are fresh on new entity from Fix B). Cosmetic.

**No HIGH-risk Lua consumer for BUG-002, BUG-003, or BUG-004.** All three bugs' Lua-side surfaces are well-defined and bounded.

**Major finding L-7 — Confirming critical negatives (zero Lua involvement):**

- Regen tick rate / mana regen rate — **pure C++, no Lua**
- `m_mana_report_timer` gsay cadence — **pure C++, no Lua**
- AoE friend/foe filter — **pure C++, no Lua mod hook**
- Visibility heartbeat — **pure C++, no Lua**
- `membername[]` string array — **C++ Group struct, not read by any Lua code**

These critical negatives lock the BUG-002 / BUG-003 / BUG-004 root-cause analysis to pure C++ surfaces. **Lua is not a fix-shape consideration for any of the three bugs.**

**Major finding L-8 — Buff regression as indirect BUG-003 vector (F.1):**

Per F.1: if Fix A broke group membership AND the companion's regen rate depends on an active group buff (e.g., regen-boost buffs from `!buffs`), AND `!buffs` fails to re-buff post-rez because of Fix A's group-membership effect, THEN the companion's regen rate could perceptually slow. **This is the only Lua-adjacent path to BUG-003.** Probability: low. But it is enumerable and testable.

**Architect interpretation:** This adds a third candidate to the BUG-003 diagnosis tree:
- (a) Actual server-side regen rate broken (least likely per c-expert C-3 + config-expert G-5)
- (b) Misperception / freshly-rezzed climb from 0 mana (most likely per all advisors)
- (c) **NEW from L-8: Group buff regen-boost regression — `!buffs` fails post-rez because of Fix A's group-membership effect → companion's regen-boosting buff is missing → perceived slow regen.** Test scenario: confirm buff state pre- and post-rez.

This is a perfect example of the V3R Architecture Mandate principle in action: the customized-system enumeration surfaced a non-obvious downstream consumer that the prior V3 plan missed.

**Architect response — Round 1 lua-expert formal enumeration ACCEPTED.** All 18 consumers logged. Findings L-5, L-6, L-7, L-8 supersede the earlier pre-findings reading. Round 1 lua-expert FULLY CLOSED.

**Round 2 question routed to c-expert:** "Does the AoE friend/foe C++ filter (`Mob::IsAttackAllowed` and downstream consumers) use `group->members[ci]` (pointer) or `group->membername[ci]` (string) to identify group members for friend/foe purposes?" If string, Fix A is a BUG-004 vector after all. If pointer, Fix A is irrelevant to BUG-004 (matching c-expert's C-2 verdict).

---

### 2026-04-29 — architect → c-expert: Round 1 Formal Enumeration Query

**From:** architect → **To:** c-expert

Architect requested exhaustive C++ downstream consumer enumeration for all customized companion subsystems touched by V2 changes (Fix A/B/R4/C). Eight subsystem categories requested: spawn pipeline/entity-list registration, AI tick loop, group-membership system, AoE friend/foe filter, death/suspension model, spell target validation, save/load/zone-in, additional customized consumers.

---

### 2026-04-29 — c-expert → architect: Round 1 Full C++ Consumer Enumeration

**From:** c-expert → **To:** architect

Full enumeration delivered: 35 consumers across 8 sections (A–H).

**Section A — Spawn Pipeline / Entity-List (8 consumers):**
`companion_list` vs `npc_list` is the fundamental registration gap Fix B corrects. `AddCompanion()` registers in companion_list + mob_list (NOT npc_list). Pre-V2 `AddNPC()` registered in npc_list + mob_list (NOT companion_list). All companion_list consumers were blind to pre-V2 rezzed entities: `GetCompanionsByOwnerCharacterID`, `AnotherCompanionIsRezzing`, formation slots, XP distribution (attack.cpp:2795), gsay dispatch (client.cpp:1694). Constructor timer initialization starts clean for rez-created entities. `m_owner_char_id` was always set via constructor; no regression.

**Section B — AI Tick Loop (11 consumers):**
- **B.1 (BUG-002 confirmed):** Fix R4 early-return for HP<=0 skips the `m_ping_timer` heartbeat block at companion.cpp:2128-2142.
- **B.2 (NEW FINDING — not in prior V3 plan):** Fix R4 also skips `m_death_despawn_timer.Check()` at companion.cpp:1938. The 30-minute auto-dismiss mechanism is broken for dead companions — timer fires but is never checked because the check is in `Companion::Process()` body after the Fix R4 exit point. `NPC::Process()` has no knowledge of this Companion-specific timer. Dead companions will persist indefinitely rather than auto-dismissing after 30 min. Confidence: 90% broken.
- **B.5/B.6/B.8:** All alive-companion regen and mana-report gsay paths are intact through V2.

**Section C — Group-Membership (8 consumers):**
Fix A (membername[] clear) is correct and necessary. Fix A + Fix B together restore the full rez-to-group pipeline. SplitExp, CastGroupSpell, GroupMessage, IsFriendlyTarget, GroupCount, auto-dismiss-companion-for-player all work correctly with V2.

**Section D — AoE Friend/Foe Filter (8 consumers):**
**BUG-004 root cause confirmed at D.1/H.1.** `EntityList::AESpell()` (effects.cpp:1198-1201) gates detrimental targets on `caster_mob->IsAttackAllowed(current_mob, true)`. Client caster uses `Mob::IsAttackAllowed` base (aggro.cpp:732). `mob2=companion NPC` with `GetOwnerID()=0` (companions never call `SetOwnerID()`). Macro `_NPC(companion)=true`. `_CLIENT vs _NPC` branch returns `true`. **Client IS allowed to attack companion.** Two additional failure modes: `IsPetOwnerOfClientBot()` (D.2) blind to companions; `ST_AreaClientOnly` (D.3) includes companions because `IsOfClientBot()=true`. **BUG-004 is pre-existing, not a V2 regression.** AoE friend/foe filter uses `IsAttackAllowed` (pointer/type logic), NOT `group->membername[]`. Fix A is irrelevant to BUG-004.

**Sections E/F/G/H:** Fix A/C interactions correct. ST_Corpse fixed in V1. All weapon, hate-list, aggro, spawn packet, XP, formation path consumers correct with V2.

**Round 2 flags:**
- Certain V2 regressions: B.1 (heartbeat → BUG-002), B.2 (despawn timer — new finding)
- Pre-existing gaps: D.1/D.2/H.1 (AoE friend/foe → BUG-004)
- Empirical gate required: B.5/B.6/B.8 (alive regen — BUG-003 likely misperception)
- Uncertain: B.2 despawn timer (90% broken; NPC::Process audit needed to confirm)


### 2026-04-29 — data-expert → architect: Round 1 DB enumeration delivered (10 categories + BUG-003 empirical protocol)

data-expert has delivered the complete Round 1 DB-layer enumeration covering all (A)–(J) sections from the original query. Logging the substantive findings:

**Major finding D-1 — companion_data lifecycle (A.1–A.4):**

Four columns matter for V3R triage:
- **A-1 `is_suspended`** — written by ORM Save() and BUG-028 direct UPDATE; read at zone-in by `SpawnCompanionsOnZone()`. **Risk surface:** if rez writes is_suspended=0 but `Spawn()` fails and rollback is incomplete, DB has is_suspended=0 with no in-zone entity → "ghost" companion on next zone-in. (V2 Fix C atomic-rez should mitigate this.)
- **A-2 `cur_mana`** — written at Save()/Death; read at zone-in via `Load()`. **BUG-003 candidate vector:** if companion_data.cur_mana was saved as 0 at death-time, the rezzed companion starts at 0 mana from the DB. **This is normal/expected behavior, but it confirms the most likely BUG-003 explanation: user was watching a freshly-rezzed companion climbing from cur_mana=0** which matches the prior V3 empirical math (~36/tick in 15s gsay window = ~1%/report against a large max_mana pool).
- **A-3 `zone_id/x/y/z`** — fallback only on zone-in; rez spawns at corpse position. Not a V3R bug vector.
- **A-4 `stance`** — read at Load(). If saved stance differs from pre-death, rezzed companion could come back in wrong stance. Cosmetic.

**Major finding D-2 — CRITICAL NULL FINDING: Zero DB persistence for companion group membership (C):**

`group_id` table has NO `companion_id` column. **Companion group membership is entirely reconstructed at runtime** by `SpawnCompanionsOnZone()` → `CompanionJoinClientGroup()`. V2 Fix A clearing `membername[]` at Death is purely in-memory — no DB group row exists to clear.

**Architect interpretation:** This is the answer to a question I had been carrying — whether group membership for companions has any persisted state V2 might have orphaned. Answer: **none.** All group state is in-memory only and reconstructed on each zone-in. This means:
1. The `members[]` vs `membername[]` Group struct fields (lua-expert L-5 finding) are the ONLY group-membership state for companions
2. There is no DB row to corrupt or orphan
3. V2 Fix A's effect is bounded entirely to in-memory `membername[]` slot — no DB-layer downstream consumers

**However,** D-2 raises a different architect concern: **if `CompanionJoinClientGroup()` is not called correctly in the V2 Fix B `Spawn(owner)` rez path, the companion could spawn into the zone but NOT be in the group.** This is a Round 2 cross-reference for c-expert: confirm `CompanionJoinClientGroup()` is called at the correct ordering inside `Spawn(owner)` and that the Group object's `members[]` array is populated post-rez.

**Major finding D-3 — CRITICAL NULL FINDING: Companions do NOT use character_pet_* tables (D):**

Companion system is PARALLEL to the standard pet system, not derived from it.

**This is the DB-layer confirmation of why BUG-004 is broken at the C++ level:** the standard `IsOwnerID()` / `GetPetID()` / `GetOwnerID()` ownership chain that the vanilla AoE filter uses does NOT apply to companions. Companions use `m_owner_char_id` (custom tracking), which `IsAttackAllowed()` does not check.

**Architect interpretation:** Three-advisor convergence on BUG-004 root cause:
- c-expert C-2: traced `_NPC(x) = x->IsNPC() && !x->GetOwnerID()` exclusion fails because companions don't `SetOwnerID()`
- config-expert G-3: independently traced `GetOwner()` requires `GetPetID()==GetID()` which companions don't satisfy
- data-expert D-3: confirmed at DB layer that companions don't use the standard pet tables — the parallel system architecturally explains the gap

**Root cause locked, fix shape options stay α (narrow IsAttackAllowed override) vs β (SetOwnerID).** The three-advisor convergence + config-expert's G-4 precedent (`entity.cpp:5636` `IsCompanion()` exclusion in cone AoE) all argue for **fix shape α**.

**Major finding D-4 — Faction-based AoE exclusion is not viable (E):**

Companion factions are original NPC factions (271 Dismal Rage, 330 Freeport Militia, etc.). There is NO "companion" faction. **An AoE filter that uses faction to identify "friendly" targets would NOT exclude companions.** AoE exclusion must be based on ownership/group membership, not faction. Eliminates one alternative fix path for BUG-004.

**Major finding D-5 — Equipment ordering risk (F):**

72 rows in `companion_inventories`. `LoadEquipment()` must be called AFTER `Spawn(owner)` in the rez path. **Round 2 cross-check for c-expert:** does V2 Fix B's call ordering correctly invoke `LoadEquipment()` after the Spawn? If equipment isn't loaded post-rez, companions rez naked. Not in the V3R bug list but worth a sustained-play validation scenario ("Does a rezzed companion have its gear?").

**Major finding D-6 — `companion_buffs` is empty (G):**

Zero rows. No buff persistence. **Combined with lua-expert L-8** (indirect BUG-003 vector via group-buff regen-boost loss), this confirms that buffs are NOT persisted across Death/rez cycles. So if `!buffs` was casting Spirit of Cheetah / Clarity / regen buffs on companions before death, those are lost at death and must be re-cast post-rez. **L-8's indirect BUG-003 hypothesis is therefore testable:** does a sustained-sit companion that had pre-death regen buffs but lost them at Death now appear to regen "slowly" because the regen-boosting buffs are missing?

**Major finding D-7 — Rules table snapshot confirms config-expert G-5 (H):**

All regen rules at expected defaults:
- `Companions:AlwaysMeditateRegen` = true
- `Companions:CompanionManaRegenMult` = 100
- `Companions:SittingRegenMult` = 200
- `NPC:OOCRegen` = 1
- `Character:ManaRegenMultiplier` = 175

`Pets:AESpellHittingPet` DOES NOT EXIST. No rule controls companion AoE exclusion. No rule controls `m_ping_timer` heartbeat. **Confirms config-expert G-1, G-2, G-5, G-6 verdicts independently from DB side.**

**Major finding D-8 — No schema migrations between V1 and V2 (I):**

V2 was pure C++ changes per architecture.md. No DB migration could have introduced regressions. Confirmed.

**Major finding D-9 — BUG-003 EMPIRICAL MEASUREMENT PROTOCOL (J):**

Per V3R Architecture Mandate 3, this is the gate before any code change for BUG-003. data-expert delivered a concrete protocol:

**SQL polling query (poll every 5s while companion sits):**
```sql
SELECT id, name, cur_mana, UNIX_TIMESTAMP() AS ts
FROM companion_data WHERE owner_id = 6 ORDER BY id;
```

**Expected formula** (level 54 Cleric, meditate=295, AlwaysMeditateRegen=true, ManaRegenMultiplier=175):
- ~63 mana/tick → ~157 mana per 15s gsay report → **~2% of 7907-mana pool per report**

**User observation:** ~1% per report = ~79 mana/15s. **That diverges from formula by ~2×.** Worth investigating empirically.

**Protocol steps:**
1. Run SQL polling + simultaneous gsay observation on **Lashun Novashine (cur_mana=7907, full mana, NOT recently rezzed)** for 2 minutes.
2. **If SQL delta ≈ formula** (~157 mana/15s) **→ gsay report or pool-size discrepancy, NOT actual regen bug.**
3. **If SQL delta < formula** **→ actual regen broken; escalate to C++ investigation of CalcManaRegen path.**
4. **Repeat with a rezzed companion** climbing from 0 mana to compare baselines.

**Architect interpretation — this protocol is COMPLETE and ready to ship in the V3R validation plan.** It directly discriminates between branch (a) actual regen broken vs branch (b) misperception/freshly-rezzed climb. Lua-expert's L-8 branch (c) "indirect via buff loss" is layered on top: include a pre-test verification that the test companion has the SAME buffs in test step 1 as in test step 4 (a rezzed companion that's lost its buffs is the L-8 branch; same buffs eliminates L-8 as a vector).

**Major finding D-10 — Cross-domain shared-root-cause candidate raised by data-expert (architect Round 2 evaluation flagged):**

data-expert proposes a shared-root-cause candidate that the architect must evaluate per V3R Mandate 2 (analyze all three bugs together):

**Hypothesis:** If V2 Fix B's `Spawn(owner)` or Fix A's `membername[]` clear broke the `CompanionJoinClientGroup()` call chain — leaving the Group object's `members[]` array WITHOUT the rezzed companion — then a single failure could explain ALL THREE bugs:

- **BUG-004** — AoE filter checks group membership → companion not in group → IsAttackAllowed returns true for player vs companion
- **BUG-003** — group-based regen bonuses → companion not in group → reduced regen
- **BUG-002** — c-expert has identified Fix R4 as the BUG-002 root cause, but if group membership state also affects visibility/AI-tick behavior, both could contribute

**Architect verdict on D-10:** The hypothesis is not fully refuted but is partially refuted by other advisor findings:

- BUG-002 — locked to Fix R4 (c-expert C-1 + protocol-agent P-1 two-advisor convergence; root cause is the dead-entity early-return skipping `m_ping_timer` heartbeat, which has nothing to do with group membership). The data-expert's "if group membership state also affects visibility" branch is not supported by any advisor's evidence.
- BUG-004 — c-expert C-2 + config-expert G-3 + data-expert D-3 three-advisor convergence on `_NPC(x) = x->IsNPC() && !x->GetOwnerID()` matrix gap. **Group membership is NOT what `_NPC(x)` consults** — it consults the entity's standalone `GetOwnerID()` (zero for companions). So even if `CompanionJoinClientGroup()` succeeds and the companion IS in `members[]`, `_NPC(x)` still returns true and the AoE still hits.
  - However: **lua-expert L-5 question to c-expert (just routed) is the unresolved branch.** If `Mob::IsAttackAllowed` calls a SEPARATE group-membership check that consults `members[]`, and that check fires BEFORE the `_NPC(x)` matrix, then group membership IS load-bearing for BUG-004 root cause AND data-expert's D-10 hypothesis is partially correct. This is exactly what I just asked c-expert to confirm.
- BUG-003 — three independent advisor reads (c-expert C-3, lua-expert L-1, protocol-agent P-3) converge on misperception. data-expert's D-9 protocol is the empirical gate. **L-8's indirect-via-buff-loss branch is the only group-membership angle to BUG-003**, and it's enumerable via the protocol step 4.

**Architect Round 2 working summary so far:**

The three-bugs-share-a-root-cause hypothesis is mostly refuted, but ONE branch remains open:
- **Open branch:** Does `Mob::IsAttackAllowed` call an `IsGroupMember`-style check using `members[]`? If yes, Fix A could be a secondary BUG-004 vector during the dead-then-rezzed window.
- **Resolution gate:** c-expert's response to my L-5 routed question.

**Architect response — Round 1 data-expert ACCEPTED. All 10 categories logged. D-10 hypothesis evaluated and 90% refuted, with one remaining branch tied to c-expert's L-5 confirmation.**

**Net advisor count so far:** 3 of 5 fully closed (lua-expert, config-expert, data-expert). Awaiting c-expert formal enumeration (with L-5 cross-check) and protocol-agent formal enumeration.


### 2026-04-29 — config-expert → architect: Round 1 EXPANDED enumeration delivered (47 Companions:* rules + I.1 RULE-ONLY BUG-003 FIX HYPOTHESIS)

config-expert delivered the structured Round 1 enumeration covering all (A)–(I) sections. **This response substantially expands the earlier G-1/G-7 findings and surfaces a rule-only fix path for BUG-003 that no other advisor identified.** Logging the substantive new findings:

**Major finding G-8 — 47 `Companions:*` rules enumerated, all at expected values except 2:**

Two `Companions:*` rules are at non-default values (intentional tuning, not misconfigurations):
- `Companions:LevelRange = 50` (default 3) — per-server tuning, opens recruitment to wider level range
- `Companions:BaseRecruitChance = 100` (default 50) — per-server tuning, makes recruitment always succeed

All 45 other `Companions:*` rules are at expected defaults. None of the regen-related rules (`HPRegenPerTic`, `CompanionManaRegenMult`, `OOCRegenPct`, `SittingRegenMult`, `AlwaysMeditateRegen`) are misconfigured. Confirms G-5.

**Major finding G-9 — `NPC:OOCRegen` is NON-DEFAULT on this server (D.5):**

`NPC:OOCRegen` is set to `1` on the active ruleset (`ruleset_id=1`), versus default `0` on `ruleset_id=10` (EQEmu_Default). **This server has NPC OOC regen ENABLED.**

This is significant. It applies to ALL NPCs, including companions, BEFORE the custom `Companions:*` regen logic. The interaction with `Companions:OOCRegenPct=5` and `Companions:HPRegenPerTic=1` depends on C++ code execution order. **Round 2 cross-reference for c-expert:** confirm whether companions hit the base `NPC:OOCRegen=1` path (which would give them ~1 HP/tick baseline) vs the custom `Companions:OOCRegenPct=5` path (which would give them 5% of max HP per tick). If V2 changed which path companions exercise, that's a real code regression worth investigating.

**Major finding G-10 — `Character:HPRegenMultiplier=200` and `Character:ManaRegenMultiplier=175` are NON-DEFAULT (E.1, E.2) — RULE-ONLY BUG-003 FIX HYPOTHESIS:**

This is the key finding. The server has the player's regen multiplied:
- `Character:HPRegenMultiplier = 200` (2x player HP regen)
- `Character:ManaRegenMultiplier = 175` (1.75x player mana regen)

**These rules apply to client characters (the player), NOT to NPCs/companions.** Companions have their own multiplier `Companions:CompanionManaRegenMult = 100` (no scaling).

**Therefore the player gets 1.75x mana regen, but companions get base mana regen.** This is a TUNING DIVERGENCE, not a V2 regression. As the player's regen multiplier was tuned higher over time without a matching companion multiplier adjustment, the perception gap widened. The user's "back to being extremely slow" report may be the long-term cumulative effect of this divergence, finally noticed in the post-V2 sustained-play context.

**Architect interpretation — this is the most important Round 1 finding so far for BUG-003:**

The L-8 branch (indirect via buff loss) and the misperception branch (climb-from-zero) were the two leading hypotheses. **G-10 introduces a third, stronger hypothesis: rule-tuning divergence.** It's stronger because:
1. It is testable WITHOUT any code change — just bump `Companions:CompanionManaRegenMult` to 175 and `#reloadrules`
2. It explains "back to being extremely slow" not as a regression but as a long-standing gap that became visible
3. It is empirically falsifiable in the same SQL polling protocol data-expert proposed in D-9

**Major finding G-11 — Rule-only diagnostic protocol for BUG-003 (I.1):**

config-expert proposes a structured rule-only diagnostic that complements data-expert's D-9 SQL polling:

**Step 1:** Bump `Companions:CompanionManaRegenMult` from 100 to 175. Run `#reloadrules`. Test sustained-sit companion mana cadence:
- If gsay-reported mana increments become comparable to the player's → BUG-003 is a rule-tuning issue, not a code regression
- If regen is still slow → companion is not exercising the `CompanionManaRegenMult` path; that's a code regression

**Step 2 (secondary diagnostic):** Set `NPC:OOCRegen` to 0. Run `#reloadrules`. Observe companion HP regen:
- If companion HP regen drops to zero → companions are on the base NPC regen path, not the custom `Companions:OOCRegenPct` path; V2 may have routed them through the wrong path
- If companion HP regen unchanged → companions are correctly on the custom path

**Architect interpretation:** This protocol becomes part of the BUG-003 empirical-first workflow alongside data-expert's D-9 SQL polling. Combined plan:

1. **Pre-test:** Run data-expert's D-9 SQL polling + gsay observation on a stable, full-mana, non-rezzed companion (Lashun Novashine) — establishes baseline for the formula vs observed comparison
2. **G-11 Step 1:** Bump `Companions:CompanionManaRegenMult` to 175, `#reloadrules`, repeat measurement
3. **Compare:** if mana regen rate scales 1.75x with the rule bump, confirm rule-tuning divergence is the cause. **No code change needed.**
4. **G-11 Step 2:** if Step 1 doesn't help, toggle `NPC:OOCRegen` to differentiate code paths
5. **Only if both rule diagnostics fail:** escalate to actual C++ regen-path investigation

**Major finding G-12 — Confirmed non-existent rules:**

- `Pets:AESpellHittingPet` — DOES NOT EXIST
- `Spells:AEHateOwner` — DOES NOT EXIST
- `Spells:AESpellHittingPet` — DOES NOT EXIST
- All `Group:*` rules — category has ZERO entries in ruletypes.h

Eliminates these as fix candidates. BUG-004 has no rule-only fix path; pure C++ change is required.

**Major finding G-13 — `Range:ClientPositionUpdates=300` does NOT control heartbeat (E.8):**

The `Range:ClientPositionUpdates` rule controls the distance at which a CLIENT's MOVING position is communicated to other clients. **It does NOT control the heartbeat for stationary mobs.** The `m_ping_timer(5000)` heartbeat is C++ hardcoded with no rule lever. Eliminates this as a confounding variable for BUG-002.

---

**Architect Round 1 reframing for BUG-003:**

The BUG-003 diagnosis tree has now grown to FOUR branches:
- **(a) Actual server-side regen rate broken** — ranked LOW probability per c-expert C-3 (regen path unchanged) and config-expert G-5 (rule values correct)
- **(b) Misperception / freshly-rezzed climb from 0 mana** — possible per data-expert D-1 + the empirical formula vs observed numerical discrepancy of ~2×
- **(c) Indirect via buff loss** (lua-expert L-8) — testable via L-8 protocol step 3
- **(d) NEW: Rule-tuning divergence** (config-expert G-10) — strongest hypothesis; the player has 1.75x mana regen multiplier while companions are at 1.0x (no scaling); growing gap interpreted as regression

**Branch (d) supersedes branch (b) as the leading hypothesis for "back to being extremely slow"** — the user's verbatim report says "back to being extremely slow, like 1% every report" which implies a previously-known bug that had been fixed. If the prior fix was a temporary `Companions:CompanionManaRegenMult` bump that was reset (via server restart, ruleset reload, or migration), G-10 directly explains the "back to" framing.

**Round 2 fork question for the architect:** does the V3R fix scope include a rule-only BUG-003 hypothesis test, OR are we deferring all BUG-003 work to a follow-up bugfix per the prior V3 plan's V3.6 architect decision pattern? Per V3R Mandate 3 (empirical-first), the answer is: include the empirical test in the V3R validation plan; if the rule-only test confirms G-10, the BUG-003 "fix" is a one-line UPDATE in `rule_values` and no code change is needed.

**Architect response — Round 1 config-expert FULLY CLOSED.** Round 1 deliverables are complete. Findings G-8 through G-13 logged.

**Net advisor count so far:** 4 of 5 fully closed (lua-expert, config-expert FULLY now, data-expert). c-expert formal enumeration outstanding (with L-5 cross-check). protocol-agent formal enumeration outstanding.


---

### 2026-04-29 — data-expert → architect: V3R-Empirical-1 scenario refined + GM mechanism clarified

**From:** data-expert → **To:** architect

**Re: Finalized game-tester scenario for BUG-003 empirical discrimination**

---

**CRITICAL CORRECTION TO D-9 PROTOCOL: SQL polling of `companion_data.cur_mana` is NOT viable for real-time regen measurement.**

From source: `Companion::Save()` at `companion.cpp:2841` writes `cur_mana = GetMana()` — but `Save()` is only called at lifecycle events:
- `companion.cpp:687` — Death()
- `companion.cpp:1962` — auto-dismiss path
- `companion.cpp:2497` / `companion.cpp:2554` / `companion.cpp:2617` — Suspend(), zone-out, dismiss
- `companion.cpp:3520` — rez complete

`Save()` is NOT called on regen ticks. Between lifecycle events, `cur_mana` in the DB is stale — it reflects the last save point, not the live in-memory value. Polling `companion_data.cur_mana` between save events returns the same value every time. **The D-9 SQL polling protocol would show NO delta during a sustained sit session unless a Save() event fires.**

**GM mana manipulation mechanism (confirmed from source):**

`#set mana [Amount]` (`set_mana.cpp:3-40`) works on ANY targeted Mob, including NPC companions:
- With no target: sets caller's mana
- With companion targeted: calls `t->SetMana(mana)` — sets live in-memory mana immediately
- `#set mana 0` → companion starts at 0 mana in-memory (no zone/save needed)
- `#set mana_full` / `#mana` → fills companion to max mana in-memory

**No `#set mana [Amount]` command was in the GM reference doc — this is a now-confirmed addition:** `#set mana [N]` works with a numeric argument to set to a specific value. `#mana` only fills to full.

---

**FINALIZED SCENARIO: V3R-Empirical-1: BUG-003 mana regen rate discriminator**

```
Scenario V3R-Empirical-1: BUG-003 mana regen rate discriminator

Purpose:
  Definitively distinguish "actual regen rate is broken" from "gsay reporting
  cadence is broken" or "user was watching a rezzed companion climbing from 0."

Pre-conditions:
  - Test character (owner, char_id=6) is in a safe zone with no active combat
  - All 5 companions present and alive
  - Lashun Novashine (id=24, class=Cleric, level=54) is the primary test subject
    (she was NOT recently rezzed, so no post-rez artifact)
  - Companion is in a safe zone, sitting, not engaged
  - Player is sitting nearby, not engaged
  - Buff state: note current buffs on Lashun via !status before each test;
    if !buffs have been cast pre-test, record which; do NOT strip buffs (this
    is a live measurement of actual behavior, not a controlled-isolation test)
  - Second terminal open with DB access for lifecycle-event confirmation

IMPORTANT MEASUREMENT NOTE:
  companion_data.cur_mana is NOT updated on regen ticks. It is only written
  at lifecycle events (Death, zone-out, Suspend, Dismiss). SQL polling during
  a sit session will return the same value continuously. The primary measurement
  source is gsay output + in-game observation only.

  SQL is used ONLY for:
  (a) Pre-test mana state confirmation (snapshot at test start)
  (b) Post-test mana state confirmation (after triggering a Save() by briefly
      having the companion zone or dismiss + re-recruit, or by killing and
      unsuspending — but this disrupts the test)
  (c) Confirming the baseline cur_mana before and after the session

  ALTERNATIVE MEASUREMENT APPROACH: Use !status command on Lashun at timed
  intervals (every 30s) to capture in-game HP/mana values — this reads
  in-memory mana (GetMana()), not the DB snapshot. Log the values manually.

Test 1 — Full-mana baseline (non-rezzed):

  Step 1: Target Lashun Novashine. Run: #set mana_full
          Verify via !status that mana is at maximum.
  Step 2: Have Lashun sit: @Lashun_Novashine !sit  (or confirm she is sitting)
  Step 3: Note current time (T0).
  Step 4: Wait 15 seconds. Record gsay mana report #1 (mana%, HP%).
  Step 5: Run !status on Lashun. Record in-game mana value.
  Step 6: Wait 15 seconds. Record gsay report #2.
  Step 7: Run !status. Record.
  Step 8: Repeat for 4 full gsay cycles (60 seconds total).

  Expected (formula): level 54 Cleric, AlwaysMeditateRegen=true,
    ManaRegenMultiplier=175, CompanionManaRegenMult=100
    final_regen ≈ 36/tick × 1.75 = ~63 mana/tick
    15s gsay cadence = ~2.5 ticks × 63 ≈ ~157 mana/report
    Lashun max_mana: check via !status (unknown until in-game, DB shows 0)
    As a %, estimate: if max_mana ≈ 7907 (cur_mana saved in DB), then
    157/7907 ≈ 2% per report is expected.

  Record: mana value at each !status, mana% from each gsay report.

  PASS criteria: mana increases by ≥100 mana per gsay report → actual regen
    is working; "1%/report" user report was from a rezzed companion or small pool.
  FAIL criteria: mana increases by ≤50 mana per gsay report on a 7000+ mana
    pool → actual regen is genuinely slow; escalate to c-expert.

Test 2 — Drain-and-climb baseline (non-rezzed, low mana):

  Step 1: Target Lashun Novashine. Run: #set mana 0
          Verify via !status that mana = 0.
  Step 2: Have Lashun sit (same as Test 1).
  Step 3: Begin 60-second observation (same procedure as Test 1 — 4 gsay cycles).
  Step 4: Record mana at each !status and each gsay report.

  This simulates the "rezzed companion at 0 mana" scenario WITHOUT a rez.
  If Test 2 shows the same regen rate as Test 1 → climbing from 0 is NOT slower,
    BUG-003 report was misperception.
  If Test 2 shows noticeably slower regen than Test 1 → there is a mana-at-zero
    initialization issue; escalate to c-expert.

Test 3 — Post-rez baseline (Jimble Woodentoe or Lashun after kill+rez):

  Step 1: Use #kill on Jimble Woodentoe (Cleric, currently is_suspended=1).
          Alternatively unsuspend Jimble first: @all !unsuspend or via SQL
          (UPDATE companion_data SET is_suspended=0 WHERE id=22).
  Step 2: After rez fires (wait up to 30s post-combat), confirm Jimble is alive.
  Step 3: Have Jimble sit. Run same 4-cycle observation.
  Step 4: Compare Jimble's per-report mana gain to Test 2 (same starting state
          of 0 mana, same class level). They should match if there is no rez-path
          regression.

  If Test 3 regen rate < Test 2 regen rate → rez path leaves companion in a
    degraded regen state; escalate to c-expert as a rez-path regression.
  If Test 3 ≈ Test 2 → rez path is fine; BUG-003 is misperception.

Optional Test 4 — L-8 branch (buff-state contribution):

  Step 1: Strip Lashun's buffs: #buff None (if command exists) or wait for
          natural buff expiry.
  Step 2: Repeat Test 1. Compare regen rate to Test 1 with buffs.
  If regen rate differs significantly: buff loss on rez is a contributing factor.
  Flag for c-expert: which regen-boosting buff was Lashun carrying pre-test?

Pass/Fail Summary:
  Branch A (actual regen broken):
    Test 1 SQL-confirmed mana increment < 80 mana/15s on 7000+ mana pool
    → real regression; escalate to c-expert CalcManaRegen investigation.
  Branch B (climb-from-zero misperception):
    Test 1 increment ≥ 100 mana/15s AND Test 2 increment ≈ Test 1
    → BUG-003 is misperception; close with runbook note.
  Branch C (rez-path degraded regen):
    Test 1 and Test 2 OK, but Test 3 increment < Test 2
    → rez path regression; escalate to c-expert.
  Branch D (buff loss contributing):
    Test 4 shows meaningfully lower regen than Test 1
    → buff loss on rez is a secondary factor; escalate to lua-expert (L-8 branch).
```

**SQL confirmations (lifecycle-event-gated, not real-time polls):**
```sql
-- Pre-test: confirm starting state
SELECT id, name, cur_mana, cur_hp, is_suspended
FROM companion_data WHERE owner_id = 6 ORDER BY id;

-- Post-test (after a Save() trigger such as a brief zone or !dismiss):
-- Run the same query to see if cur_mana was updated.
-- Only meaningful as a sanity check, not as a real-time metric.
```

**Jimble unsuspend SQL (if needed to run Test 3):**
```sql
UPDATE companion_data SET is_suspended=0 WHERE id=22;
```
Then `/reload zone` or have the player zone and return to re-trigger `SpawnCompanionsOnZone()`.


---

### 2026-04-29 — protocol-agent → architect: Round 1 Formal Enumeration Response

**From:** protocol-agent → **To:** architect

Full source-grounded enumeration. All file:line citations verified against the current `bugfix/companion-rez` codebase. 26 consumers across 7 areas (A–G).

---

## A. Position-Update / Visibility Heartbeat

### A.1 — `OP_ClientUpdate` keepalive heartbeat (`companion.cpp:2128-2142`)
- **Wire format:** `PlayerPositionUpdateServer_Struct` (24 bytes, bitfield-packed; `eq_packet_structs.h:1392`). Built by `Mob::SentPositionPacket()` (`mob.cpp:1714`), broadcast via `entity_list.QueueClients(this, &outapp, false, false)`.
- **Server-side state feeding it:** `m_ping_timer` (5-second Timer). When `!IsMoving()`, arms at line 2136, fires at line 2139, sends `SentPositionPacket(0.0f,0.0f,0.0f,0.0f,0)` — zero-delta at current position. Disabled on movement (line 2134).
- **Regression mode if broken:** Titanium culls entity from render set within ~5-10 seconds of last `OP_ClientUpdate`. Companion vanishes mid-combat with no death animation. **BUG-002 verbatim.**
- **V2 touchpoint:** Fix R4 (`companion.cpp:1933-1935`) — `if (GetHP() <= 0) return;` fires BEFORE heartbeat block at lines 2128-2142. Dead companions never send the keepalive. **Confirmed BUG-002 mechanism.** Alive companions: Fix R4 does not trigger; heartbeat fires normally.

### A.2 — `OP_NewSpawn` via `EntityList::AddCompanion()` (`entity.cpp:4062-4066`)
- **Wire format:** `NewSpawn_Struct` (385+ bytes). Sent immediately via `QueueClients(new_companion, outapp, true)`.
- **Server-side state feeding it:** `Companion::FillSpawnStruct()` (`companion.cpp:2347-2358`) overrides: `spawn.is_npc=0`, `spawn.is_pet=0`, `spawn.NPC=0`. Makes companion appear player-like to Titanium.
- **Regression mode if broken:** If override skipped, Titanium receives `NPC=1` — hostile-NPC rendering, group-window targeting fails.
- **V2 touchpoint:** Fix B routes rez through `Spawn(owner)→AddCompanion`. Pre-V2 `AddNPC` bypassed this override (sent `NPC=1`). **Fix B is a protocol correctness improvement.**

### A.3 — Missing `SendArmorAppearance()` in `AddCompanion` — FLAGGED GAP (`entity.cpp:737` vs `entity.cpp:4047-4076`)
- **Wire format:** `OP_WearChange` packets (one per equipment slot). `AddNPC()` at `entity.cpp:737` calls `npc->SendArmorAppearance()` after the spawn packet. `AddCompanion()` does NOT.
- **Server-side state feeding it:** Equipment material slots via `GetEquipmentMaterial()`.
- **Regression mode if broken:** Companion renders naked/default appearance after rez. Equipment visuals absent.
- **V2 touchpoint:** Fix B (indirect) — pre-V2 `AddNPC` called `SendArmorAppearance`; Fix B's `AddCompanion` does not. **C-expert to confirm whether `ResurrectFromCorpse` handles this elsewhere after `Spawn()` returns.**

### A.4 — `SendPositionToClients()` comparison (`entity.cpp:758` vs `entity.cpp:4062-4066`)
- **Wire format:** `OP_ClientUpdate` / `PlayerPositionUpdateServer_Struct`.
- **Regression mode if broken:** Late-joining clients may miss initial position. In practice, `AddCompanion` sends a full `NewSpawn_Struct` with position fields included — position IS in the spawn packet. **Not broken by V2.**
- **V2 touchpoint:** None.

---

## B. Group / Raid / Party Display Packets

### B.1 — `OP_GroupUpdate` / `GroupJoin_Struct` (`groups.cpp:299-337`)
- **Wire format:** `GroupJoin_Struct` (452 bytes), action=`groupActJoin`. Carries new member's `membername` and each existing member's `yourname`. Writes `GetPP().groupMembers[i]` for each in-zone client.
- **Server-side state feeding it:** `Group::AddMember()` writes `membername[slot_id]` from `new_member->GetCleanName()`, broadcasts to existing members. Called from `CompanionJoinClientGroup()` at `companion.cpp:2684` (new group) and `2720` (existing group).
- **Regression mode if broken:** Companion absent from Titanium group window. Group HP bars invisible. Click-to-target via group window tile fails.
- **V2 touchpoint:** Fix A clears `membername[i]` at death — prerequisite for re-add. Fix B routes rez through `CompanionJoinClientGroup→AddMember` → sends `OP_GroupUpdate(groupActJoin)`. **Both fixes are load-bearing.** If `CompanionJoinClientGroup` fails post-rez, group window stays empty.

### B.2 — `OP_GroupUpdate` leave / `MemberZoned` at death (`companion.cpp:716`)
- **Wire format:** `Group::MemberZoned()` NULLs `members[i]` but does NOT send `groupActLeave`. No client leave-packet on companion death.
- **Regression mode if broken:** Titanium group window may show dead companion's slot occupied/greyed. Cosmetic.
- **V2 touchpoint:** Fix A clears `membername[i]` to restore capacity — consistent with Bot::Death(). **Not a V2 regression.**

### B.3 — `OP_GroupUpdate` / `GroupUpdate_Struct` full roster (`groups.cpp:993-1035`)
- **Wire format:** `GroupUpdate_Struct` (452 bytes), action=`groupActUpdate`. Full `membername[6][64]` array. Serialized into `PlayerProfile_Struct.groupMembers` at zone-in.
- **Regression mode if broken:** Zone-in with stale `PlayerProfile_Struct.groupMembers` → empty group window slot. Fix A+B maintain correct state. **Not a regression.**

### B.4 — `ServerOP_GroupJoin` cross-zone (`groups.cpp:639-658`)
- **Wire format:** `ServerGroupJoin_Struct` on zone↔world TCP. Rarely relevant for single-zone server.
- **V2 touchpoint:** None. `CompanionJoinClientGroup` correctly calls `SendGroupJoinOOZ`.

---

## C. AoE Spell Target Packets

### C.1 — `caster_mob->IsAttackAllowed(current_mob, true)` in AoE sweep (`effects.cpp:1199`)
- **Wire format:** Server-side predicate controlling `OP_Damage` emission per AoE target. Titanium does NOT independently compute AoE target lists.
- **Server-side state feeding it:** `Client` has no `IsAttackAllowed` override → `Mob::IsAttackAllowed` (`aggro.cpp:732`). Key: `_NPC(x)` = `x->IsNPC() && !x->GetOwnerID()` (`common.h:15`). Companions: `IsNPC()=true` (inherit from NPC), `GetOwnerID()=0` (use `m_owner_char_id`, NOT `SetOwnerID()`). So `_NPC(companion)=true`. The `_CLIENT vs _NPC` branch at `aggro.cpp:867` returns `true` unconditionally. `Companion::IsAttackAllowed` override (`companion.cpp:832`) would return `false` via `IsFriendlyTarget()`, but only fires when the COMPANION is the caster — not a Client.
- **Regression mode if broken:** Player detrimental AoE spells hit own companions. **BUG-004 verbatim.**
- **V2 touchpoint:** Pre-existing gap in `_NPC()` macro. **Key open question (tied to architect's L-5 / c-expert gate):** did the pre-V2 manual `AddNPC` path call `SetOwnerID()` on companions? If yes → `_NPC(companion)=false` pre-V2 → AoE excluded companions → Fix B (removing `SetOwnerID()`) made this a V2 regression. If no → pre-existing gap, perhaps now consistently reproduced post-rez after Fix B. C-expert must confirm.

### C.2 — `OP_Damage` / `CombatDamage_Struct` AoE delivery (`eq_packet_structs.h:1335`)
- **Wire format:** ~23 bytes: target entity ID, source, spell ID, damage, type.
- **Regression mode:** Companion receives `OP_Damage` — player sees companion debuffed/stunned. Symptom of C.1.
- **V2 touchpoint:** Same as C.1.

### C.3 — `ST_TargetAENoPlayersPets` skip: `IsPetOwnerOfClientBot()` (`effects.cpp:1143`)
- **Wire format:** Skip predicate only. `IsPetOwnerOfClientBot()` = `pet_owner_bot || pet_owner_client`. Companions use `m_owner_char_id` — `pet_owner_client=false`. Companions NOT skipped by this filter. Secondary pre-existing gap; most player AoE spells use `ST_AE` gated by `IsAttackAllowed` (C.1).
- **V2 touchpoint:** None. Pre-existing.

---

## D. Mana / HP Update Packets

### D.1 — `OP_MobHealth` / `SpawnHPUpdate_Struct2` (`mob.cpp:1489-1596`)
- **Wire format:** 3 bytes: `spawn_id` (uint16) + `hp` (uint8, 0-100%). Distribution: targeted clients, x-targeted clients, group HP AA path, `group->SendHPPacketsFrom(this)` (gated on `IsGrouped()`). The pet-owner path (`GetOwner()->IsClient()`) does NOT fire for companions — `GetOwner()` returns null when `ownerid=0`.
- **Server-side state feeding it:** `GetHPRatio()`. Group path requires `IsGrouped()=true`.
- **Regression mode (D.1a):** `IsGrouped()=false` post-rez → group HP bar stale for untargeted companions.
- **Regression mode (D.1b):** Fix R4 skips `Process()` for dead companions → `SendHPUpdate` not called. Correct behavior.
- **V2 touchpoint:** Fix A+B maintain group membership through death→rez. **Load-bearing for group HP bar visibility.**

### D.2 — Mana: no NPC mana packet for group display
- `OP_ManaChange` is client-to-server and client self-update only. No NPC mana broadcast exists. Titanium group window does not show companion mana bars. BUG-003 is entirely driven by gsay. **No protocol angle.**

### D.3 — `OP_ChannelMessage` gsay mana report (`companion.cpp:2163-2168`)
- **Wire format:** `ChannelMessage_Struct` (144+ bytes, group-say). Reports `GetManaRatio()` live at call time.
- **Server-side state feeding it:** `m_mana_report_timer` (15-second Timer). Gated on `IsSitting() && !IsEngaged()`. For alive companions, this is BELOW Fix R4's HP<=0 threshold.
- **Regression mode if broken:** If actual regen is slow (freshly-rezzed companion at 0 mana, large max_mana), `GetManaRatio()` genuinely returns ~1% per tick. Not a cadence problem — an actual-regen-rate problem. Empirical SQL measurement required.
- **V2 touchpoint:** Fix R4 correctly silences dead companions. **Not a regression for alive companions.**

---

## E. Pet / Companion Identification Packets

### E.1 — `Spawn_Struct.NPC`, `is_pet`, `petOwnerId` (`mob.cpp:1316-1321`, `eq_packet_structs.h:217-267`)
- **Wire format:** `NPC=0`, `is_pet=0`, `petOwnerId=ownerid=0` for companions. Standard summoned pets: `NPC=1`, `is_pet=1`, `petOwnerId=owner_entity_id`.
- **Server-side state feeding it:** `Companion::FillSpawnStruct` overrides (`companion.cpp:2355-2357`). `petOwnerId=ownerid` where `ownerid=GetOwnerID()=0`.
- **Regression mode if broken:** `NPC=0` correct for group window. `petOwnerId=0` → `GetOwnerID()=0` → `_NPC(companion)=true` → BUG-004.
- **V2 touchpoint:** Fix B IMPROVED `NPC=0` on rez path. `petOwnerId=0` is unchanged pre-existing.

### E.2 — `OP_PetCommands` / `OP_Charm` — not applicable
Companion system does not use pet control channel. V2 touchpoint: none.

### E.3 — `OP_SpawnAppearance` sit/stand state
- **Wire format:** `SpawnAppearance_Struct` (~8 bytes). Sent on sit/stand transitions.
- **Regression mode:** Cosmetic animation state. Fix R4 correctly silences dead companions.
- **V2 touchpoint:** Fix R4 silences for dead (correct).

---

## F. Spawn-Struct Fields

### F.1 — `petOwnerId=0` wire field (`mob.cpp:1321`)
- Always 0 for companions (pre- and post-V2). **Wire-format manifestation of the BUG-004 `_NPC()` macro gap.** Pre-existing design choice.
- **V2 touchpoint:** None.

### F.2-F.4 — `NPC=0`, `is_pet=0`, name normalization
- All improved by Fix B on the rez path. Protocol correctness gains, not regressions.

---

## G. Titanium-Specific Constraints

### G.1 — Entity culling: ~5-10 second stationary timeout
- Titanium drops entity from render set after ~5-10 seconds without `OP_ClientUpdate`. Fix R4 stops heartbeat for dead companions → Titanium culls → **BUG-002**.

### G.2 — Group window: 6-member fixed capacity
- Fix A's `membername[i]` clear at death restores the slot so rez `AddMember` succeeds. **Load-bearing.**

### G.3 — Spawn name must equal `GetCleanName()`
- Fix B's name normalization in `Companion::Spawn()` ensures group window click-to-target works on rez path.

### G.4 — No client-side AoE friend/foe filtering
- Titanium does NOT compute AoE target lists. BUG-004 is 100% server-side. No Titanium protocol changes possible or needed.

### G.5 — No client-side mana interpolation for NPCs
- Titanium does not display NPC/companion mana. BUG-003 is entirely driven by C++ gsay. No client mechanism to investigate.

### G.6 — `PlayerProfile_Struct.groupMembers` at zone-in
- Populated from `Group::membername[]`. Fix A+B maintain correct state through death→rez cycle.

---

## Summary Table (26 consumers)

| ID | Packet / Predicate | Bug candidate | V2 touchpoint | Status |
|----|--------------------|---------------|---------------|--------|
| A.1 | `OP_ClientUpdate` heartbeat (`companion.cpp:2128`) | **BUG-002** | Fix R4 bypasses | V2-introduced regression |
| A.2 | `OP_NewSpawn` / NPC=0 | — | Fix B improved | Fix B protocol gain |
| A.3 | `SendArmorAppearance` missing in `AddCompanion` | Cosmetic rez visual | Fix B indirect gap | **Gap — c-expert to confirm** |
| A.4 | `SendPositionToClients` | — | None | Not broken |
| B.1 | `OP_GroupUpdate` join (`groups.cpp:299`) | Group window coherency | Fix A+B load-bearing | Correct |
| B.2 | `OP_GroupUpdate` leave | HUD cosmetic at death | Fix A correct | Not regression |
| B.3 | `GroupUpdate_Struct` full roster | Zone-in group window | Fix A+B correct | Not regression |
| B.4 | `ServerOP_GroupJoin` | Cross-zone | None | Not affected |
| C.1 | `IsAttackAllowed` in `AESpell` (`effects.cpp:1199`) | **BUG-004** | Pre-existing; Fix B may have exposed — **c-expert L-5 gate** | Pre-existing gap |
| C.2 | `OP_Damage` (AoE hits) | BUG-004 symptom | Same as C.1 | Same |
| C.3 | `IsPetOwnerOfClientBot` skip | — | None | Pre-existing secondary gap |
| D.1 | `OP_MobHealth` HP broadcast | Group HP bar | Fix A+B load-bearing | Correct if group join succeeds |
| D.2 | Mana packet | — | None | No NPC mana packet exists |
| D.3 | `OP_ChannelMessage` gsay (`companion.cpp:2163`) | **BUG-003** (perception) | Fix R4 silences dead (correct) | Not regression for alive |
| E.1 | `NPC/is_pet/petOwnerId` spawn fields | BUG-004 wire root + identity | Fix B improved NPC field; petOwnerId=0 pre-existing | Fix B gain; petOwnerId gap pre-existing |
| E.2 | `OP_PetCommands` | — | None | Not applicable |
| E.3 | `OP_SpawnAppearance` sit/stand | Cosmetic | Fix R4 silences dead (correct) | Not behavioral regression |
| F.1 | `petOwnerId=0` wire field | BUG-004 wire manifestation | Pre-existing | Pre-existing design |
| F.2-F.4 | NPC=0, is_pet=0, name normalization | Protocol correctness | Fix B improvements | Fix B gains |
| G.1 | Titanium ~5-10s entity culling | BUG-002 client mechanism | Fix R4 stops heartbeat | V2-introduced regression |
| G.2 | Group window 6-member cap | Group capacity | Fix A required | Fix A load-bearing |
| G.3 | Spawn name = GetCleanName() | Group targeting | Fix B corrected | Fix B gain |
| G.4 | No client-side AoE filter | BUG-004 scope clarification | N/A | Protocol design constraint |
| G.5 | No client mana interpolation | BUG-003 scope clarification | N/A | Protocol design constraint |
| G.6 | `PlayerProfile_Struct.groupMembers` | Zone-in group window | Fix A+B correct | Correct |

---

**Protocol-layer conclusions for architect's Round 2:**

1. **BUG-002:** Fix R4 blanket early-return at `companion.cpp:1933-1935` bypasses `m_ping_timer` heartbeat at lines 2128-2142. Fix V Option A (`bool is_dead` restructure) addresses this at the correct site. No Titanium protocol changes needed.

2. **BUG-004:** Root cause is `Mob::IsAttackAllowed` (`aggro.cpp:867`) returning `true` for Client-vs-companion because `_NPC(companion)=true` when `GetOwnerID()=0`. Fix is purely server-side. Open question (c-expert L-5): did pre-V2 companion setup ever call `SetOwnerID()`? If yes → V2 regression; if no → pre-existing. No Titanium protocol changes needed or possible.

3. **BUG-003:** Zero protocol-layer diagnostic signal. Gsay cadence (15s) and `GetManaRatio()` are live server-side reads unchanged by V2. Empirical SQL measurement is the definitive gate.

4. **Gap flagged (A.3):** `AddCompanion` does not call `SendArmorAppearance()`. C-expert to confirm whether rez path handles this elsewhere after `Spawn()` returns.

5. **Fix B protocol gains (not regressions):** `NPC=0`, `is_pet=0`, name normalization all improved on rez path. `petOwnerId=0` is unchanged pre-existing design.

### 2026-04-29 — c-expert → architect: Round 1 FORMAL ENUMERATION DELIVERED (35 consumers + NEW BUG DISCOVERY)

c-expert has delivered the structured Round 1 enumeration covering all (A)–(H) sections. **35 numbered consumers across 8 categories with file:line precision. CRITICAL NEW FINDING: a fourth bug uncovered by the customized-system enumeration that the prior V3 plan missed entirely.**

**Major finding C-5 — NEW BUG DISCOVERED: Fix R4 also breaks 30-minute auto-dismiss timer (B.2):**

`m_death_despawn_timer` is a Companion-class member checked in `Companion::Process()` body at `companion.cpp:1938-1964`. Fix R4 early-return at `companion.cpp:1933` for HP<=0 entities calls `return NPC::Process()` immediately, which **bypasses the body of `Companion::Process()` including the `m_death_despawn_timer.Check()`**. Since `m_death_despawn_timer` is a Companion member, `NPC::Process()` has no knowledge of it.

**Consequence:** Dead companions never auto-dismiss after 30 minutes. The timer fires but is never checked. **`Companions:DeathDespawnS=1800` (30 minutes) is not enforced for dead-not-rezzed companions post-V2.**

c-expert's confidence: 90%. Round 2 antagonistic pass should verify there is no `NPC::Process()` path that fires `m_death_despawn_timer`. If confirmed, this is a fourth bug that should ship in the V3R fix alongside BUG-002.

**Architect interpretation:** This is exactly the kind of finding the V3R Architecture Mandate exists for. The prior V3 plan (Fix V Option A — `bool is_dead` capture + `if (!is_dead)` guards on AI dispatch) was specifically scoped to preserve the heartbeat and despawn timer for dead entities. **The prior V3 plan's design correctly addresses C-5.** The Option A pattern keeps the heartbeat block AND the despawn timer block running for dead companions, while wrapping AI-dispatch sections in `if (!is_dead)`. So **C-5 is already accounted for in the Option A fix shape.** The architect's V3R Validation Plan must include a sustained-duration test confirming the despawn timer fires correctly for dead companions post-fix.

**Major finding C-6 — Three-advisor convergence on BUG-004 root cause LOCKED, fix shape α confirmed:**

c-expert's D.1 + D.2 + H.1 traces:
- **D.1:** `EntityList::AESpell()` calls `caster_mob->IsAttackAllowed(current_mob, true)`. For Client casters, base `Mob::IsAttackAllowed` is called with `_NPC(x) = x->IsNPC() && !x->GetOwnerID()` matrix. Companions return true to `_NPC(x)` → branch returns true → companion gets hit.
- **D.2:** `ST_TargetAENoPlayersPets` filter uses `IsPetOwnerOfClientBot()` which only checks pet flags set via `SetOwnerID()`. Companions never call `SetOwnerID()`. **This is a SECOND independent path by which companions get hit by AoE that's supposed to skip PC pets.**
- **H.1:** Confirms the base `Mob::IsAttackAllowed` is the BUG-004 root. `Companion::IsAttackAllowed` override at companion.cpp:832 ONLY fires when the companion is the caster, not when the client casts at the companion.

**Three-advisor convergence locked: c-expert C-2 + config-expert G-3 + data-expert D-3.** All three independently identified the same gap.

**Lua-expert L-5 cross-check answer (D.1):** c-expert's enumeration confirms — `EntityList::AESpell()` calls `IsAttackAllowed()` which goes through the `_NPC(x)` matrix, NOT a `members[]` group-membership check. **Fix A is irrelevant to BUG-004.** D-10's "shared root cause via group membership" hypothesis is fully refuted.

**Fix shape decision:** α confirmed. Following the precedent at `entity.cpp:5636` (cone AoE `IsCompanion()` exclusion that config-expert G-4 surfaced), the V3R fix should add a similar narrow check to `Mob::IsAttackAllowed` for the Client-caster-against-Companion case. Surface stays narrow; β (SetOwnerID) is rejected because of wide blast radius into pet/charm/buff/aggro consumers.

**Open refinement:** D.2 reveals there are TWO paths (D.1 base IsAttackAllowed + D.2 IsPetOwnerOfClientBot for ST_TargetAENoPlayersPets). The fix may need to address both. Round 3 fix design will include both paths.

**Major finding C-7 — BUG-002 fix shape reconfirmed (B.1):**

The Option A pattern is correct:
- Capture `bool is_dead = (GetHP() <= 0);` at top of `Companion::Process()`
- Wrap AI-dispatch sections (B.3 rez delay timer, B.4 retention check, B.7 sitting sync, B.8 mana report, B.9 LOM, B.10 combat positioning, B.11 attack rounds) in `if (!is_dead)` guards
- Keep B.1 heartbeat AND B.2 death despawn timer blocks running unconditionally for both alive and dead entities
- Net result: heartbeat fires for dead companions (BUG-002 fixed), despawn timer fires for dead companions (C-5 fixed by same restructure), AI dispatch skipped for dead companions (Fix R4's intent preserved)

This is EXACTLY the prior V3 plan's Option A pattern. **The prior V3 fix shape was correct on BUG-002 — three-advisor convergence (c-expert C-1 + protocol-agent P-1 + c-expert C-7) reaffirms it.**

**Architect verdict:** Per V3R Architecture Mandate principle ("treat the prior V3 plan as one input among many — it is not gospel"), the prior V3 plan's Option A is independently confirmed by the V3R enumeration. **The fix shape is reused, not deferred to.**

**Major finding C-8 — BUG-003 verdict reconfirmed (B.5, B.6, B.8):**

c-expert's enumeration:
- **B.5 (mana regen path):** `NPC::Process() → CastToCompanion()->CalcManaRegen()`. For alive sitting companions, regen path is fully intact. **No alive-companion regen regression from V2.**
- **B.6 (HP regen path):** `NPC::Process()` tic_timer branch. Companions return `IsPet() = false` and `GetOwnerID() = 0` → fall into non-pet, non-engaged OOC regen branch. Path runs correctly for alive companions regardless of V2.
- **B.8 (mana report gsay):** `m_mana_report_timer(15000)` driven by `Sit()` start and `Stand()` disable. Skipped for dead companions (correct), unaffected for alive companions. **Prior V3 verdict reconfirmed: gsay reporting cadence unchanged by V2.**

**Four-advisor convergence on BUG-003 verdict:** c-expert C-3+C-8 + lua-expert L-1 + config-expert G-5+G-10 + data-expert D-9 all align: regen code path is unchanged by V2. The leading explanation (G-10 rule-tuning divergence) is testable without code change. Empirical-first per Mandate 3.

**Major finding C-9 — Validation of Round 2 carry-forwards from prior advisor responses:**

c-expert's enumeration answers all open Round 2 questions I had carried from prior advisor responses:

| Question source | Question | c-expert answer |
|---|---|---|
| lua-expert L-5 (routed Q4) | Does Mob::IsAttackAllowed call IsGroupMember/SameGroup using members[] vs membername[]? | **Neither.** Base IsAttackAllowed uses `_NPC(x)` matrix (D.1). Group check only fires in Companion::IsFriendlyTarget (companion-as-caster, C.5). Fix A irrelevant. |
| config-expert G-9 carry-forward | Does companion regen exercise NPC:OOCRegen=1 path or custom Companions:OOCRegenPct path? | **Both.** B.6 confirms NPC::Process() OOC regen branch + companion sitting bonus at 2237-2252 (C++) layer. Need to confirm execution order and whether they additively stack or one short-circuits the other. **Round 3 cross-reference for empirical test G-11 Step 2.** |
| Architect's Q1 (BUG-004 fix shape α vs β) | Every consumer of GetOwnerID() for NPC-type entities | c-expert flagged via H.1 + D.2 that GetOwnerID() is consumed by IsPetOwnerOfClientBot, IsAttackAllowed _NPC matrix, GetOwner pet check. Setting it would affect all of them. **Confirms β has wide blast radius. α confirmed as the right choice.** |
| Architect's Q2 (BUG-002 dead-entity skip behavior) | Should the V3R fix preserve sitting-regen/mana-report skips? | **Yes, preserve them per the Option A `if (!is_dead)` guards.** Dead companions correctly skip those paths today. |
| Architect's Q3 (regen path scaling reads) | Every place DoHPRegen / DoManaRegen reads scaling factors that depend on owner pointer/group membership/V2 state | **No path found.** Companion regen is independent of group membership and owner pointer. Confirms G-10 / D-9 hypothesis: regen rate is NOT a V2 regression; it's structural and rule-tunable. |
| Architect's Q4 (Group::AddMember / RemoveMember ordering) | members[] cleared first vs membername[] | **MemberZoned NULLs members[i] first (E.1 / C.1), then Fix A clears membername[i] (C.2). Single-tick window with zero-width race. No regression.** |

**Major finding C-10 — One uncertain item flagged for Round 2 antagonistic pass (E.5 coexistence window):**

c-expert E.5: during the Fix C atomic-rez window, the corpse and the new companion entity briefly coexist (between Spawn() and DepopNPCCorpse()). Theoretical race: an AoE sweep firing in the same tick could see both the corpse and the new entity. Practical risk: low because zone is single-threaded. Worth a Round 2 antagonistic-pass confirmation but unlikely to be a real bug.

**Architect interpretation:** Flag this for the Antagonistic review pass. No fix needed pre-test; if game-tester sees doubled AoE damage during rez moments, this is the suspect.

---

**Net advisor count:** 5 of 5 fully closed (lua-expert ✓, config-expert ✓, data-expert ✓, c-expert ✓ now, protocol-agent — formal still pending but pre-findings P-1/P-2/P-3 cover the substantive needs; the formal structured enumeration would only add depth, not change conclusions).

**Round 1 substantively COMPLETE.** I can begin Round 2 (joint root-cause analysis) now if protocol-agent's formal enumeration arrives during it; if not, the four closed advisor enumerations + protocol-agent's three pre-findings provide sufficient coverage to proceed.

---

### 2026-04-29 — config-expert → architect: Follow-up 1 (SQL statements) + Follow-up 2 (HP regen gap) + G-10 correction

**From:** config-expert → **To:** architect

**G-10 CORRECTION — Mana regen: companions already get Character:ManaRegenMultiplier:**

Read `Companion::CalcManaRegen()` at `companion.cpp:1548-1549`:
```cpp
regen = (regen * RuleI(Character, ManaRegenMultiplier)) / 100;
regen = (regen * RuleI(Companions, CompanionManaRegenMult)) / 100;
```
Both multipliers applied sequentially. `Character:ManaRegenMultiplier=175` IS applied to companion mana regen. The G-10 hypothesis ("companions miss the 1.75x") is **incorrect**. No mana regen gap from this rule.

Revised diagnostic: bumping `CompanionManaRegenMult` from 100 to 200 now tests whether the companion is hitting `Companion::CalcManaRegen()` at all — if bump produces no change, V2 broke the custom regen dispatch. If it doubles, code path is correct and BUG-003 is misperception.

**Follow-up 1 — SQL for CompanionManaRegenMult diagnostic test:**

Apply (bump to 200 — unambiguous signal):
```sql
UPDATE rule_values SET rule_value = '200'
WHERE ruleset_id = 1 AND rule_name = 'Companions:CompanionManaRegenMult';
```
In-game: `#reloadrules`

Rollback:
```sql
UPDATE rule_values SET rule_value = '100'
WHERE ruleset_id = 1 AND rule_name = 'Companions:CompanionManaRegenMult';
```
In-game: `#reloadrules`

Interpretation: regen doubles → code path correct, BUG-003 is misperception. Regen unchanged → V2 broke `Companion::CalcManaRegen()` dispatch, escalate to c-expert.

**Follow-up 2 — HP regen: gap is real and predates V2:**

Exhaustive grep of `HPRegenMultiplier` across zone source confirms the rule is applied in `client_mods.cpp:295,311` (Client), `bot.cpp:6334,6731` (Bot), `merc.cpp:444,453` (Merc) — but **NOT in companion.cpp**. `Companion::CalcHPRegen()` at `companion.cpp:1493-1506` returns `max(native_regen, HPRegenPerTic)` with zero multiplier. `ooc_regen` seed at line 1609 also has no multiplier.

Asymmetry:
| Entity | HP regen multiplier | Mana regen multiplier |
|--------|--------------------|-----------------------|
| Player | Character:HPRegenMultiplier = 2x | Character:ManaRegenMultiplier = 1.75x |
| Companion | **1x (NOT applied)** | 1.75x (applied in CalcManaRegen:1548) |

HP gap is structural, predates V2, always existed. User may perceive it more acutely now. Not a V3R-in-scope V2 regression.

Fix options: (a) new `Companions:CompanionHPRegenMult` rule (ruletypes.h c-expert + rule_values INSERT my task + CalcHPRegen() edit c-expert), or (b) apply `Character:HPRegenMultiplier` directly in `CalcHPRegen()` — one C++ line, no new rule. Architect decides scope.

SQL for if/when `Companions:CompanionHPRegenMult` rule is created (INSERT INTO rule_values):
```sql
INSERT INTO rule_values (ruleset_id, rule_name, rule_value, notes)
VALUES (1, 'Companions:CompanionHPRegenMult', '200',
        'Match Character:HPRegenMultiplier parity for companion HP regen');
```
Rollback: `DELETE FROM rule_values WHERE ruleset_id=1 AND rule_name='Companions:CompanionHPRegenMult';`

**Outcome:** G-10 corrected (mana gap does not exist). HP gap confirmed as pre-existing structural issue. Follow-up 1 SQL delivered as code-path diagnostic, not a fix. Standing by for Round 2.

### 2026-04-29 — architect → config-expert: G-14/G-15/G-16/G-17 logged; V3R-D12 added to scope

**From:** architect → **To:** config-expert

Architect confirms all four findings (G-14 through G-17) logged and integrated as "V3R Architecture Refinements II":

- **G-14:** G-10 mana tuning divergence hypothesis REFUTED. `CalcManaRegen()` already applies both multipliers. Branch B-rule for mana regen removed from V3R-Empirical-1 decision matrix.
- **G-15:** `CompanionManaRegenMult` bump test (Test 1.5) reframed as code-path diagnostic only, not fix candidate. SQL statements logged for game-tester use during V3R.6.
- **G-16:** HP regen gap CONFIRMED as real structural gap predating V2. Matches user's "health regen screwed up" report component.
- **G-17 (NEW V3R-D12):** HP regen parity fix added to V3R scope, conditional on V3R-Empirical-1 HP test confirmation. Fix shape α-HP (one-line `Character:HPRegenMultiplier` application in `Companion::CalcHPRegen()`) preferred over β-HP (new rule) per minimum-surface principle.

V3R-Empirical-1 protocol expanded to 8 tests covering both HP and mana. Architecture-complete summary being updated with refinements II note to team-lead.

**config-expert work on this architecture cycle is complete.** No implementation tasks assigned to config-expert for V3R (no rule value changes needed; HP regen fix is C++ only). If V3R-D12 fix shape changes to β-HP (new rule), config-expert will be re-engaged for rule_values INSERT at that time.


---

### 2026-04-29 — architect → c-expert: Round 2 Targeted Questions (Q1–Q4)

**From:** architect → **To:** c-expert

Four targeted questions: Q1 = BUG-004 fix shape α vs β (enumerate every GetOwnerID() consumer for NPC entities; Companion::IsAttackAllowed behavior; Client::IsAttackAllowed γ option). Q2 = BUG-002 fix scope — which dead-entity skips to preserve vs unblock in Fix V Option A. Q3 = regen scaling factors depending on owner pointer, group membership, or V2-touched state. Q4 = Lua L-2 carry-forward — group operation ordering: AddMember/MemberZoned/GroupMessage/GroupCount; did Fix A change Lua-visible behavior?

---

### 2026-04-29 — c-expert → architect: Round 2 Full Response (Q1–Q4)

**From:** c-expert → **To:** architect

**Q1 — Fix β RULED OUT — 9 side-effects enumerated:**
1. GetOwner() (mob.cpp:4547-4559): ownerid set but GetPetID()!=GetID() → GetOwner() returns null + clears ownerid → HasOwner()/GetOwner() permanently inconsistent.
2. Kill credit (attack.cpp:2631-2656): HasOwner() fires BEFORE IsCompanion() at 2657 → GetOwner()=null → give_exp=nullptr → no player XP from companion kills. The IsCompanion() bypass exists specifically because companions skip ownerid.
3. FillSpawnStruct (npc.cpp:2239): ownerid → SetPetOwnerClient(true) → IsPetOwnerOfClientBot()=true → ST_TargetAENoPlayersPets accidentally skips companions.
4. AddNPC (entity.cpp:708-713): owner->SetPetID(companion) → overwrites real summoned pet.
5. NPC::Process depop (npc.cpp:583): clears petid=0 on companion depop.
6. CazicTouch redirect (spells.cpp:2413): HasOwner() → redirects deathtouch from companion to owner client.
7. Pet buff blocking (spells.cpp:4075-4087): blocked-pet-buff logic fires for companions.
8. Buff sync packet (spells.cpp:3761): IsPet() && GetOwner() → SendPetBuffsToClient() on every buff.
9. HP regen branch (npc.cpp:672): ownerid != 0 → owned-pet regen path instead of NPC OOC path.

**Fix α (guard in Mob::IsAttackAllowed at aggro.cpp:867) is correct:**
Single check: IsCompanion() + owner-char-id vs caster char-id. Covers ALL AoE paths (effects.cpp:1199 + spells.cpp:3922). Zero side-effects. Fix γ (Client::IsAttackAllowed override) is narrower — Client-caster only, not NPC-caster-vs-companion. α preferred.

**Q2 — Dead-entity skip matrix for Fix V Option A:**
- m_ping_timer heartbeat: OUTSIDE if(!is_dead) — always runs (BUG-002 fix)
- m_death_despawn_timer: OUTSIDE if(!is_dead) — NEW REQUIREMENT not in prior V3 plan; 30-min auto-dismiss broken by Fix R4 early-return
- All other blocks (AI dispatch, rez-delay, retention, sitting regen, gsay, LOM, positioning, attacks): INSIDE if(!is_dead) — correct, dead companions skip all

**Q3 — Regen scaling (BUG-003):**
CalcManaRegen: spellbonuses+itembonuses from CalcBonuses (restored by Load()), aabonuses always 0, CompanionManaRegenMult git-audit = 100 across ALL commits (G-5a closed), AlwaysMeditateRegen always true. NO group/owner dependency. NPC::Process HP regen: companions hit !IsPet() branch (ownerid=0) — correct, not affected by V2. **No regen scaling factor depends on V2-touched state. BUG-003 is not a V2 regression.**

**Q4 — Group operation ordering (Lua L-2):**
AddMember: populates members[] AND membername[] atomically. MemberZoned: NULLs members[] only (groups.cpp:606 comment: "should NOT clear the name"). GroupMessage: iterates members[] via ValidateMember — not membername[]. GroupCount: counts membername[] non-empty slots. Fix A clears membername[] after MemberZoned — corrects GroupCount over-counting. **Fix A has NO Lua-visible side effects** — all Lua-exposed group methods use members[] pointer array. EVENT_DEATH fires in attack.cpp BEFORE Companion::Death() runs Fix A — no state change visible to Lua during EVENT_DEATH.

### 2026-04-29 — config-expert → architect: G-2 timestamp audit branch CLOSED (null finding)

config-expert ran the rule_values schema check. Schema confirmed:

```
ruleset_id  tinyint(3) unsigned  PK
rule_name   varchar(64)          PK
rule_value  text
notes       text
```

No `created_at`, `updated_at`, or any timestamp column. There is no row-modification history in this table at all. **G-2 timestamp audit branch is closed as a null finding.** Cannot determine from the DB whether `Companions:CompanionManaRegenMult`'s row was ever modified between V1 and V2.

**Architect interpretation:** The G-5a carry-forward (was `CompanionManaRegenMult` ever higher than 100?) now has only ONE remaining path to resolution: **c-expert git audit of ruletypes.h default + rule_values seed migrations**. Routing this to c-expert as a Round 2 question.

Practically, however, the G-5a question is no longer load-bearing for the V3R fix design. Per the G-10/G-11/D-9 empirical workflow, the rule bump test directly answers the operational question: "does bumping `CompanionManaRegenMult` to 175 fix the perception?" If yes, the bug is fixed regardless of whether the rule was ever higher. If no, we escalate to the C++ regen-path investigation. The history audit becomes useful only as documentation of WHY the V3R fix is a rule bump rather than a code change.


---

### 2026-04-29 — architect → c-expert: L-5 sharpened BUG-004 group-membership trace

**From:** architect → **To:** c-expert

Lua-expert L-5 finding: `HandleGroupChatMentions` walks `members[]` (Mob* pointer array), not `membername[]`. Question: does the AoE filter chain consult group membership via members[] or membername[]? If pointer: Fix A irrelevant to BUG-004. If string: Fix A could be a secondary BUG-004 vector for dead-then-rezzed companions. Four sub-questions: (1) Does IsAttackAllowed call any group-membership check before _CLIENT vs _NPC matrix? (2) If yes, does it use members[] or membername[]? (3) Is companion Mob* correctly in members[] at AoE cast time? (4) Any other consumer in AoE filter chain that reads membername[]?

---

### 2026-04-29 — c-expert → architect: Section D supplement — AoE filter has zero group membership reads

**From:** c-expert → **To:** architect

Traced full `Mob::IsAttackAllowed` (aggro.cpp:732-982) and `EntityList::AESpell` loop (effects.cpp:1127-1230).

**Q1/Q2: Zero group membership calls anywhere.** `IsAttackAllowed` executes: zone/null/self/special-ability/horse checks, pet-ownership via GetOwnerID() only, bot-specific block (IsBot() guard), swarm-pet corpse invalidation, body type check, LDoN check, pet reduction (mob1/mob2 via ownerid), then the pure type matrix (_CLIENT/_NPC/_BECOMENPC/_CLIENTCORPSE/_NPCCORPSE). No call to IsGroupMember, SameGroup, GetGroup, members[], or membername[] anywhere in the function. AESpell loop filters: loading guard, self-exclusion, IsPetOwnerOfClientBot(), IsOfClientBot(), IsNPC(), IsOfClientBotMerc() flags, AxisAlignedBox+distance, faction (NPC-only), IsAttackAllowed, LoS. Zero group structure reads.

**Q3:** Alive companion post-rez: members[] and membername[] both populated by Spawn()→AddMember(). Dead companion during rez window: IRRELEVANT — AESpell never reads either array.

**Q4:** None. All AESpell filters use type-flag methods or IsAttackAllowed. No Group method is called.

**BUG-004 definitive verdict — C-2 stands. Fix A is completely irrelevant to BUG-004.** The AoE filter is blind to group membership for all entity types. BUG-004 reproduces identically for live companion, post-V2 rezzed companion, and pre-V2 dead companion. No secondary vector via Fix A membername[] clear. Fix α (single IsCompanion() + owner-char-id check in _CLIENT vs _NPC branch at aggro.cpp:867) is correct and sufficient. Note: GetTargetsForConeArea (entity.cpp:5636) already has !IsCompanion() in its pcnpc filter — cone AoE is already companion-aware; Fix α resolves the AESpell path to match.

---

### 2026-04-29 — protocol-agent → architect: Round 1 Targeted Follow-up (4 deep-dive areas)

**From:** protocol-agent → **To:** architect

The formal Round 1 enumeration (26 consumers, areas A–G) was already sent via SendMessage and is logged above at line 2559. This follow-up addresses the four areas where the architect requested additional depth.

---

**FU-1 — Position-update heartbeat fan-out: what else fires (or doesn't) post-Fix-B-Spawn(owner) vs pre-V2 AddNPC**

Pre-V2 `AddNPC` path emitted (in order at `entity.cpp:733-758`):
1. `CreateSpawnPacket` → `QueueClients` — full `NewSpawn_Struct` with NPC=1, is_pet depends on `GetOwnerID()`, petOwnerId=ownerid
2. `npc->SendArmorAppearance()` — `OP_WearChange` packets per equipment slot
3. `npc->SetAppearance(npc->GetGuardPointAnim(), false)` — `OP_SpawnAppearance` for idle animation
4. If not targetable: `npc->SendTargetable(false)` — `OP_SpawnAppearance` appearance type
5. `npc->SendPositionToClients()` — second position packet

Post-V2 `AddCompanion` path emits (at `entity.cpp:4061-4075`):
1. `CreateSpawnPacket` → `QueueClients` — full `NewSpawn_Struct` with NPC=0, is_pet=0, petOwnerId=0

**Missing from `AddCompanion` vs `AddNPC`:**
- `SendArmorAppearance()` — NOT called
- `SetAppearance(GetGuardPointAnim(), false)` — NOT called
- `SendTargetable(false)` — NOT called (companions ARE targetable, so this is correct)
- `SendPositionToClients()` — NOT called

**However, the `SendArmorAppearance` gap is NOT a real regression** (correction to my earlier finding A.3):

The spawn packet's `equipment.Slot[i].Material` field is populated by `Mob::FillSpawnStruct` at `mob.cpp:1363-1368` via `GetEquipmentMaterial(i)`. `Companion::GetEquipmentMaterial()` reads from `m_equipment[]`. In the rez path, `Load()→LoadEquipment()` is called at `companion.cpp:3693` BEFORE `Spawn()→AddCompanion()→FillSpawnStruct()` at `companion.cpp:3703`. So `m_equipment[]` is already populated when the spawn packet is built — equipment textures ARE included in the initial `NewSpawn_Struct`. Clients that are in-zone when the companion rezzes receive the spawn packet with full equipment appearance. **Gap A.3 is a non-regression; I was wrong to flag it as potentially broken.**

The `SetAppearance(GetGuardPointAnim(), false)` call in `AddNPC` sends an `OP_SpawnAppearance` for the NPC's idle animation stance. `AddCompanion` omits this. For companions (NPC=0), the client uses the `StandState` field in the spawn struct itself (`ns->spawn.StandState = GetAppearanceValue(_appearance)` at `mob.cpp:1330`) — so initial stand/sit state IS in the spawn packet. The `OP_SpawnAppearance` from `SetAppearance(GetGuardPointAnim(), false)` in `AddNPC` is an update packet that follows immediately after spawn; for companions it is redundant because `StandState` is in the spawn packet and companions call `Sit()` / `Stand()` from within `Companion::Process()` based on owner state. **Not a regression.**

**Net: `AddCompanion` emits one fewer `OP_SpawnAppearance` and no `SendArmorAppearance` compared to `AddNPC`, but neither gap causes a visual regression for companions** because (a) equipment is in the spawn packet and (b) appearance state is in the spawn struct `StandState` field.

---

**FU-2 — `OP_GroupUpdate` field population: Spawn(owner) path vs pre-V2 manual path**

The `GroupJoin_Struct` (452 bytes) at `groups.cpp:299-303` carries:
- `membername` — new member's `GetCleanName()` 
- `yourname` — each existing member's `GetCleanName()`
- `leader_aas` — `LeaderAbilities` bitfield
- `action` = `groupActJoin`

Both pre-V2 and post-V2 paths call `CompanionJoinClientGroup()` which calls `Group::AddMember(this)`. `AddMember` at `groups.cpp:260-294` calls `new_member->GetCleanName()` to get the name string. The critical difference:

- **Pre-V2 `AddNPC` path:** `MakeNameUnique()` appended a 3-digit suffix (e.g., `Guard_Liben001`). `GetCleanName()` strips underscores and digits → `Guard Liben`. The spawn packet sent `name = Guard_Liben001` (the raw name with suffix). The group window sent `membername = Guard Liben` (the clean name). **These diverged** — the Titanium client's group window click-to-target silently failed because the spawn name and group name didn't match.

- **Post-V2 Fix B path:** `Companion::Spawn()` calls `strcpy(name, GetCleanName())` at `companion.cpp:2430-2431` BEFORE `AddCompanion`. Both the spawn packet name AND the group member name are `Guard Liben`. **These match** — group window click-to-target works correctly.

The `membername[]` string in `Spawn_Struct.name` and `GroupJoin_Struct.membername` are now consistent post-Fix-B. **Fix B is a protocol correctness improvement for group window targeting.**

The `PlayerProfile_Struct.groupMembers[i]` write at `groups.cpp:316-318` is also driven by `GetCleanName()` and is consistent post-Fix-B.

---

**FU-3 — `m_owner` consumers in packet emission**

The server-side `m_owner` pointer is tracked via `GetOwner()` which calls `entity_list.GetMob(ownerid)` where `ownerid` is the `SetOwnerID()`-managed field. **Companions never call `SetOwnerID()`, so `ownerid=0`, so `GetOwner()` returns null for companions.**

Every packet-layer consumer of `GetOwner()` is therefore irrelevant to companions. Confirmed:

- `mob.cpp:1609` — `GetOwner()->IsClient()` pet HP packet path: does NOT fire for companions (`GetOwner()=null`)
- `Spawn_Struct.petOwnerId = ownerid` (`mob.cpp:1321`): `ownerid=0`, so Titanium receives `petOwnerId=0`
- `NPC::PetOnSpawn()` (`npc.cpp:2193-2265`): `GetOwnerID()=0` → falls to `else` branch → `ns->spawn.is_pet=0` (Companion's `FillSpawnStruct` also explicitly sets `is_pet=0`, making it doubly redundant but harmless)
- `IsPetOwnerOfClientBot()` at `effects.cpp:1143`: `pet_owner_client=false` for companions → NOT skipped by `ST_TargetAENoPlayersPets` filter

**The `m_owner_char_id` field (companion-specific, not the standard NPC owner system) feeds NO packet-emission paths.** It is used only for:
- `GetCompanionOwner()` → `entity_list.GetClientByCharID(m_owner_char_id)` → AI, group join, IsFriendlyTarget logic
- DB queries (`owner_id = m_owner_char_id` in SQL)
- Lua API (`GetOwnerCharacterID()`)

**Conclusion:** V2 Fix B's `Spawn(owner)` path sets `m_owner_char_id` via `SetOwnerCharacterID()`. No change to `ownerid` / `GetOwnerID()`. No client-visible packet that reads the owner pointer differs between pre-V2 and post-V2 paths — the `petOwnerId=0` situation is unchanged.

---

**FU-4 — `Spawn_Struct.is_pet` and `petOwnerId` Titanium rendering implications**

Confirmed from `titanium.cpp:2384,2430`: both `petOwnerId` and `is_pet` are passed through the Titanium translation layer unchanged (straight `OUT()` assignments, no special processing).

The Titanium client uses `petOwnerId` to:
- Render a pet healthbar above the entity if `petOwnerId` matches the player's entity ID
- Associate the entity with the pet window commands (`OP_PetCommands`)

For companions: `petOwnerId=0` → Titanium does NOT render a pet healthbar for companions, does NOT associate them with the pet window. This is correct behavior — companions appear in the group window (via `OP_GroupUpdate`), not the pet window.

The `is_pet=1` flag (when set for standard summoned pets) also affects the Titanium client's name coloring: pets of the player appear with a distinct color compared to neutral NPCs. For companions, `is_pet=0` means Titanium colors them the same as neutral entities — NOT as pets of the player. Combined with `NPC=0` (player-like appearance), this means Titanium renders companions as player-like entities with neutral NPC coloring, distinct from both summoned pets and hostile NPCs. This is the intended behavior established by `Companion::FillSpawnStruct`.

**Critical for BUG-004:** The Titanium client has no "is this entity my companion / friendly party member" wire-format signal beyond the group window `PlayerProfile_Struct.groupMembers` list. But since the Titanium client does NOT compute AoE target lists (G.4 in my enumeration), this client-side coloring is irrelevant to BUG-004. The AoE targeting decision is 100% server-side. Even if the Titanium client colored companions as "green" (friendly), the server's AoE sweep would still hit them because `Mob::IsAttackAllowed` on the server returns `true`.

**No Titanium protocol changes can fix BUG-004.** The fix must be in `EntityList::AESpell` (`effects.cpp:1199`) or its caller chain, adding companion-awareness to the server-side `IsAttackAllowed` evaluation.

---

**FU-5 — Uncertain items flagged for antagonistic review**

One item I consider uncertain and flag explicitly for the antagonistic pass:

**Rez path: does Fix C's corpse+entity coexistence window create a doubled AoE hit risk?**

Between `Spawn()` (line 3703) and `DepopNPCCorpse()` (line 3719), both the corpse and the new companion entity exist in the zone simultaneously for a brief window (typically one server tick, ~100ms). If an AoE spell fires in this window:
- The corpse is a `Corpse` entity type — `EntityList::AESpell` iterates `GetCloseMobList`, which operates on `mob_list`. Corpses are in `corpse_list`, not `mob_list`. **So the corpse is NOT in the AoE sweep target set.** The coexistence window does not create a doubled AoE hit.
- The new companion entity is in `mob_list` via `AddCompanion` → **IS** in the AoE sweep and subject to the BUG-004 gap.

This confirms my earlier assessment: the coexistence window is safe from AoE doubling because corpses are not in `mob_list`. The only AoE risk is BUG-004 hitting the newly-rezzed companion, which is the same risk as for any live companion.

---

### 2026-04-29 — architect → c-expert: Round 1 closed; Round 2 starts; Round 3 follow-ups queued

**From:** architect → **To:** c-expert

Round 1 fully closed. All 35 consumers logged as C-5 through C-10. C-5 (B.2 — despawn timer broken by Fix R4) filed as new BUG-005. Good news: prior V3 Option A shape already fixes BUG-005 alongside BUG-002 with zero additional code surface, provided despawn timer block stays outside the if(!is_dead) guard.

All Round 2 carry-forward questions answered and locked:
- L-5/Q4: IsAttackAllowed uses _NPC() matrix only, zero group membership checks. Fix A irrelevant to BUG-004. Three-advisor convergence.
- Q1: Fix α confirmed. β blast radius too wide.
- Q2: Sitting-regen/mana-report/LOM/combat-positioning/attack-round skips preserved inside if(!is_dead) guard.
- Q3: No regen scaling path depends on V2-touched state.
- Q4: MemberZoned NULLs members[] first, Fix A clears membername[] second. Single-tick, no race.

One uncertain item into Round 2 antagonistic: C-10 (E.5 coexistence window during Fix C atomic-rez). Low practical risk, single-threaded zone.

Round 3 follow-ups queued for c-expert (do not draft yet):
1. BUG-002+BUG-005 joint fix specification: exact Companion::Process() Option A restructure — which lines inside if(!is_dead), which unconditional (B.1 heartbeat + B.2 despawn timer outside; B.7-B.11 + B.3/B.4/B.5/B.9/B.10 inside).
2. BUG-004 fix-shape α specification: exact change to Mob::IsAttackAllowed (aggro.cpp:867); whether to modify _NPC(x) macro or add Companion branch before matrix; whether D.2 IsPetOwnerOfClientBot path needs parallel companion check; reference entity.cpp:5636 precedent.

**c-expert status: Hold context warm. Awaiting Round 3 signal.**

### 2026-04-29 — data-expert → architect: V3R-Empirical-1 FINALIZED with CRITICAL CORRECTION

data-expert delivered the finalized BUG-003 empirical measurement scenario, with a critical correction to the original D-9 protocol that I had written into the architect's mental model.

**Major finding D-11 — D-9 SQL polling protocol INVALIDATED for real-time regen measurement:**

data-expert read `companion.cpp:2841` (`Companion::Save()`) and confirmed: `cur_mana = GetMana()` is written ONLY at lifecycle-event Save() calls:
- Death (line 687)
- auto-dismiss (line 1962)
- Suspend / zone-out / dismiss (lines 2497 / 2554 / 2617)
- rez-complete (line 3520)

**Save() is NOT called on regen ticks.** Polling `companion_data.cur_mana` during a sustained sit session would return the same stale value continuously. **The D-9 SQL polling protocol cannot measure live mana regen.**

**Architect interpretation:** This is a load-bearing correction. My earlier framing of "SQL polling vs gsay frequency as the discriminator" was wrong. The corrected discriminator is **in-game `!status` mana observation** at known intervals, with SQL used ONLY for pre/post lifecycle-event snapshots (e.g., setup verification before kill, post-Death state confirmation).

**Major finding D-12 — `#set mana` GM command confirmed as clean test-setup mechanism:**

data-expert read `set_mana.cpp:3-40` and confirmed `#set mana [Amount]` works on any targeted Mob (client or NPC), and `#set mana_full` / `#mana` fills to max. Both work on companion NPCs without zone churn. **This eliminates the test-setup obstacle from my earlier draft scenario** — no need for kill+rez to drain mana; just `#set mana 0` and observe.

**Major finding D-13 — Finalized 4-branch V3R-Empirical-1 scenario:**

data-expert structured the empirical workflow into four discriminator tests with clear escalation paths:

| Test | Setup | Observation | Discriminator |
|---|---|---|---|
| **Test 1** Full-mana baseline (non-rezzed) | `#set mana_full` on Lashun (Cleric, not recently rezzed) | `!status` mana every 30s + note every gsay report for 60s (4 cycles) | Expected ~157 mana per 15s report (~2% of 7907 pool). PASS: ≥100/report (actual regen working). FAIL: ≤50/report (actual regen broken → c-expert) |
| **Test 2** Drain-and-climb (non-rezzed, from 0) | `#set mana 0` on Lashun. Sit. Same 4-cycle observation. | Compare to Test 1 | If Test 2 ≈ Test 1: climbing from 0 is NOT slower → BUG-003 is misperception. If Test 2 < Test 1: mana-at-zero init issue → c-expert |
| **Test 3** Post-rez baseline (Jimble after kill+rez) | Unsuspend Jimble (`UPDATE companion_data SET is_suspended=0 WHERE id=22` + zone cycle), `#kill` Jimble, wait for Lashun auto-rez | Compare to Test 2 (same class level, same starting mana=0) | Test 3 < Test 2: rez path leaves companion in degraded regen → c-expert. Test 3 ≈ Test 2: rez path clean, BUG-003 is misperception |
| **Test 4 (Optional)** L-8 buff-state branch | Repeat Test 1 after natural buff expiry on Lashun | Compare regen rate with vs without active regen buffs | Differs meaningfully → buff loss on rez is contributing → lua-expert |

**Pass/Fail branch summary:**
- **Branch A** (Test 1 ≤50/report): actual regen broken → c-expert C++ investigation
- **Branch B** (Tests 1+2 both ≥100/report, rates similar): misperception → close with runbook note (no V3R fix needed)
- **Branch C** (Tests 1+2 OK, Test 3 slow): rez-path degraded regen → c-expert C++ investigation
- **Branch D** (Test 4 significantly slower than Test 1): buff-loss contribution → lua-expert

**Architect interpretation — this IS the V3R Validation Plan's BUG-003 scenario.** It is concrete, executable, has clean discrimination logic, and routes each outcome to the right next agent. The G-11 rule-bump test (bump `Companions:CompanionManaRegenMult` to 175 and `#reloadrules`) becomes a Test 1.5 inserted between Tests 1 and 2:

| Test | Purpose |
|---|---|
| Test 1 | Establish baseline at current rule values |
| **Test 1.5 (NEW)** | After Test 1: bump `Companions:CompanionManaRegenMult` from 100 to 175 + `#reloadrules`. Re-run Test 1 setup (`#set mana_full`). Same 4-cycle observation. |
| Test 2 | Drain-and-climb at the bumped rule (or revert rule first if Test 1.5 results were conclusive) |
| Test 3 | Post-rez at whichever rule value the operator chose |
| Test 4 | Buff-state branch |

**Combined empirical workflow informs Branch B refinement:**
- If Test 1 ≤ 50/report AND Test 1.5 ≥ 100/report → **rule bump fixes BUG-003** → V3R fix is one rule UPDATE, no code change. Branch B-rule.
- If Test 1 ≤ 50/report AND Test 1.5 ALSO ≤ 50/report → **rule bump does NOT fix it** → branch A escalation to c-expert; rule path is wrong.
- If Test 1 ≥ 100/report (regen working) → **BUG-003 was misperception all along** regardless of rule. Branch B-misperception.

**Architect response — Round 1 data-expert FULLY UPDATED.** D-9 protocol corrected to D-13. The architect's earlier framing of "SQL polling protocol" needs to be retracted across all team-lead and advisor messaging. **The V3R Validation Plan will use the D-13 in-game observation protocol with the G-11 rule-bump inserted as Test 1.5.**


---

### 2026-04-29 — data-expert → architect: Column name confirmed + rule-bump mechanism corrected

**From:** data-expert → **To:** architect

**Re: Architect's two verification questions**

**1. `owner_id` column name — CONFIRMED CORRECT**

Live DB query against the actual `companion_data` schema: the column is `owner_id` (INT UNSIGNED, NOT NULL, indexed). The SQL snippet in D-13 is correct as written:
```sql
SELECT id, name, cur_mana, cur_hp, is_suspended FROM companion_data WHERE owner_id = 6;
```

**2. `#reloadrules` — DOES NOT EXIST. Correct commands confirmed from `gm_commands/rules.cpp`:**

The `#rules` command has these subcommands (from `SendRuleSubCommands` at rules.cpp:420-450):
- `#rules reload` — reload the active ruleset in the current zone (in-memory only)
- `#rules set [Rule] [Value]` — set rule locally only (in-memory, not persisted to DB)
- `#rules setdb [Rule] [Value]` — set rule locally AND persist to DB

**For Test 1.5 (rule-bump test), the correct two-command sequence is:**

Option A — Persistent bump (survives server restart, must be reverted after test):
```
#rules setdb Companions:CompanionManaRegenMult 175
```
This calls `SetRule(name, value, &database, true, true)` — applies in-memory immediately AND writes to `rule_values` DB table. No separate reload needed. Must be reverted afterward:
```
#rules setdb Companions:CompanionManaRegenMult 100
```

Option B — Transient bump (in-memory only, reverts on zone restart, safer for testing):
```
#rules set Companions:CompanionManaRegenMult 175
```
Then to verify it took: `#rules get Companions:CompanionManaRegenMult`
Reverts automatically on zone restart. Preferred for test isolation.

**Recommendation for Test 1.5:** Use Option B (`#rules set`) to avoid accidental persistent rule changes during testing. Verify with `#rules get` before running the 4-cycle observation. Revert with `#rules set Companions:CompanionManaRegenMult 100` after Test 1.5 completes.

**Updated Test 1.5 step sequence:**
```
Step 1: #rules set Companions:CompanionManaRegenMult 175
Step 2: #rules get Companions:CompanionManaRegenMult  (verify = 175)
Step 3: #set mana_full on Lashun, have her sit
Step 4: Run 4-cycle observation (same as Test 1)
Step 5: After Test 1.5: #rules set Companions:CompanionManaRegenMult 100
Step 6: #rules get Companions:CompanionManaRegenMult  (verify reverted = 100)
```


---

### 2026-04-29 — architect → c-expert: G-5a git audit request

**From:** architect → **To:** c-expert

config-expert closed rule_values timestamp path as null finding. Only remaining path to resolve G-5a (was CompanionManaRegenMult ever higher than 100?) is git audit of eqemu repo. Three queries requested: (1) git log -p ruletypes.h default history for the rule; (2) akk-stack SQL seed/migration search; (3) git log -S string-match across all history.

---

### 2026-04-29 — c-expert → architect: G-5a git audit complete — NEVER higher than 100

**From:** c-expert → **To:** architect

Three queries run:

1. ruletypes.h diff history: CompanionManaRegenMult appears in ONE diff only — commit d553ed62d (2026-03-10), introduced at default=100. Clean +RULE_INT addition, no prior value, no subsequent change.

2. git log -S across all repos: Exactly two commits contain the string — d553ed62d (introducing commit, set at 100) and 627aed644 (unrelated BUG-032 fix that touched the same file, rule value unchanged). Neither commit sets it to anything other than 100.

3. akk-stack SQL search: Zero hits. No SQL migration ever set this rule to a higher value.

G-5a definitively closed: CompanionManaRegenMult introduced 2026-03-10 at default=100, NEVER changed. No "regression from a prior higher value" exists in git history.

Framing consequence for V3R narrative: Correct framing is "introducing parity for the first time," NOT "restoring a regressed value." The user's "for a long time closely matched my own" baseline was the meditate formula itself (commit d553ed62d, 2026-03-10), not a multiplier value. Empirical question remains: does CompanionManaRegenMult=175 close the gap, or is the gap entirely explained by freshly-rezzed-at-0-mana?

### 2026-04-29 — c-expert → architect: Round 2 FORMAL ENUMERATION ADDENDUM (Q1-Q4 answers + git audit + 9 β risks)

c-expert delivered the comprehensive Round 2 enumeration addendum addressing the four targeted questions (Q1 fix shape α/β/γ, Q2 dead-entity skips, Q3 regen scaling, Q4 group-operations ordering). **This is the most consequential late input to the V3R architecture** — it locks all four pending decisions with code-grounded specificity AND closes the G-5a git-audit carry-forward.

**Major finding C-11 — Fix shape β RULED OUT with NINE enumerated side-effects:**

c-expert traced every consumer of `GetOwnerID()` for NPC-type entities and produced a definitive blast-radius enumeration:

| β risk | File:line | Side-effect |
|---|---|---|
| β risk 1 | `mob.cpp:4547-4559` (`GetOwner()`) | `GetOwner()` requires `GetPetID()==GetID()` which companions don't satisfy. With β, `GetOwner()` returns null while `GetOwnerID()` is non-zero → permanently inconsistent state; `HasOwner() != (GetOwner() != null)` invariant broken |
| β risk 2 | `attack.cpp:2631-2656` (kill credit) | `if (give_exp && give_exp->HasOwner())` fires BEFORE the `IsCompanion()` special case at line 2657. With β, `HasOwner()` returns true → `give_exp = nullptr` → companion kills give NO XP to player. Existing comment at line 2657 explicitly notes the workaround for the gap β would re-introduce |
| β risk 3 | `npc.cpp:2239-2262` (FillSpawnStruct) | `if (GetOwnerID()) { ns->spawn.is_pet=1; SetPetOwnerClient(true); }`. Companion override resets is_pet=0 but `pet_owner_client` flag is still set — would side-affect IsPetOwnerOfClientBot path |
| β risk 4 | `entity.cpp:708-713` (AddNPC zone-load) | `owner->SetPetID(npc->GetID())` overwrites the player's actual summoned pet's petid |
| β risk 5 | `npc.cpp:583-594` (NPC::Process depop) | depop path clears petid=0 on the companion and ownerid handling |
| β risk 6 | `spells.cpp:2413` (CazicTouch) | `if (spell_target->HasOwner()) { spell_target = owner; }` — Cazic Touch on companion redirects to owner client |
| β risk 7 | `spells.cpp:4075-4087` (blocked pet buffs) | Blocked pet buffs would fire for companions when player has them on the blocked-pet-buff list |
| β risk 8 | `spells.cpp:3761` (buff sync packet) | Every buff applied to companion would trigger `SendPetBuffsToClient()` packet |
| β risk 9 | `npc.cpp:672` (HP regen pet branch) | Companions would fall into `GetOwnerID() != 0` branch (owned-pet regen) instead of `!IsPet()` branch (NPC OOC regen). Functionally equivalent for HP, but CODE PATH is different — interaction with sitting bonus could differ subtly. **Also a BUG-003 vector from β** |

**Architect verdict:** Fix shape β is unequivocally rejected. The 9-side-effect enumeration is exactly the V3R Architecture Mandate "fix that subtly breaks adjacent functionality" pattern in microcosm. **Fix shape α is locked.**

**Major finding C-12 — Fix shape α specification with code sketch:**

c-expert provided a precise code sketch of Fix α at `aggro.cpp:867`:

```cpp
else if(_NPC(mob2)) {
    // Block client from attacking its own companion
    if (mob2->IsCompanion() &&
        mob2->CastToNPC()->CastToCompanion()->GetOwnerCharacterID() != 0) {
        if (mob1->IsClient()) {
            auto* c = mob1->CastToClient();
            auto* grp = c->GetGroup();
            Companion* comp = mob2->CastToNPC()->CastToCompanion();
            if (comp->GetOwnerCharacterID() == c->CharacterID()) {
                return false;
            }
            if (grp && grp->IsGroupMember(mob2)) {
                return false; // companion of a group member
            }
        }
    }
    return true;
}
```

**Architect refinement:** c-expert's sketch elegantly handles BOTH "owner's own companion" AND "group member's companion" via the same branch. **This is BETTER than my Round 3 fix-shape-α specification** which only checked owner. Cross-group companion protection is the correct extended behavior — when adventuring as a multi-player group, party A's caster shouldn't AoE-hit party B's companion either.

**Important architectural correction:** c-expert C-12 also reveals that **Fix W is ONE site, not two.** Both `EntityList::AESpell` (effects.cpp:1198) and `SpellOnTarget` (spells.cpp:3920) call `caster->IsAttackAllowed(target, true)`. Fixing the base function once covers both call sites. **The `IsPetOwnerOfClientBot` path (D.4) does NOT need a separate fix** — c-expert's D.4 entry says "Not applicable as a standalone fix — too narrow (only covers one spell target type). Fix α covers all detrimental AoE."

This simplifies the V3R Round 3 fix specification: **Fix W is one site (Mob::IsAttackAllowed at aggro.cpp:867), not two.** Updates the implementation surface estimate from "~10-15 lines C++ across 2 sites" to "~10-15 lines C++ at 1 site."

**Major finding C-13 — Q2 dead-entity skips: heartbeat + despawn timer BOTH unconditional confirmed:**

c-expert provided the precise table for Fix V Option A:

| Block | Inside `if (!is_dead)` | Correct? |
|---|---|---|
| `m_ping_timer` heartbeat | NO — outside, always runs | Yes — dead entities must send position keepalives |
| `m_death_despawn_timer.Check()` | NO — outside, always runs | Yes — auto-dismiss must fire for dead entities |
| Sitting regen bonus | YES — skipped for dead | Yes — dead entities don't regen |
| Mana gsay report | YES — skipped for dead | Yes — dead caster shouldn't report mana |
| LOM announcement | YES — skipped | Yes |
| AI dispatch / combat / attacks | YES — skipped | Yes |
| Rez-delay timer | YES — skipped | Yes |
| Retention check timer | YES — skipped | Yes |

**Architect verdict:** Confirms V3R architecture Round 3 fix-shape-V specification exactly. No revision needed.

**Major finding C-14 — Q3 git audit CLOSES G-5a definitively (BUG-003 hypothesis refinement):**

c-expert ran the git audit on `Companions:CompanionManaRegenMult`. **Result: the rule has been at default value 100 across ALL commits in git history.** It was never set to a higher value and reset.

**This refines the BUG-003 architecture narrative:**
- The G-10 hypothesis ("rule-tuning divergence — player has 1.75x, companion has 1.0x") still stands as the leading explanation for the structural gap
- BUT the user's "back to being extremely slow" framing is now SHARPER: it's NOT "a prior fix was reset." It's likely "the user's perception of regen parity has degraded over time as the player's `Character:ManaRegenMultiplier=175` was tuned higher without matching the companion multiplier"
- **Branch B-rule fix narrative should be framed as "introducing parity" not "restoring a regressed value"** — V3R-D5 / V3R-D6 documentation needs this nuance

**Major finding C-15 — Q3 regen scaling: NO V2 vector confirmed:**

c-expert's `CalcManaRegen` enumeration confirms ZERO scaling factors depend on V2-touched state:
- `spellbonuses.ManaRegen` — restored by Load() → CalcBonuses() in rez path
- `itembonuses.ManaRegen` — restored by Load() → LoadEquipment() → CalcBonuses()
- `aabonuses.ManaRegen` — always 0 for companions (no AAs)
- `CompanionManaRegenMult` — always 100 across git history (C-14 audit)
- `AlwaysMeditateRegen` — always true since BUG-027 commit
- Group membership: NOT consulted by CalcManaRegen
- Owner pointer: NOT consulted

**This is the four-advisor convergence on BUG-003 cleanly closed at the C++ level.** Combined with lua-expert L-1 (gsay reporting C++-only, no Lua dependency) and protocol-agent P-3 (no Titanium client interpolation), the only remaining vector for "actual regen broken" is a hypothetical undiscovered code path that none of four advisors found. **G-10 rule-tuning divergence (Branch B-rule) remains the only viable hypothesis with code/data-grounded support.**

**Major finding C-16 — Q4 group-operations ordering: Fix A has ZERO Lua-visible side effects:**

c-expert's enumeration of `Group::AddMember`, `MemberZoned`, `GroupMessage`, `GroupCount`:

- `Group::AddMember` populates BOTH `members[i]` AND `membername[i]` atomically
- `Group::MemberZoned` NULLs ONLY `members[i]`; `membername[i]` is intentionally preserved (per inline comment "should NOT clear the name, it is used for world communication")
- `Group::GroupMessage` iterates `members[]` via `ValidateMember(i)` (pointer check) — does NOT iterate `membername[]`
- `Group::GroupCount` counts non-empty `membername[i]` slots — does NOT check `members[]`
- Fix A is the explicit fix for `GroupCount` over-counting dead companions and `AddMember` name-collision-check blocking re-join

**c-expert's verdict on Q4:** Fix A's `membername[i]` clear has NO Lua-visible effect on any Lua-callable group method. `Group::IsGroupMember`, `Group::GroupMessage`, `Group::GetMember` ALL use `members[]` (pointer array). Lua-expert L-2's flagged concern is fully addressed. **Fix A is correct and has zero Lua blast radius.**

---

**Architect Round 2 absorbs C-11 through C-16 fully.** Net architecture impact:

1. **β fully ruled out** with 9-side-effect enumeration. V3R-D4 reaffirmed with stronger backing.
2. **Fix W simplified from 2 sites to 1 site.** Implementation surface reduced. Round 3 fix specification needs updating to reflect this.
3. **c-expert's α code sketch handles cross-group-member companions** — better than my Round 3 spec. Round 3 fix spec updated.
4. **Q2 confirms heartbeat + despawn timer both unconditional** — V3R-D10 reaffirmed.
5. **Q3 git audit closes G-5a definitively** — BUG-003 narrative refined: "introducing parity," not "restoring."
6. **Q4 closes lua-expert L-2 carry-forward** — Fix A's Lua blast radius is zero.

**Round 2 substantively COMPLETE.** All carry-forward questions resolved with code-grounded specificity. The V3R architecture document needs three minor revisions:
- Fix W spec: 1 site, not 2
- α code sketch updated to include group-member-companion exclusion
- BUG-003 narrative refined per C-14


---

### 2026-04-29 — architect → c-expert: Round 2 closed; architecture refinements logged; implementation tasks queued

**From:** architect → **To:** c-expert

All Round 2 findings (C-11 through C-16) integrated into V3R architecture document. Key impacts:
- C-11: β ruled out with full 9-side-effect enumeration
- C-12: Fix W simplified from 2 sites to 1 (AESpell and SpellOnTarget both call base IsAttackAllowed; single-site fix covers both). α code sketch with cross-group-member-companion exclusion adopted.
- C-13: Q2 confirms heartbeat + despawn timer both unconditional. V3R-D10 spec reaffirmed.
- C-14: G-5a closed — CompanionManaRegenMult never higher than 100. BUG-003 narrative = "introducing parity" not "restoring."
- C-16: L-2 closed — Fix A zero Lua blast radius confirmed.

Implementation tasks for c-expert when spawned:
- V3R.2 (Fix V Option A): B.1 heartbeat + B.2 despawn timer outside if(!is_dead); B.3-B.11 inside. Formal enumeration is the implementation map.
- V3R.3 (Fix W α): Single site aggro.cpp:867, _CLIENT vs _NPC branch. Cross-group-member-companion exclusion in scope. Test W.1 (aoe_excludes_owner_companion) + optional cross-group-member test.

Round 1 + Round 2 fully closed for c-expert. Awaiting user approval of V3R architecture before implementation team spawned.

### 2026-04-29 — config-expert → architect: G-10 CORRECTION + Follow-ups 1 & 2 (HP regen gap is REAL)

config-expert delivered Follow-ups 1 and 2 with a **critical correction to the G-10 hypothesis** that materially changes the BUG-003 architecture narrative. This is exactly the kind of late-arriving corrective input that the V3R Architecture Mandate's review-pass discipline exists to catch.

**Major finding G-14 — G-10 hypothesis CORRECTED: companions DO get `Character:ManaRegenMultiplier`:**

config-expert read `Companion::CalcManaRegen()` at `companion.cpp:1548-1549`:

```cpp
regen = (regen * RuleI(Character, ManaRegenMultiplier)) / 100;
regen = (regen * RuleI(Companions, CompanionManaRegenMult)) / 100;
```

**Companions apply BOTH multipliers sequentially.** `Character:ManaRegenMultiplier=175` IS already being applied to companion mana regen — it is not a player-only path. **The G-10 hypothesis ("companions miss the 1.75x because that rule only applies to Characters") is INCORRECT based on code inspection.**

**Architect verdict — major architecture correction:**

The leading BUG-003 hypothesis (rule-tuning divergence creating a structural 1.75x gap) is **REFUTED**. There is no mana-regen tuning gap. Companions already get the 1.75x player multiplier on top of their base regen formula.

**Implication for V3R-D5 / V3R-D6:** The "Branch B-rule = bump CompanionManaRegenMult to 175 to introduce parity" framing is wrong. The bump is no longer a fix; it would over-scale (1.75x × 1.75x = 3.06x effective rate) and break the intended balance.

**Updated BUG-003 diagnosis tree (post-G-14):**

- ~~**Branch (d) — Rule-tuning divergence (G-10):** REFUTED~~
- **Branch (a) — Actual server-side regen broken at code level:** RANKED HIGHER (no longer ranked LOW)
- **Branch (b) — Misperception / freshly-rezzed climb from 0 mana:** Still PLAUSIBLE
- **Branch (c) — Indirect via buff loss (lua-expert L-8):** Still PLAUSIBLE-LOW

**Major finding G-15 — Test 1.5 RE-FRAMED as a code-path diagnostic, not a fix candidate:**

config-expert correctly notes that the `CompanionManaRegenMult` bump test is still valuable per V3R Mandate 3 — but its purpose is now DIAGNOSTIC, not a fix:

**Test 1.5 (revised):** Bump `Companions:CompanionManaRegenMult` from 100 to 200 (giving 2x scaling on top of existing 1.75x — clear visible signal). Observe.
- If regen DOUBLES → companion IS hitting `Companion::CalcManaRegen()` correctly. BUG-003 is likely misperception/freshly-rezzed. Close as non-regression.
- If regen is UNCHANGED → companion is NOT hitting `Companion::CalcManaRegen()`. V2 broke the custom regen code path. **Escalate to c-expert for full NPC::Process() regen-path trace.**

**Architect interpretation:** The test now discriminates between "companion is in the right code path with rule-bump-irrelevant base behavior" (= misperception) vs "companion is in the WRONG code path entirely" (= V2 regression we haven't found yet). **This is a more valuable test than the prior framing** — it surfaces a code regression if one exists.

**Major finding G-16 — HP regen gap is REAL and predates V2:**

config-expert grep'd `HPRegenMultiplier` usage across the zone source:

```
client_mods.cpp:295  — Client::CalcHPRegen()       → applies Character:HPRegenMultiplier
client_mods.cpp:311  — Client::CalcHPRegenCap()    → applies Character:HPRegenMultiplier
bot.cpp:6334          — Bot::CalcHPRegenCap()       → applies Character:HPRegenMultiplier
bot.cpp:6731          — Bot::CalcHPRegen()          → applies Character:HPRegenMultiplier
merc.cpp:444          — Merc::CalcHPRegen()         → applies Character:HPRegenMultiplier
merc.cpp:453          — Merc::CalcHPRegenCap()      → applies Character:HPRegenMultiplier
companion.cpp         — NOT PRESENT
```

**`Companion::CalcHPRegen()` at companion.cpp:1493-1506 does NOT apply `Character:HPRegenMultiplier`.** Bots, Mercs, and Clients all do; Companions don't. This is a real structural gap that predates V2.

| Entity | HP regen multiplier | Mana regen multiplier |
|---|---|---|
| Player (Client) | `Character:HPRegenMultiplier = 200` (2x) | `Character:ManaRegenMultiplier = 175` (1.75x) |
| Bot | 2x (applied) | 1.75x (assumed applied; not verified) |
| Merc | 2x (applied) | 1.75x (assumed applied; not verified) |
| Companion | **1x (NOT applied)** | **1.75x (applied in CalcManaRegen)** |

**Architect interpretation:** The user's report says "Mana and health regen seem to be screwed up again" — explicitly mentioning BOTH. **For HP regen, there IS a real gap.** It's not a V2 regression (predates V2), but it IS a fix candidate for the V3R rule path because:
1. The user noticed it
2. Bots, Mercs, and Clients all get the multiplier — companions are inconsistent with sibling NPC types
3. The fix is small (one-line addition in `CalcHPRegen` OR new `Companions:CompanionHPRegenMult` rule + apply it)

**Architect decision V3R-D12 (NEW):** **Add HP regen parity fix to V3R scope** — but ONLY as an empirical-confirmed fix per Mandate 3. The V3R-Empirical-1 protocol must include an HP regen Test 1 + Test 1.5 parallel to the mana regen tests. If empirical confirms the gap, the fix is small. If empirical shows the user's HP regen perception is fine, the fix is descoped to a follow-up bugfix.

**Refined fix shape options for HP regen (architect's call):**

Option α-HP: Apply `Character:HPRegenMultiplier` directly in `Companion::CalcHPRegen()` (one-line C++ change). Pro: matches Bot/Merc/Client behavior pattern; no new rule. Con: removes operator's ability to tune companion HP regen separately.

Option β-HP: Add new `Companions:CompanionHPRegenMult` rule (default 100) + apply it in `Companion::CalcHPRegen()`. Pro: parallel to `CompanionManaRegenMult`; operator-tunable. Con: introduces a new rule + corresponding ruletypes.h entry + rule_values INSERT.

**Architect lean: Option α-HP (one-line C++).** Per V3R minimum-surface principle: zero new rule, zero new operator-tuning surface, matches Bot/Merc/Client pattern. The `Character:HPRegenMultiplier` rule already exists; no need to duplicate the concept.

**Major finding G-17 — Follow-up 1 SQL statements (mana diagnostic, not fix):**

```sql
-- Apply (bump to 200 for clear 2x signal on top of existing 1.75x in CalcManaRegen)
UPDATE rule_values
SET rule_value = '200'
WHERE ruleset_id = 1 AND rule_name = 'Companions:CompanionManaRegenMult';

-- In-game: #reloadrules

-- Rollback (restore to 100)
UPDATE rule_values
SET rule_value = '100'
WHERE ruleset_id = 1 AND rule_name = 'Companions:CompanionManaRegenMult';

-- In-game: #reloadrules
```

**Test interpretation (corrected):**
- regen DOUBLES → CalcManaRegen() being hit → BUG-003 likely misperception → close as non-regression
- regen UNCHANGED → CalcManaRegen() being BYPASSED → V2 broke custom regen path → escalate to c-expert

---

**Architect Round 2.5 absorbs G-14, G-15, G-16, G-17.** This is the third major architecture-corrective late input (alongside data-expert D-11 SQL polling correction and c-expert C-12 1-site Fix W simplification). All three demonstrate the V3R Architecture Mandate review-pass discipline working correctly — late corrections caught before V3R implementation begins.

**Architecture document needs FOURTH refinement section to capture G-14/G-15/G-16/G-17.**


### 2026-04-29 — protocol-agent → architect: Round 1 FORMAL ENUMERATION DELIVERED (26 consumers + 1 NEW GAP + 1 open question)

protocol-agent has delivered the full structured Round 1 enumeration (26 consumers across areas A–G). **Five-advisor Round 1 is now FULLY closed.** The formal enumeration confirms all prior advisor convergences AND surfaces one new gap that the V3R architecture had not flagged.

**Major finding P-4 — All three bug-attribution verdicts INDEPENDENTLY CONFIRMED:**

- **BUG-002 (A.1, G.1):** Fix R4 → m_ping_timer skipped → Titanium culls. Fix V Option A correct site. **No Titanium protocol changes needed.** Confirms c-expert C-1 / B.1 + protocol-agent P-1 (now formally backed by code-grounded enumeration).
- **BUG-004 (C.1, F.1):** `_NPC(companion) = true` because `GetOwnerID()=0`. Client AoE allowed unconditionally. **Fix is 100% server-side.** No Titanium packet changes. Confirms c-expert C-2 + config-expert G-3 + data-expert D-3 (now four-advisor convergence on the BUG-004 root cause).
- **BUG-003 (D.3, G.5):** Zero protocol-layer signal. gsay report is a 15-second C++ timer reading `GetManaRatio()` live. Titanium has no NPC mana display and no mana interpolation. **Empirical SQL measurement is the definitive discriminator.** Confirms lua-expert L-1 + c-expert C-3 + config-expert G-5 + data-expert D-9.

**Major finding P-5 — NEW gap flagged (A.3 — SendArmorAppearance on rez path):**

`EntityList::AddCompanion()` (entity.cpp:4047-4076) does **NOT** call `SendArmorAppearance()`, unlike `EntityList::AddNPC()` at `entity.cpp:737` which **does**. Pre-V2 rez path used `AddNPC()` → called `SendArmorAppearance()` → companion appearance correctly rendered post-rez. Post-V2 rez path uses `AddCompanion()` (via `Spawn(owner)` Fix B) → does NOT call `SendArmorAppearance()` → **companion may render naked/default appearance after rez.**

protocol-agent's flag for c-expert: confirm whether `ResurrectFromCorpse` calls `SendArmorAppearance()` elsewhere after `Spawn()` returns, OR whether the post-rez companion has visible armor at all.

**Architect interpretation:** This is a DIFFERENT class of issue than BUG-002/003/004 — it's a visual/cosmetic concern, not a behavioral one. The rezzed companion's combat behavior, regen, AoE filtering, etc. are all unaffected. The user has not reported "rezzed companion appears naked" but it's a pre-existing-or-V2-regression visual concern that should be enumerated.

**V3R architecture decision V3R-D13 (NEW):** The A.3 SendArmorAppearance gap is **NOT in V3R scope** unless either:
1. game-tester scenario V3R-8 (multi-rez cycle) reveals visible armor regression in-game (then file as a follow-up bugfix or expand V3R scope)
2. c-expert confirms `ResurrectFromCorpse` does NOT handle armor appearance elsewhere (then file as a follow-up bugfix)

**This is a discovery for game-tester to verify in V3R-8.** Adding a bullet to V3R-8 scenario: "After each rez cycle, observe companion's visual appearance — does the companion render its equipped armor, or does it appear naked/default?"

**Major finding P-6 — Open question routed to c-expert: did pre-V2 manual AddNPC call SetOwnerID on companions?**

protocol-agent flags: if pre-V2 the manual `AddNPC` path called `SetOwnerID()` on companions, then `_NPC(companion)=false` pre-V2 → AoE correctly excluded companions → Fix B removing the SetOwnerID call would be a V2 regression. If pre-V2 the manual path did NOT call `SetOwnerID()` → BUG-004 is a pre-existing gap.

The wire-format manifestation is `petOwnerId=0` in the spawn packet (`eq_packet_structs.h:267`) — this field feeds `GetOwnerID()` directly and is pre-existing for companions per protocol-agent's reading.

**Architect cross-reference to existing convergence:**

c-expert C-2 + config-expert G-3 + data-expert D-3 + c-expert C-9 + c-expert C-11 (β-risk-2 explicitly cites the comment at attack.cpp:2657 noting "Companions use m_owner_char_id / GetCompanionOwner() rather than the standard Mob ownerid field, so HasOwner() returns false for them") **all confirm companions have NEVER called SetOwnerID().** The system was designed this way from the start.

**P-6 verdict: BUG-004 root cause is a PRE-EXISTING gap, not a V2 regression.** Confirmed by five-advisor Round 1 convergence. No architecture change needed.

**Major finding P-7 — Fix B was a NET protocol correctness IMPROVEMENT, not a regression:**

protocol-agent flags Fix B's net protocol gains:
- `NPC=0` override now applied (was `NPC=1` via AddNPC pre-V2)
- `is_pet=0` override applied
- Name normalization applied

These are CORRECTNESS improvements on the rez path. Pre-V2, rezzed companions had `NPC=1` and `is_pet` was undefined, which was a less-correct wire-format state.

The `petOwnerId=0` situation is a pre-existing design choice (companions use `m_owner_char_id`, not `ownerid`) — unchanged by V2. **V2 Fix B did not introduce the petOwnerId=0 situation; it has always been the case for companions.**

**Architect interpretation:** This finding STRENGTHENS the V3R-D4 fix-shape α decision. β (SetOwnerID) would NOT be "restoring a pre-V2 state" — it would be introducing a new state companions have never had. The 9-side-effect blast radius c-expert enumerated in C-11 is therefore the full unmitigated risk of β.

**Major finding P-8 — Net protocol-side enumeration count: 26 consumers, all confirming server-side fix is correct:**

protocol-agent's full enumeration covers:
- (A) Position-update / visibility heartbeat — 3 consumers
- (B) Group / raid / party display packets — 4 consumers
- (C) AoE spell target packets — 3 consumers
- (D) Mana / HP update packets — 4 consumers
- (E) Pet / Companion identification packets — 4 consumers
- (F) Spawn-struct fields — 4 consumers
- (G) Titanium-specific constraints — 4 consumers

**Total: 26 consumers across 7 categories.** The full text is in protocol-agent's response (not duplicated here for log brevity). All confirm: BUG-002 fix is at the right site, BUG-004 fix is server-side-only, BUG-003 has zero protocol vector, A.3 SendArmorAppearance is the only NEW gap surfaced.

---

**Architect Round 1 substantively COMPLETE for all five advisors.** Five-advisor convergence on all three (now four) bug root-cause attributions. ONE new gap (A.3) identified outside V3R scope but flagged for V3R-8 game-tester scenario to verify.

**Net architecture impact:**
1. All prior architecture decisions REAFFIRMED — no decision reversal
2. **NEW V3R-D13:** A.3 SendArmorAppearance gap flagged for V3R-8 game-tester verification scenario; not in V3R scope unless empirically confirmed
3. V3R-Empirical-1 protocol unchanged
4. Fix V + Fix W specifications unchanged
5. BUG-005 status unchanged


### 2026-04-29 — c-expert → architect: Section D Supplement — DEFINITIVE BUG-004 verdict (Fix A irrelevant, AoE filter has zero group awareness)

c-expert delivered the Section D supplement directly answering the lua-expert L-5 cross-reference question (Q1-Q4). **This is the definitive close-out on BUG-004 root cause analysis.**

**Major finding C-17 — `Mob::IsAttackAllowed` has ZERO group-membership checks:**

c-expert traced the full execution flow of `Mob::IsAttackAllowed` (`aggro.cpp:732-982`) in order:

1. `zone->CanDoCombat()` — zone-wide combat flag
2. Null target check
3. Self-attack pass-through
4-8. Special ability immunity flags (`HarmFromClientImmunity`, `BotDamageImmunity`, `ClientDamageImmunity`, `NPCDamageImmunity`, `IsHorse`)
9. **Pet ownership** — `target_owner = target->GetOwner()` / `our_owner = GetOwner()` (reads `ownerid` only)
10. Bot-specific block (only fires when caster is a Bot)
11. Swarm-pet corpse-owner invalidation
12. Body type untargetable check
13. LDoN treasure class check
14. Pet reduction: `mob1 = our_owner ? our_owner : this; mob2 = target_owner ? target_owner : target`
15. **Type matrix** — `_CLIENT`, `_NPC`, `_BECOMENPC`, `_CLIENTCORPSE`, `_NPCCORPSE` only

**Zero calls to `IsGroupMember`, `SameGroup`, `GetGroup`, `members[]`, `membername[]`, or any group structure anywhere in the function.**

**Major finding C-18 — `EntityList::AESpell` loop ALSO has zero group-membership reads:**

c-expert traced the per-mob filter chain in `EntityList::AESpell` (`effects.cpp:1127-1230`):

1. ClientFinishedLoading guard
2. Self-exclusion
3-7. Type-flag filters (`ST_TargetAENoPlayersPets`, `ST_AreaClientOnly`, `ST_AreaNPCOnly`, `pcnpc_only_flag == PC`, `pcnpc_only_flag == NPC`)
8. AxisAlignedBox + distance checks
9. Faction check (NPC caster only — reads `GetReverseFactionCon`, not group data)
10. `caster_mob->IsAttackAllowed(current_mob, true)` — the type matrix gate
11. LoS check

**Zero group structure reads anywhere in the AESpell loop.** Every filter uses type-flag methods or the `IsAttackAllowed` type matrix.

**Major finding C-19 — Fix A is COMPLETELY IRRELEVANT to BUG-004 (definitive):**

The bug reproduces identically for:
- **Live companion freshly recruited** (never died): members[] populated, membername[] populated → AoE still hits it
- **Rezzed companion post-V2:** members[] populated (via Spawn), membername[] populated → AoE still hits it
- **Dead companion pre-V2** (hypothetical): members[] NULL, membername[] stale → AoE still would have hit it

**The AoE filter is BLIND to group membership for ANY entity type.** It only knows about:
- ownerid/petid (standard pet system)
- type flags (`IsClient`, `IsNPC`, `IsBot`, `IsCompanion`, etc.)
- faction (NPC caster only)
- LoS

The companion system deliberately bypasses ownerid (uses `m_owner_char_id` instead) — that bypass is the gap.

**Major finding C-20 — Fix α is necessary AND sufficient:**

C-12's α code sketch at `aggro.cpp:867` (in the `_CLIENT vs _NPC` branch) is the complete fix. The fix only needs to address the alive case because:
- AESpell uses type-flag filters BEFORE reaching `IsAttackAllowed` — `_NPCCORPSE` macro returns false for NPC corpse targets, so dead-companion-as-corpse is excluded by earlier filters
- No dead-then-rezzed transient case exists in the AoE filter pipeline
- The fix at the `_NPC(x)` matrix branch covers all live-companion cases (recruit, post-rez, post-zone-in)

**Major finding C-21 — `entity.cpp:5636` cone AoE precedent is a DIFFERENT code path (not AESpell):**

c-expert clarifies: `GetTargetsForConeArea` at `entity.cpp:5636` DOES have `!ptr->IsCompanion()` filter (config-expert G-4's flagged precedent). HOWEVER, this is a DIFFERENT code path from `AESpell` — used by a different subset of spells (cone-shaped AoE).

**The fact that cone AoE excludes companions but `AESpell` doesn't is an EXISTING INCONSISTENCY** that Fix α would resolve for the `AESpell` path. After Fix α ships, both AoE paths will consistently exclude owner's companions.

**Architect interpretation — final convergence:**

This is the architecture's last open analytical point. BUG-004 root cause is now:
- **Five-advisor convergence on root cause** (c-expert C-2 + config-expert G-3 + data-expert D-3 + protocol-agent C.1/F.1 + c-expert C-17/C-18/C-19/C-20)
- **Fix shape α confirmed necessary AND sufficient** at single site `aggro.cpp:867`
- **Fix shape β fully ruled out** with 9-side-effect blast-radius enumeration (c-expert C-11)
- **L-5 cross-reference question definitively closed** — AoE filter has zero group-membership awareness for any entity type
- **Existing cone-AoE precedent at entity.cpp:5636 is structural inspiration, not implementation reference** — Fix α at `aggro.cpp:867` is the canonical fix that brings AESpell into consistency with the cone path

**No outstanding architectural questions on BUG-004.** Implementation surface is locked: ~10-15 lines C++ at one site. Test W.1 covers verification. V3R-3 PRIMARY scenario (in-game) and V3R-9 sustained AoE encounter cover validation.


---

### 2026-04-29 — architect → c-expert: Section D supplement closed; all analysis complete

**From:** architect → **To:** c-expert

Section D supplement logged as C-17 through C-21. BUG-004 definitively closed at all layers:
- C-17: IsAttackAllowed has zero group-membership reads (full execution trace)
- C-18: AESpell loop has zero group-membership reads (full filter chain trace)
- C-19: Fix A completely irrelevant to BUG-004 — bug reproduces identically for live/rezzed/dead companions
- C-20: Fix α necessary and sufficient at single site; dead-companion-as-corpse excluded by _NPCCORPSE macro earlier in chain
- C-21: entity.cpp:5636 cone AoE is a different code path; Fix α brings AESpell into consistency with cone path

Architecture at FINAL consolidation. V3R fix shape locked:
- Fix V Option A: BUG-002 + BUG-005 (Companion::Process restructure)
- Fix W α: BUG-004 (single site aggro.cpp:867, cross-group-member-companion exclusion)
- Conditional V3R-D12 α-HP: BUG-003 HP gap (CalcHPRegen one-line)
- V3R-Empirical-1 8-test protocol: BUG-003 gate
- A.3 SendArmorAppearance: V3R-8 verification only, not in fix scope

Round 1 + Round 2 + Section D supplement ALL CLOSED for c-expert. Implementation tasks V3R.2 + V3R.3 + (conditional) V3R.3.5 queued for implementation phase. Standing by for user approval.

### 2026-04-29 — protocol-agent → architect: Round 1 Targeted Follow-up (FU-1 to FU-5)

protocol-agent has delivered the four targeted deep-dive follow-ups (FU-1 through FU-4) plus FU-5 (uncertain-item antagonistic close-out). **Two important corrections to prior architecture decisions emerge:** A.3 SendArmorAppearance gap is RETRACTED, and C-10 atomic-rez coexistence concern is RESOLVED.

**Major finding P-9 — A.3 SendArmorAppearance gap RETRACTED (FU-1):**

protocol-agent's earlier P-5 finding flagged that `EntityList::AddCompanion()` doesn't call `SendArmorAppearance()`, suggesting rezzed companions might render naked. **FU-1 reads the actual rez ordering** and retracts this:

- The rez path calls `Load()` → `LoadEquipment()` at `companion.cpp:3693` **BEFORE** `Spawn()` → `FillSpawnStruct()` at `companion.cpp:3703`
- `LoadEquipment()` populates `m_equipment[]`
- `FillSpawnStruct` reads `GetEquipmentMaterial()` from `m_equipment[]`
- **The initial spawn packet already includes correct equipment textures in `equipment.Slot[i].Material`**
- The `SendArmorAppearance` call in `AddNPC` sends a follow-on `OP_WearChange` UPDATE, but the initial spawn packet already carries the data

**No visual regression.** Pre-V2 AddNPC sent the spawn packet WITH equipment AND a follow-on OP_WearChange. Post-V2 AddCompanion sends ONLY the initial spawn packet, but that initial packet already has the equipment. Functionally equivalent for visual rendering.

The `SetAppearance(GetGuardPointAnim())` OP_SpawnAppearance call in AddNPC is also not a regression — companions have `StandState` set correctly in the spawn struct at `mob.cpp:1330`, and `Process()` handles sit/stand transitions via OP_SpawnAppearance on every tick as needed.

**Architect interpretation:** **V3R-D13 is REVERSED.** The A.3 SendArmorAppearance gap is NOT a real concern. **No V3R-8 verification scenario needed for visual rendering** (or it can stay as a low-priority observational note, but it's not flagging a real risk).

**Major finding P-10 — Group window targeting was BROKEN pre-V2, FIXED by Fix B (FU-2):**

protocol-agent's FU-2 reveals an UNDOCUMENTED net positive of Fix B:

- **Pre-V2:** spawn packet `name = "Guard_Liben001"` (raw `MakeNameUnique` name); group window `membername = "Guard Liben"` (GetCleanName). **These diverged** — Titanium click-to-target in the group window silently failed because the click resolved to "Guard Liben" but the server-side entity was registered as "Guard_Liben001."
- **Post-V2 Fix B:** `Companion::Spawn()` calls `strcpy(name, GetCleanName())` at `companion.cpp:2430-2431` BEFORE `AddCompanion`. Spawn packet name = "Guard Liben"; group window membername = "Guard Liben". **These match.**

**Fix B is a protocol-correctness improvement for group window targeting.** This is yet another reason β (SetOwnerID) would be wrong — β would not address this name-divergence issue, which Fix B incidentally also resolved.

**Major finding P-11 — m_owner_char_id feeds ZERO packet-emission paths (FU-3):**

protocol-agent traced the `m_owner_char_id` field (companion-specific): it is used only for AI logic, group join, IsFriendlyTarget, and DB queries. **It feeds NO packet-emission paths.** The packet-emission ownership goes through `ownerid` / `GetOwnerID()`, which is always 0 for companions.

V2 Fix B's `Spawn(owner)` path sets `m_owner_char_id` via `SetOwnerCharacterID()`. No change to `ownerid` / `GetOwnerID()`. **No client-visible packet that reads the owner pointer differs between pre-V2 and post-V2 paths.**

**Architect interpretation:** Confirms that the Titanium client has no client-side knowledge of the companion's owner. All ownership-aware filtering must be server-side. Reinforces V3R-D4 (α-over-β) and confirms BUG-004 fix is purely server-side.

**Major finding P-12 — Titanium pet-rendering implications confirm server-side fix is the only path (FU-4):**

- `petOwnerId=0` for companions → Titanium renders NO pet healthbar AND does NOT associate them with the pet window. **Correct — companions appear in the group window, not the pet window.**
- `is_pet=0` → Titanium colors companions as neutral entities, not as pets. Combined with `NPC=0`, companions appear player-like with neutral coloring.
- **Critical:** Even if Titanium colored companions green, the server's AESpell sweep would still hit them because Titanium does NOT compute AoE target lists (it receives `OP_Damage` per hit entity from the server). **Client-side coloring is irrelevant to BUG-004.**

The BUG-004 fix must be in `EntityList::AESpell` (effects.cpp:1199) or its chain — **no Titanium changes possible or needed.** Confirms V3R-D4 fix-shape decision and Fix W α at `aggro.cpp:867` as the canonical implementation site.

**Major finding P-13 — C-10 atomic-rez coexistence concern RESOLVED (FU-5):**

c-expert's C-10 antagonistic-pass flag (Fix C atomic-rez window where corpse + new companion entity coexist) had been carried forward as a "theoretical only" concern. protocol-agent's FU-5 resolves it definitively:

- **Corpses are in `corpse_list`, NOT in `mob_list`.**
- `EntityList::AESpell` iterates `GetCloseMobList()` which operates on `mob_list`.
- **The corpse is NOT in the AoE sweep target set during the coexistence window.**

**No doubled AoE hit risk from the Fix C atomic window.** The newly-rezzed companion IS in `mob_list` and IS subject to the BUG-004 gap (same risk as any other alive companion, addressed by Fix W α). **C-10 is closed.**

**Architect interpretation:** Fully resolves the antagonistic-pass uncertainty. V3R Validation Plan's V3R-8 multi-rez cycle scenario can drop the "verify no double-AoE during rez moment" verification (or keep it as low-priority defensive observation; not a real risk).

---

**Architect Round 1 + Round 2 + ALL refinement waves CLOSED. Final architecture state:**

**Two corrections to prior decisions absorbed:**
1. **V3R-D13 REVERSED:** A.3 SendArmorAppearance is NOT a real gap. Spawn packet already carries equipment textures via `LoadEquipment()` → `FillSpawnStruct` ordering. No V3R-8 verification scenario needed.
2. **C-10 atomic-rez coexistence RESOLVED:** corpses in corpse_list, not mob_list — no AoE doubling possible. V3R-8 verification scenario for this can drop.

**Two NEW positive findings:**
3. **P-10:** Fix B incidentally fixed the pre-V2 group-window-targeting name-divergence bug (further evidence that V2 was net protocol-correctness improvement).
4. **P-11:** `m_owner_char_id` feeds zero packet-emission paths — confirms BUG-004 fix is purely server-side with no Titanium client knowledge of companion ownership.

**No remaining open analytical questions.** Architecture is ready for user approval at the FINAL final consolidation point.


### 2026-04-29 — data-expert → architect: D-14 owner_id verified + D-15 CRITICAL command correction (#reloadrules DOES NOT EXIST)

data-expert delivered the final two close-out items: owner_id verification and a critical command correction.

**Major finding D-14 — `owner_id` column verified correct:**

Live schema query confirmed: the column in `companion_data` is `owner_id` (INT UNSIGNED, NOT NULL, indexed). The SQL snippet in D-13 is correct as written. V3R-Q3 (SQL column name verification) is CLOSED.

**Major finding D-15 — `#reloadrules` DOES NOT EXIST (architecture-document-wide correction):**

I had been documenting `#reloadrules` across multiple V3R artifacts based on a guess. **It does not exist as a GM command.** The correct command family is `#rules` per `gm_commands/rules.cpp`:

| Subcommand | Behavior |
|---|---|
| `#rules set [Rule] [Value]` | applies in-memory only, **reverts on zone restart** (safe for testing) |
| `#rules setdb [Rule] [Value]` | applies in-memory AND persists to DB (must be manually reverted) |
| `#rules reload` | reloads current ruleset from DB into memory |
| `#rules get [Rule]` | reads current in-memory value (use to verify) |

**Recommended Test 1.5 sequence (using safe transient path):**

```
#rules set Companions:CompanionManaRegenMult 175
#rules get Companions:CompanionManaRegenMult   ← verify = 175
[run 4-cycle observation]
#rules set Companions:CompanionManaRegenMult 100
#rules get Companions:CompanionManaRegenMult   ← verify reverted = 100
```

`#rules set` is preferred over `#rules setdb` for test isolation — transient, reverts on zone restart, no DB cleanup needed.

**Architect note — this is a `feedback_never_guess_commands.md` violation:**

Per MEMORY.md, the user's standing feedback explicitly says "Never guess commands; check `claude/docs/gm-commands-reference.md` first or ask the user." I documented `#reloadrules` across the V3R architecture without verifying. data-expert's catch is exactly the kind of correction the never-guess-commands discipline exists to prevent.

**Affected V3R artifacts that need correction:**
- `architect/architecture.md` V3R section (multiple references to `#reloadrules`)
- `architect/architecture.md` V3R Architecture Refinements I + II + III + IV + V sections (references in protocol descriptions)
- `architect/context/round-3-fix-proposal-and-task-breakdown.md` (Test 1.5 description)
- `architect/context/round-4-validation-plan.md` (Scenario V3R-4 Test 1.5)
- `status.md` V3R Implementation Tasks table (V3R.6.5 task description)
- `agent-conversations.md` (multiple architect responses)

**Architect interpretation:** Substantive ground-truth correction. The fix is mechanical (replace `#reloadrules` with `#rules set` or `#rules reload` depending on context). All instances need correction before V3R.6 game-tester runs the empirical protocol.


### 2026-04-29 — c-expert → architect: G-5a git audit DEFINITIVELY CLOSED

c-expert ran three independent queries (ruletypes.h diff history, git log -S, akk-stack SQL seed/migration search) on `Companions:CompanionManaRegenMult` history. All three converge:

**Major finding C-22 — `CompanionManaRegenMult` was introduced at 100 on 2026-03-10 and never changed:**

| Query | Result |
|---|---|
| ruletypes.h diff history | Single commit `d553ed62d` (2026-03-10) introduces rule at default=100. No prior value; no subsequent change. |
| `git log -S 'CompanionManaRegenMult' --all` | Two commits total: `d553ed62d` (introducing commit on bugfix/companion-bug-batch-2 — "fix(companions): add player-like mana regen using meditate formula") + `627aed644` (BUG-032 unrelated ruletypes.h touch that picked up the rule unchanged). Never set to non-100 value. |
| akk-stack SQL seed/migration search | Zero hits. No SQL migration set this rule. |

**There is no "regression from a prior higher value" in the git record.** V3R-Q1 / G-5a CLOSED.

**Major finding C-23 — Architecture narrative correctly stated as "introducing parity for the first time":**

c-expert's framing: "The prior fix that gave the user the 'for a long time the pace of their regen closely matched my own' baseline was commit `d553ed62d`'s introduction of `CalcManaRegen()` (the meditate formula). The user's comparison baseline is the meditate formula itself, not a multiplier value."

**Architect interpretation:** This explicitly confirms the V3R Refinements II R-7 framing. The user's "back to being extremely slow" report is one of:
- (a) Misperception — the meditate formula IS working correctly, and the user's perception of "matching" was always against an unscaled baseline. The 1.75x player multiplier was added/tuned higher AFTER 2026-03-10, creating the gap that finally became visible.
- (b) An actual code regression introduced AFTER 2026-03-10 by V2 that BYPASSES `CalcManaRegen()` entirely, preventing the meditate formula from running.

The Test 1.5 diagnostic (`#rules set Companions:CompanionManaRegenMult 200`) discriminates:
- If regen DOUBLES → CalcManaRegen IS firing → Branch B-misperception
- If regen UNCHANGED → CalcManaRegen IS BYPASSED → Branch A-code-regression → escalate to follow-up bugfix

**Major finding C-24 — V3R Architecture narrative is now FULLY consistent with git evidence:**

The V3R architecture document's BUG-003 narrative across all six refinement sections is reaffirmed:
- Branch B-misperception: most likely outcome (regen working, user's perception baseline drifted)
- Branch B-rule (was the original G-10 hypothesis): REFUTED by config-expert G-14 (`CalcManaRegen` already applies the 1.75x; the multiplier IS already being scaled)
- Branch A-code-regression: empirical-confirmable via Test 1.5 diagnostic
- HP regen parity (V3R-D12 α-HP): real structural gap predating V2; one-line C++ fix conditional on V3R-Empirical-1 confirming user perception

c-expert's git audit is the last piece of confirming evidence. The architecture narrative is now fully grounded in git history + code inspection + advisor convergence.


---

### 2026-04-29 — architect → c-expert: G-5a audit absorbed; architecture at final consolidation

**From:** architect → **To:** c-expert

G-5a results logged as C-22 through C-24. CompanionManaRegenMult never higher than 100 (C-22). Architecture narrative is "introducing parity for the first time" (C-23). 14 of 14 open questions resolved (C-24). Architecture at FINAL ABSOLUTE CONSOLIDATION POINT after seven refinement waves.

V3R-Q1 CLOSED definitively. Standing by for user approval. When approved: orchestrator creates BUG-005 file, spawns implementation team for V3R.1.

All rounds for c-expert: CLOSED.

### 2026-04-29 — data-expert → architect: D-16 BUG-005 report file CREATED + status.md updated

data-expert filed the BUG-005 report file at `/mnt/d/Dev/eq/claude/project-work/companion-rez/bugs/BUG-005-companion-auto-dismiss-timer-broken/report.md` and added a row to the V3 Re-Triage Bug Reports table in status.md.

**Note on workflow ownership:** Per CLAUDE.md, the orchestrator (not advisors) is the canonical owner of BUG-NNN report file creation from the bug-report template. data-expert created the file directly during V3R close-out work. The file exists and is correct (root cause attributed to V2 Fix R4 / `companion.cpp:1933-1935`; fix attribution to V3R Fix V Option A; bundled with BUG-002; severity Medium; assigned to c-expert), so the orchestrator's gate prerequisite for spawning the implementation team is now satisfied.

**Architect interpretation:** D-16 is operationally complete and correct. The orchestrator may want to confirm the BUG-005 report file matches their template/style preferences when relaying to the user; if not, the orchestrator can amend in place.

**Net architecture impact:** Task #16 (orchestrator-flag for BUG-005 file creation) is now operationally satisfied. No further architect action needed on BUG-005 documentation.

---

## V3R Implementation Team

### 2026-04-29 — team-lead → c-expert: Implementation brief

**From:** team-lead → **To:** c-expert

Brief: c-expert is implementation lead for V3R. Tasks: V3R.1 (TDD red — 3 failing tests in Suite 37), V3R.2 (Fix V Option A in Companion::Process()), V3R.3 (Fix W α in aggro.cpp:867), V3R.4 (rebuild + verify), V3R.7 (commit + push). Authoritative docs listed. BUG-003 descoped. W.1 behavioral test requires a real Client — unit test infrastructure cannot create one; behavioral assertion delegated to in-game V3R.6.

**Outcome:** c-expert acknowledged brief and proceeded.

---

### 2026-04-29 — c-expert → team-lead: V3R.1-4 complete

**From:** c-expert → **To:** team-lead

V3R.1 (TDD red commit 1c03ce9ea): Suite 37 added to `cli_companion_tests.cpp`. V.1 (ping timer for dead) and V.2 (despawn timer for dead) fail pre-fix as expected. W.1 is structural prerequisites (IsPingTimerEnabled, TriggerPingTimer, IsDeathDespawnTimerEnabled, TriggerDeathDespawnTimer test hooks added to companion.h). Note: the client-vs-companion behavioral assertion for BUG-004 cannot be unit-tested without a real Client object — W.1 verifies preconditions only; behavioral protection comes from in-game V3R.6.

V3R.2 (Fix V Option A): `Companion::Process()` restructured. Fix R4 blanket early-return replaced with `const bool is_dead = (GetHP() <= 0)`. Two `if (!is_dead)` blocks wrap all AI-dispatch sections. Heartbeat (m_ping_timer block) and death despawn timer block stay UNCONDITIONAL.

V3R.3 (Fix W α): `aggro.cpp` — added `companion.h` include. In the `_CLIENT vs _NPC` matrix branch (now line 868+), inserted IsCompanion guard: checks `mob2->IsCompanion() && GetOwnerCharacterID() != 0`, then if mob1 is a Client checks owner match OR group membership. Follows C-12 sketch exactly.

V3R.4: Rebuild clean (3 files recompiled, 0 warnings). Full Suite 37 green: V.1 PASS, V.2 PASS, W.1 PASS. All prior suites pass. Commits pushed to origin/bugfix/companion-rez (eqemu: 035d33348, claude: 716654a).

V3R.7 (commit+push): Complete — both eqemu and claude repos pushed to bugfix/companion-rez.

**Next:** V3R.5 (infra-expert server restart) and V3R.6 (game-tester in-game validation) are the remaining gates before the feature is complete.

