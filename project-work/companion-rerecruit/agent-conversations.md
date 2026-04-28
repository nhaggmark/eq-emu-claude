# Companion Re-recruitment Fix — Agent Conversations Log

> **Feature branch:** `bugfix/companion-rerecruit`
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

### 2026-04-27 — Lore touchpoint: re-recruit invariant + Lydl the Great

**From:** game-designer → **To:** lore-master

> Drafting PRD for `companion-rerecruit` (BUG-001). Bug is mechanical: re-recruiting a previously-recruited NPC is blocked by level caps, cooldown timers, and a stale "dismissed" flag. User invariant: "Once I recruit a companion, I should always be able to re-recruit that companion after they die or otherwise drop out of the group. They become re-recruited with their gear and levels intact. There should be no rules around levels on re-recruiting companions. The idea is that I can recruit an NPC at level 5 and take them through the entire game with me."
>
> Asked lore-master two questions before sending full PRD for sign-off:
> 1. Lydl the Great (East Freeport) — anything in his lore (faction, deity, race, role, allegiances) that makes him a poor exemplar for a "follow the player from level 5 to 60+" companion arc?
> 2. Does the invariant itself ("an NPC can be recruited once and re-recruited indefinitely after death/dismissal, gear and level preserved") carry narrative landmines across Norrath at large — e.g., guards-with-jobs vanishing from their post needing flavor handling?

**Response from** lore-master:

> APPROVED — no lore blockers. Detailed findings:
>
> **Lydl the Great:** Level 4 human wizard, wandering "insane" Innoruuk-corrupted figure in North Ro / East Freeport. No stable city role, no home faction, no quest-giver function — framed as a hostile/kill target. Killing him helps Knights of Truth and hurts Dismal Rage / Opal Dark Briar. The companion system has never filtered by deity affiliation; cleared as repro NPC. **Edge case noted:** Lydl is himself a kill target in the Lydl Mastat Freeport wizard-guild quest — re-recruit of a quest kill-target may interact oddly with quest state. Flagged for architect.
>
> **Re-recruit invariant at Norrath scale:** Approved, no era-compliance issues. NPC level is a game abstraction, not narrative; NPC death/respawn was never canonized in EQ fiction; the companion system is a custom feature with no in-world fiction. Two flavor-level landmines worth one sentence each in the PRD (NOT design changes):
>   - Landmine A — NPCs with functional world roles (guards/merchants/quest-givers) vanishing from their post. Same fiction break vanilla EQ already has via static respawn. Suggest one sentence in PRD lore section.
>   - Landmine B — Quest-chain NPCs mid-quest. Mechanical edge case, not a lore constraint. Flag for architect to evaluate.

**Outcome:** Lore-master initial review APPROVED. Two flavor-level edge cases folded into PRD:
1. Static-respawn fiction note added to Era Compliance section.
2. Quest-chain NPC edge case (incl. Lydl Mastat) added to Open Question #1 and as new acceptance criterion AC-10.
Lore-notes.md transcribed and updated. Full PRD draft sent to lore-master for formal sign-off; awaiting response.

---

### 2026-04-27 — Full PRD draft sent for formal sign-off

**From:** game-designer → **To:** lore-master

> Full PRD draft (with all lore-master findings incorporated as of initial review) sent for formal sign-off. Asked lore-master to confirm two specifics: (1) Cyrla the Healer is a generic example name, flag if real EQ NPC with conflicting lore; (2) Sebilis as a death-location flavor reference creates no faction/race conflict. Asked for APPROVED / REVISE / specific changes verdict.

**Response from** lore-master:

