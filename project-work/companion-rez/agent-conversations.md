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