> **APPROVED WITH MINOR NOTE.** Verdict 2026-04-27.
>
> - Lydl the Great (Scenario A): APPROVED — confirmed level 4 human wizard, East Freeport, no stable world role, no lore conflict.
> - **Cyrla the Healer (Scenario B): NAME FLAG.** "Cyrla" collides with Cyrla Shadowstepper, a real EQ NPC (level 61 Rogue guild master, Highpass Hold — emphatically not a healer). Recommended rename to a generic invented name like "Mira the Healer" to avoid noise for architect/implementation. Not a sign-off condition.
> - Sebilis (Scenario C): APPROVED — Kunark-era zone, neutral dungeon, no alignment/faction conflict.
> - Era Compliance section: APPROVED as written. Nothing post-Luclin.
>
> Final verdict: APPROVED. PRD may proceed to commit.

**Outcome:** Lore-master signed off APPROVED 2026-04-27. Cyrla rename recommendation applied: "Cyrla the Healer" → "Mira the Healer" in Scenario B (zero-cost, removes collision noise). Final sign-off block appended to lore-notes.md. PRD status bumped to APPROVED. Cleared to commit and hand off to architect.

---



---


## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

---

### 2026-04-27 — Architect dispatches 4 parallel consultations

**From:** architect → **To:** c-expert, lua-expert, data-expert, config-expert (parallel)

> Sent each advisor a tailored consultation request asking them to verify-before-trust the 44-day-old MEMORY entries and produce concrete file:line citations for the three blockers (level cap, cooldown, dismissed flag). Each advisor was given:
> - their layer-specific scope (C++, Lua, DB, rules)
> - the locked PRD invariant
> - explicit asks tied to the architecture decisions I need to make (where does the bypass live? how is "previously recruited" detected? what does TDD look like at each layer?)
> - a "verify-before-trust" reminder that MEMORY is stale

**Outcome:** Awaiting all four responses. config-expert returned first.

---

### 2026-04-27 — config-expert: rule_values triage

**From:** config-expert → **To:** architect

> Full 47-rule `Companions:*` inventory complete. DB cross-checked against `ruletypes.h` defaults. Findings:
>
> - `Companions:LevelRange = 50` (DB; default 3) — already overridden wide. Single rule, no first-recruit vs re-recruit split. Setting to 999 would violate PRD Non-Goal #1.
> - `Companions:RecruitCooldownS = 900` (15 min). Same — uniform across both paths.
> - `Companions:ReRecruitBonus = 0.10` — **smoking gun**: rule exists → C++ already queries `companion_data` for prior recruitment. That query site is the bypass insertion point.
> - `Companions:MinFaction = 3`, `BaseRecruitChance = 100`, `MaxLevelOffset = 1` — secondary gates, may also need bypass coverage.
> - Config files (`eqemu_config.json`, `.env`): no companion settings. All config is rule-driven.
>
> **Recommendation:** No rule changes. The bypass must live in C++ at the recruit-validation site where `ReRecruitBonus` is already read. Optional new toggle rules `BypassLevelCheckOnReRecruit` / `BypassCooldownOnReRecruit` are the architect's call (config-expert noted hard-coding the bypass per the PRD invariant is also valid).
>
> **Open items handed back:** (1) does `MaxLevelOffset` reject or silently clamp on re-recruit? (2) confirm C++ file:line where `ReRecruitBonus` is read; (3) verify `companion.lua:399` cooldown message line still accurate; (4) verify `companion_data` dismiss/suspend column names.
>
> Full dev-notes: `claude/project-work/companion-rerecruit/config-expert/dev-notes.md`

**Response from** architect:

> Acknowledged. Three takeaways shape the plan:
> 1. `ReRecruitBonus` rule's existence is the architectural anchor — bypass goes wherever that rule is read.
> 2. `LevelRange=50` being already wide-open but the bug still firing means the rejection path isn't a simple delta vs LevelRange. Either NPC current level not base level is being checked, or there's a parallel hard-coded gate. c-expert + lua-expert will resolve.
> 3. No new rules needed — the PRD invariant is the rule. Hard-code the bypass guarded by prior-record predicate. Adding `BypassXOnReRecruit=true` toggles would just add misconfiguration surface area.
>
> One follow-up: which of the 47 rules are read *only* at recruit-validation vs also at runtime? Determines whether bypass is one-site or multi-site. Asked config-expert to grep when convenient.

**Outcome:**
1. **Decision locked:** Bypass is C++-side, hard-coded (no toggle rules), inserted at the `ReRecruitBonus` read site.
2. **Decision locked:** No `rule_values` changes. `LevelRange=50` and `RecruitCooldownS=900` stay where they are.
3. **Pending:** c-expert to confirm `ReRecruitBonus` C++ file:line and `MaxLevelOffset` reject-or-clamp behavior.
4. config-expert has no implementation tasks for this fix unless review uncovers a need for toggles.


### 2026-04-27 — data-expert: DB layer triage

**From:** data-expert → **To:** architect

> Live DB triage complete. Three blockers are 100% application-level — no DB constraints, triggers, or stored procedures enforce any of them. Key findings:
>
> - `companion_data` schema: `is_dismissed` tinyint default 0, `is_suspended` tinyint default 1, `cur_hp` bigint, composite index `idx_owner_active` on `(owner_id, is_dismissed, is_suspended)`. No FK constraints. **No UNIQUE on (owner_id, npc_type_id)** — duplicate rows currently observed in production: Hollish Tnoops (npc_type_id=9144) has two rows for owner_id=6 — id=18 (level 53, is_suspended=0) and id=21 (level 14, is_suspended=1). Re-recruit path must target by specific `id`, not by owner+npc_type_id.
> - `data_buckets` cooldown: MEMORY entry structurally correct (DELETE by key pattern). Zero `companion_cooldown_*` rows currently in DB.
> - **Discrepancy:** `Companions:RecruitCooldownS` rule notes say "after a FAILED recruitment attempt" — contradicts MEMORY which says it fires on dismissal/death. C++ trace required to settle.
> - **Three new tables surfaced:** `companion_exclusions` (recruitability blocklist), `companion_culture_persuasion` (race-based disposition), `companion_spell_sets` (class spell assignments). `companion_buffs` keyed by companion_id.
> - All companion satellite tables (`companion_inventories`, `companion_buffs`) reference `companion_data.id` by convention only — no enforced FK. Safe to UPDATE/DELETE companion_data rows; orphans won't trigger cascade errors.
>
> **Recommended SQL for fix:** Defensive cooldown DELETE by key pattern; UPDATE companion_data SET is_dismissed=0, is_suspended=0 WHERE id=? AND owner_id=?. No schema migrations needed.

**Response from** architect:

> Three implications for the plan:
> 1. Duplicate companion_data rows are real → bypass logic needs deterministic row selection by id, not by (owner+npc_type_id). Asked data-expert for tie-breaker recommendation (lean: is_suspended=0 first, else highest level, else highest id).
> 2. RecruitCooldownS notes vs MEMORY contradiction → c-expert and lua-expert will resolve. If cooldown only fires on FAILED recruit, the level-cap bypass alone may resolve the cooldown blocker too (since a successful re-recruit never hits the cooldown set step).
> 3. companion_exclusions is a separate gating system — invariant says re-recruit always succeeds for previously-recruited NPCs, so exclusion list should be bypassed too. Will note as a corner case.
>
> Asked data-expert two follow-ups: (a) duplicate row tie-breaker rule; (b) one-time cleanup sweep for currently-stuck rows (is_dismissed=1 + cur_hp=0). Also asked: any rows currently in companion_exclusions?

**Outcome:**
1. **Decision locked:** Re-recruit logic targets specific `companion_data.id`, not (owner_id, npc_type_id) — duplicate rows exist and are tolerated.
2. **Decision locked:** No DB schema migrations. All fixes are application-layer (C++ + Lua), with optional one-time defensive UPDATE for currently-stuck rows.
3. **Pending:** data-expert tie-breaker recommendation; companion_exclusions row dump; c-expert+lua-expert to resolve cooldown trigger condition.

### 2026-04-27 — lua-expert: Lua triage (architectural pivot)

**From:** lua-expert → **To:** architect

> Lua two-track recruit dispatch already exists and is correct. `companion.lua:attempt_recruitment()`:
> - **Track 1 (re-recruit):** queries `companion_data WHERE owner_id=? AND npc_type_id=? AND (is_dismissed=1 OR is_suspended=1) LIMIT 1` via `check_existing_companion_record()` (line 390). If row found: minimal safety checks → `client:CreateCompanion(npc)` directly. **No cooldown, no level check, no faction, no persuasion roll.**
> - **Track 2 (first-time):** if no DB record found → cooldown check (line 479) → 11-check `is_eligible_npc()` including level range (line 207) → persuasion roll → success or failure+cooldown.
>
> All three PRD blockers are already bypassed in Lua for Track 1. **The bug fires when `check_existing_companion_record()` returns nil — routing to Track 2.** Likely C++ doesn't set `is_suspended=1` on death/dismiss correctly, OR `CreateCompanion` re-applies restrictions inside C++ even after Lua succeeds.
>
> Cooldown key pattern verified current: `companion.lua:457`: `"companion_cooldown_" .. npc_type_id .. "_" .. char_id` — matches MEMORY exactly.
>
> **Test harness exists** at `akk-stack/server/quests/tests/test_companion_recruitment.lua` (38+ tests) and `test_companion_rerec_edge_cases.lua`. luajit not on host PATH (only inside vcpkg build tree); engineers need Docker exec or symlink for TDD.
>
> **No Lua fix needed** unless `check_existing_companion_record()` query has a column-name mismatch with what C++ actually writes.

**Response from** architect:

> Major architectural pivot. Reconciliation against data-expert's finding (Hollish Tnoops has rows with both is_suspended=0 and is_suspended=1) shows the flag CAN be set — so lua-expert's hypothesis "C++ never sets is_suspended=1" is partially wrong. Refined the hypothesis space to four candidates:
>
> - **A.** Death sets the flag but dismissal does not (or vice versa). Different bugs.
> - **B.** Flag is set, but `check_existing_companion_record` has a query bug (column name, parameter binding, type coercion).
> - **C.** Wrong char_id passed to attempt_recruitment (account_id vs character_id confusion).
> - **D.** Observation bias — user's manual SQL cleanup DELETES the companion_data row, removing the Track 1 hint; bug presents as "level too low" because Lua thinks it's a first-recruit. The "fix" then becomes "don't delete on reset, UPDATE flags instead."
>
> Asked lua-expert to follow up on four specific traces:
> 1. Read `_on_recruitment_success`'s call into C++ — what context (if any) is passed?
> 2. Read `lua_companion.cpp` for `CreateCompanion` binding — what parameters does it take?
> 3. Reproduce Lua SQL query against live DB with Lydl's real ids — does it return a row when the player has previously recruited Lydl?
> 4. Verify `eq.delete_data(cooldown_key)` works given the data_buckets cache staleness MEMORY note.
>
> Will sharpen c-expert's prompt to specifically trace `Companion::Death()`, `Companion::Dismiss(true)`, and `Client::CreateCompanion(NPC*)` for flag-set + Save() behavior and re-activate-vs-insert logic.

**Outcome:**
1. **Major pivot:** the architecture is no longer "build a re-recruit bypass in Lua/C++". The bypass already exists in Lua. The real architecture is "find why Track 1 isn't firing and close the gap (C++ flag-set bug, Lua query bug, or cleanup-process bug)."
2. **Decision pending:** root cause among hypotheses A/B/C/D. lua-expert + c-expert tasked with disambiguation.
3. **TDD strategy clarified:** Lua test harness exists at `akk-stack/server/quests/tests/`. New tests added there before any fix lands. Test execution via `docker exec` with luajit from vcpkg path or via a `make test` target — infra-expert may need to land that before implementation if engineers don't have a working `luajit` binary.
4. **Pending:** lua-expert's four follow-up traces.

---

### 2026-04-27 — c-expert: C++ and DB layer triage (resolves architect hypothesis A/B/C/D)

**From:** c-expert → **To:** architect

> Triage complete. All four architect hypotheses resolved by direct DB + source inspection.
>
> **Hypothesis A (death vs dismissal sets flag differently):** ELIMINATED. `companion.cpp:1881` sets `is_suspended=1` on death; `companion.cpp:2561-2564` sets both `is_suspended=1` AND `is_dismissed=1` on voluntary dismissal. Both paths write the flag. DB confirms: Lydl has `is_suspended=1, is_dismissed=0` — correctly representing death state.
>
> **Hypothesis B (check_existing_companion_record query bug):** ELIMINATED. Query manually run against live DB with Lydl's real IDs:
> `SELECT ... WHERE owner_id=6 AND npc_type_id=10162 AND (is_dismissed=1 OR is_suspended=1)` → returns row id=10. Query is correct. Both Lua and C++ use this exact query.
>
> **Hypothesis C (wrong char_id):** Cannot directly test without live recruitment attempt, but live DB shows `owner_id=6` for Lydl and the character 'Chelon' is owner_id=6 (confirmed from companion_data for other active companions). No mismatch.
>
> **Hypothesis D (user manual cleanup deleted the row):** ELIMINATED FOR LYDL. Row id=10 EXISTS in DB with is_suspended=1. It has NOT been deleted. No manual cleanup affected this record.
>
> **Actual current state:** The three named blockers (level cap, cooldown, dismissed flag) are ALL already handled correctly. The reason Lydl cannot be re-recruited RIGHT NOW is group capacity: player has 4 active companions + player = 5 in group. Adding Lydl = 6 = full party. `is_re_recruitment_eligible()` fires "Your party is full." This is working as designed.
>
> **Test infrastructure:**
> - C++ test suite: `eqemu/zone/cli/tests/cli_companion_tests.cpp` — 35+ suites, run via `./bin/zone tests:companion`
> - lua-expert notes a Lua test harness at `akk-stack/server/quests/tests/test_companion_recruitment.lua`
> - Suite 20 covers HP/mana restoration after Load() and DataBucket cooldown deletion but NOT the full CreateFromNPC re-recruitment path end-to-end
>
> **One real gap to fix:** `companion.lua:207` falls back to `or 3` for LevelRange if rule is missing. Current DB has LevelRange=50. If rule_values ever resets, first-time recruitment gets gated at 3. Should be `or 50` to match current DB intent. This is a Lua change.
>
> **ReRecruitBonus status:** Rule defined in ruletypes.h:1196, comment at companion.cpp:3792 says "Lua reads this," but companion.lua has ZERO calls to `eq.get_rule("Companions:ReRecruitBonus")`. The rule is currently unused. Config-expert's "bypass anchor at ReRecruitBonus read site" assumption is not valid — there is no such C++ bypass site, and the rule is not wired in Lua either.
>
> Full dev-notes: `claude/project-work/companion-rerecruit/c-expert/dev-notes.md`

**Outcome:** Pending architect response. This directly shapes the architecture decision: is implementation work needed at all, or is the deliverable primarily test coverage?

---

## Implementation Team Conversations

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication.
This table is the quick-reference for anyone catching up._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | Lore review APPROVED — companion re-recruit invariant has no lore blockers; two edge cases (static-respawn fiction note, quest-NPC interaction) folded into PRD as flavor notes for architect awareness | game-designer, lore-master | 2026-04-27 | Mechanical bugfix; companion system is a custom feature with no in-world fiction |
| 2 | Rename "Cyrla the Healer" → "Mira the Healer" in Scenario B | game-designer, lore-master | 2026-04-27 | Cyrla collides with real EQ NPC Cyrla Shadowstepper (level 61 Rogue, Highpass) — generic invented name removes noise for downstream readers |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| | | | |
