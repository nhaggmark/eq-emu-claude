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

### 2026-04-27 — data-expert: deep schema dump + 7-question answers

**From:** data-expert → **To:** architect

> Verified answers to all 7 questions with live DB queries. Highlights:
>
> - **companion_data column names confirmed:** `owner_id` (NOT character_id), `npc_type_id` (NOT source_npc_type_id). Indexes: PRIMARY (id), idx_owner, idx_npc_type, idx_owner_active (owner_id, is_dismissed, is_suspended). No UNIQUE on (owner_id, npc_type_id).
> - **6 rows total in companion_data for owner_id=6:** Lydl (id=10, level 53, **is_suspended=1**, is_dismissed=0, cur_hp=1504), Hollish active (id=18, level 53, suspended=0), Hollish stale (id=21, level 14, suspended=1, **0 inventory rows** — orphaned dup), Jimble (id=22), Jracol (id=23), Lashun (id=24).
> - **Critical finding:** All 6 rows have `is_dismissed=0`. The "dismissed flag blocker" is theoretical — not currently active in production.
> - **Death does NOT zero cur_hp.** Lydl is suspended with cur_hp=1504. PRD's "cur_hp=0" hint is wrong.
> - **companion_inventories items are normalized** (one row per (companion_id, slot_id)), not blobs. UNIQUE on (companion_id, slot_id). Confirmed via join — Lydl has 14 items.
> - **6 companion_* tables total:** companion_data (6 rows), companion_inventories (70 rows), companion_buffs (0 rows), **companion_exclusions (8,541 rows — NPC blocklist)**, companion_culture_persuasion (14 rows), companion_spell_sets (842 rows). No `character_*` companion columns.
> - **Zero companion_cooldown rows currently in data_buckets.** Cannot verify key format from live data; structurally consistent with `soul_wipe_*` keys observed (all scope columns 0, identity in key string).
> - **No FK constraints, no triggers, no stored procedures on any companion table.** All enforcement is application-level.
> - **Reset script** verified with correct column names: DELETE inventories via JOIN on companion_data, DELETE buffs same pattern, DELETE companion_data, DELETE data_buckets cooldown by exact key.
> - **Migration risk:** No is_dismissed=1 rows currently → no one-time UPDATE migration needed. Recommend dedup of stale duplicate rows as part of fix (Hollish Tnoops id=21 is dead weight).

**Response from** architect:

> This dump is decisive and changes the architecture again. Five consequential findings:
>
> 1. **Lydl's row exists with is_suspended=1.** Track 1 query (`is_dismissed=1 OR is_suspended=1`) SHOULD match it. If BUG-001 is reproducible, the Lua query is failing for some other reason — Hypothesis B (column/parameter mismatch) is now leading suspect.
> 2. **is_dismissed blocker is theoretical-only.** No row currently has it. We may not need a dismissed-flag fix at all — the OR predicate already covers both states.
> 3. **cur_hp preserved on death.** Death sets is_suspended=1 only; cur_hp stays at last value. Restoring cur_hp on re-recruit may be unnecessary (or even wrong if it overrides the natural healing path).
> 4. **Lydl is level 53, NPC base level 4.** Player level 35, LevelRange=50 → delta against companion's *current* level=18 (within 50), but delta against NPC *base* level=31 (still within 50). Either way, the level check should pass. So either the check uses a different formula (e.g., min(player, npc_level) < something), or the bug is purely Track-1-not-firing.
> 5. **Stale Hollish row id=21 is dead weight** — confirms dedup-as-part-of-fix is the right move.
>
> Asked data-expert four follow-ups: (a) confirm Lydl's ground-truth state with NPC base level, (b) verify dedup query logic, (c) check if any user's NPCs are in companion_exclusions, (d) recommend whether to add UNIQUE index on (owner_id, npc_type_id).
>
> data-expert task is essentially complete; these are clarifications.

**Outcome:**
1. **Decision locked:** Primary root-cause hypothesis is now (B) Lua query mismatch (or downstream of query in `_on_recruitment_success`/`CreateCompanion`). Secondary is C++ level check using NPC base level on Track 2 path.
2. **Decision locked:** No "clear is_dismissed on re-recruit" fix needed (no rows currently have is_dismissed=1). Lua's OR predicate handles it.
3. **Decision locked:** No "restore cur_hp" fix on re-recruit — death preserves it.
4. **Decision locked:** Include one-time dedup of stale companion_data rows as part of implementation plan.
5. **Decision pending:** Add UNIQUE index on (owner_id, npc_type_id)? — depends on whether C++ code requires duplicates anywhere.
6. **Pending:** lua-expert to reproduce SQL against live data; c-expert to trace `Companion::Death`/`Dismiss`/`Client::CreateCompanion`.

### 2026-04-27 — config-expert: CORRECTION — Lua bypass already exists

**From:** config-expert → **To:** architect

> Retracts and corrects earlier finding ("the fix must be in C++"). After deeper triage of `companion.lua:450-476`:
>
> - The two-track recruit dispatch already exists in Lua and is correct (matches lua-expert's independent finding).
> - **`Companions:LevelRange` and `Companions:RecruitCooldownS` are Lua-only** — grepped full `eqemu/` source, no C++ reads. This eliminates an entire class of speculative C++ fixes.
> - **`eqemu/zone/companion.cpp:3792` comment** explicitly states: "No C++ method needed here — Lua reads RuleR(Companions, ReRecruitBonus)." The recruit-decision architecture is intentionally Lua-side.
> - The three reported PRD blockers (level cap, cooldown, dismissed flag) are all symptoms of one root cause: `is_dismissed` and/or `is_suspended` not being set correctly on `companion_data` after death/dismissal/zone-disconnect/server-restart. When the flag is missing, Track 1's `check_existing_companion_record()` returns nil, falling through to Track 2 which fires all three blockers.
>
> **Recommendation:** Zero config changes. No new toggle rules. Fix is entirely about ensuring drop-out paths write the suspension/dismissed flag correctly to companion_data.

**Response from** architect:

> Correction appreciated and locked. The "verify-then-correct" pattern is the gold standard — a half-correction would have left bad guidance in the audit trail.
>
> Two pieces of evidence config-expert contributed that lock the architecture:
> 1. LevelRange/RecruitCooldownS are Lua-only (grep-verified). Eliminates "maybe C++ also enforces this" hypotheses.
> 2. companion.cpp:3792 comment confirms intentional Lua-side architecture.
>
> Consequence: `companion_exclusions` (8541 rows) is also Lua-only enforcement — already bypassed on Track 1.
>
> **config-expert task is complete.** No rule_values changes, no eqemu_config.json changes, no toggle rules. Will be released from architecture team after architecture doc commits.

**Outcome:**
1. **Decision locked:** Zero config-layer changes for this fix.
2. **Decision locked:** All recruit gating (LevelRange, RecruitCooldownS, exclusions, faction, persuasion) is Lua-only. Confirmed by both lua-expert (read Lua) and config-expert (grep-verified C++).
3. **Decision locked:** Three-blocker framing in PRD is a symptom map, not a root-cause map. Single root cause: drop-out paths failing to write is_dismissed/is_suspended to companion_data.
4. **Pending:** c-expert to identify which drop-out paths fail to write the flag.

### 2026-04-27 — lua-expert: SMOKING GUN — root cause found

**From:** lua-expert → **To:** architect

> **CRITICAL FINDING:** `companion.lua:1434` — `cmd_dismiss` calls `npc:Dismiss(true)`. The C++ signature `Companion::Dismiss(bool permanent = false)` at `companion.h:288` and implementation at `companion.cpp:2553`:
> ```cpp
> if (permanent) {
>     SoulWipe();  // deletes DB record entirely
> } else {
>     SetSuspended(true);
>     SetDismissed(true);
>     Save();      // preserves record for re-recruitment
> }
> ```
>
> The Lua doc comment at line 15 says `true=voluntary (preserves record)` — **exactly backwards**. `Dismiss(true)` = permanent SoulWipe; `Dismiss(false)` = voluntary preserve.
>
> So every `!dismiss` deletes the companion_data row entirely. Track 1 then finds nothing on re-recruit, falls through to Track 2, which enforces all 11 eligibility checks + level + cooldown + persuasion. **All three reported PRD blockers are symptoms of this single bug.**
>
> **Death path is fine.** C++ correctly writes `is_suspended=1` at companion.cpp:660 (normal) and :650/:654 (fallback). data-expert's evidence (Lydl row exists with is_suspended=1) confirms.
>
> **Recruit flow trace (file:line):**
> - Entry: `companion.lua:454` — `attempt_recruitment(npc, client)`
> - Track 1: `companion.lua:462` — `check_existing_companion_record()` — query at lines 390-402 (`WHERE owner_id=? AND npc_type_id=? AND (is_dismissed=1 OR is_suspended=1)`)
> - Track 2 cooldown: `companion.lua:479` — message at :481 (Lua-generated: "won't discuss joining you again so soon")
> - Track 2 eligibility: `companion.lua:487` — `is_eligible_npc()` runs 11 checks
> - Level check: `companion.lua:207-213` — message: "is too far from your level to recruit" (Lua-generated; rule `Companions:LevelRange` default 3, DB 50)
> - Persuasion roll: `companion.lua:494-509`
>
> **All rejection messages are Lua-generated.** No C++ method directly produces any of them. "Too low level" is a paraphrase; actual string is "is too far from your level to recruit."
>
> **Side effects in `_on_recruitment_success` (companion.lua:514-536):**
> - Sets `is_recruited="1"` entity variable (concurrency guard)
> - Calls `client:CreateCompanion(npc)` (C++ load/restore)
> - On C++ failure: clears `is_recruited` and shows error
> - Says "I will join you" (first-time) or "I remember you. Let us continue." (re-recruit)
> - **No inventory save, no stance set, no signal — Lua layer is intentionally thin.**
>
> **Test harness:** `akk-stack/server/quests/tests/test_companion_recruitment.lua` (38+ tests) and `test_companion_rerec_edge_cases.lua`. Inline harness, no external deps. **luajit not on host PATH** — exists only in `eqemu/build/vcpkg_installed/x64-linux/`. Must run via Docker exec or `apt install luajit`.
>
> **Recommended fix:** One character at `companion.lua:1434`: `npc:Dismiss(true)` → `npc:Dismiss(false)`. Plus doc comment fix at line 15. Plus tests proving the invariant. **No C++ changes. No SQL schema changes. No rule changes.**

**Response from** architect:

> Architecture LOCKED. The one-character fix is the entire implementation surface area, plus tests, plus a one-time dedup of stale companion_data rows.
>
> Three blockers reframed as one root cause + two cascading symptoms:
> - **Dismiss blocker:** Direct — `Dismiss(true)` SoulWipes the row.
> - **Level cap blocker:** Cascading — Track 2 fires when Track 1 fails because the row is gone.
> - **Cooldown blocker:** Cascading — Track 2's failure sets the cooldown, blocking next attempt.
>
> **Death blocker is not a real blocker** — death writes is_suspended=1 correctly. Confirmed by both lua-expert (code trace) and data-expert (live row state).
>
> Asked lua-expert three confirmations before architecture commit:
> a. Run existing test suite — what currently passes/fails?
> b. Trace `_on_recruitment_success` → `client:CreateCompanion(npc)`: does Lua pass `existing_record.id` to C++, or does C++ re-search by (owner_id, npc_type_id)? Determines whether duplicate rows cause a bug.
> c. Does any OTHER companion command (`!flee`, `!hold`, etc.) call `Dismiss(true)`? Single-char fix only works if there's no other invocation.
>
> lua-expert's implementation surface in Phase 4 will be:
> - `companion.lua:1434` — `Dismiss(true)` → `Dismiss(false)` (one character)
> - `companion.lua:15` — doc comment correction
> - New failing TDD tests in `test_companion_recruitment.lua` (added BEFORE the fix per PRD AC-9)

**Outcome:**
1. **Decision locked:** Single root cause is `cmd_dismiss` calling the wrong overload. Three blockers are one bug + two cascading symptoms.
2. **Decision locked:** Implementation = 1-char Lua fix + doc fix + new TDD tests + 1-time DB dedup. No C++ changes. No schema changes. No rule changes.
3. **Decision locked:** Test execution requires a `make test-companion` target (infra-expert) or luajit symlink — engineers cannot run TDD without one.
4. **Pending:** lua-expert's three follow-up confirmations (existing test pass/fail, CreateCompanion row-selection contract, other Dismiss(true) call sites).
5. **Pending:** c-expert's response — primarily for risk assessment (charm/swarm/merc shared paths) and validation of `Companion::Dismiss(bool)` semantics. Not blocking architecture commit.

### 2026-04-27 — config-expert: rule usage scope verification (final)

**From:** config-expert → **To:** architect

> Grep-verified the entire codebase for every recruit-gating rule. Single-site for all of them:
>
> | Rule | Lua site | C++ site | Used outside recruit path? |
> |------|----------|----------|---------------------------|
> | `Companions:LevelRange` | `companion.lua:207` (in `is_eligible_npc()`) | None | No |
> | `Companions:RecruitCooldownS` | `companion.lua:542` (in `_on_recruitment_failure()`) | None | No |
> | `Companions:MinFaction` | `companion.lua:217` (in `is_eligible_npc()`) | `companion.cpp:3853` stub (NOT actually read — log-and-continue placeholder) | No |
> | `Companions:BaseRecruitChance` | `companion.lua:494` (persuasion roll) | None | No |
> | `Companions:ReRecruitBonus` | Not read in Lua | `companion.cpp:3792` comment only | No |
>
> All five rules are read at exactly one site, all inside `is_eligible_npc()` or `_on_recruitment_failure()`. Track 1 already skips both functions. Zero scoping risk for the bypass.
>
> **`MinFaction` C++ stub at companion.cpp:3853-3860** is documented as a Phase 1 placeholder ("Full implementation would query character's current faction standing. For Phase 1, we just log and continue."). When fleshed out later, will need its own bypass consideration — out of scope for this fix.

**Response from** architect:

> Closed. Zero scoping risk confirmed. config-expert task complete.
>
> Architecture.md will record:
> 1. Full 47-rule Companions:* enumeration
> 2. Grep verification of all five recruit-gating rules
> 3. Decision: zero rule_values changes, zero toggle rules
> 4. companion.cpp:3792 and :3853 annotations preserved as future-work markers
>
> config-expert released from architecture team upon doc commit.

**Outcome:**
1. **Decision locked:** Bypass has no scoping risk. Single-site rule reads, all on the Track 2 path that is already short-circuited.
2. **Decision locked:** `MinFaction` C++ runtime check is a future-work placeholder, not active. Out of scope.
3. **config-expert task fully complete.** No further consultation needed.

### 2026-04-27 — data-expert: follow-up answers (final)

**From:** data-expert → **To:** architect

> All three follow-ups answered with fresh queries:
>
> **A. Tie-breaker for duplicate row selection:** `ORDER BY level DESC, experience DESC LIMIT 1`. Rationale: Hollish Tnoops ghost row id=21 is later (recruited_at 2026-03-11) than canonical id=18 (recruited_at 2026-03-09) but is clearly the bad row (level=14, experience=0, 0 inventory vs level=53, experience=18707712, 15 items). "Highest id" and "most recent recruited_at" would pick the wrong row. `is_suspended=0` weighting would also be wrong — would deprioritize legitimately suspended companions like Lydl.
>
> **B. One-time cleanup sweep:** NOT NEEDED. Re-queried — 0 rows with is_dismissed=1, 0 rows with cur_hp=0. Nothing stuck. PRD's "is_dismissed=1 + cur_hp=0 stuck" scenario does not match current production state. ONLY targeted action needed: DELETE ghost row id=21 (Hollish Tnoops). Implementation should SELECT-confirm-DELETE.
>
> **C. companion_exclusions row count corrected:** 7,269 (not 8,541 — earlier was an information_schema estimate). exclusion_type=1: 7,262 rows (auto-blocklist). exclusion_type=0: 7 rows (manual lore-anchor). User's repro candidates (Lydl=10162, Hollish=9144, Jimble=22014, Jracol=2029, Lashun=2032) ALL CLEAR — none in exclusions. The 7 lore-anchor exclusions documented for future-work awareness:
> ```
> 9147   Sir Lucan D'Lere variant
> 42019  High Priestess Alexandria
> 73112  Fabled King Thex'Ka IV
> 155151 King Raja Kerrath
> 382244 Sir Lucan D'Lere variant alt
> 466029 Lord Antonius Bayle
> 466035 Captain Hiran Tillin variant
> ```
>
> **Architectural note:** Ghost row id=21 was created LATER than id=18 — strong circumstantial evidence of a write-path bug where a re-recruit INSERTed a new row instead of UPDATing the existing one. Strengthens argument for adding `UNIQUE (owner_id, npc_type_id)` schema-level guardrail. Also: exclusion check happens in `is_eligible_npc()` which Track 1 already short-circuits past, so previously-recruited NPCs that later got added to exclusions would still re-recruit (correct per invariant).

**Response from** architect:

> Three decisions locked:
> 1. Tie-breaker = `ORDER BY level DESC, experience DESC LIMIT 1`. Recorded for engineer use.
> 2. No UPDATE sweep. Single targeted DELETE of ghost id=21 with SELECT-confirm-DELETE pattern as a named implementation step.
> 3. Lydl + repro candidates clean. exclusion_type=0 bypass is already correct in current code (Track 1 doesn't hit is_eligible_npc()).
>
> Ghost-row write-path bug noted as **out-of-scope-but-tracked**. The dismiss fix prevents the most common ghost-creation vector (dismiss→re-recruit). UNIQUE constraint is a follow-up question for engineers to investigate after the dismiss fix lands.
>
> data-expert task fully complete. Released from architecture team upon doc commit.

**Outcome:**
1. **Decision locked:** Engineers select duplicate rows by `ORDER BY level DESC, experience DESC LIMIT 1`.
2. **Decision locked:** Single targeted DELETE of `companion_data.id=21` (Hollish Tnoops ghost). No broad UPDATE sweep.
3. **Decision locked:** UNIQUE (owner_id, npc_type_id) constraint = future work, not in this fix.
4. **Decision locked:** companion_exclusions has zero impact on this fix; documented for future awareness.
5. **data-expert task fully complete.** No further consultation needed.

### 2026-04-27 — c-expert: C++ triage with two disagreements vs lua-expert

**From:** c-expert → **To:** architect

> Full C++ triage. Findings (file:line cited):
>
> - **"Too low level" string source:** `companion.lua:212` (Lua only) — fires from `is_eligible_npc()`. With `LevelRange=50` in DB, this rarely triggers. Currently bypassed by the two-track system for re-recruits.
> - **Cooldown:** Zero entries in data_buckets. Lua deletes stale cooldown at `companion.lua:474`; C++ does same at `companion.cpp:272-275`. Belt-and-suspenders. Not a blocker.
> - **Dismissed/suspended flag:** `CreateFromNPC()` at `companion.cpp:215-265` queries `(is_dismissed=1 OR is_suspended=1)`, calls `Load()`, sets `m_suspended=false`, `m_is_dismissed=false`, and `UPDATE companion_data SET is_dismissed=0, is_suspended=0`. **The flag IS properly cleared on re-recruitment.**
> - **ReRecruitBonus:** Defined in `ruletypes.h:1196`. companion.cpp:3792 has a comment "No C++ method needed here — Lua reads this." But `companion.lua` has ZERO calls to `eq.get_rule("Companions:ReRecruitBonus")`. Rule is unused. Refutes config-expert's "this is the bypass anchor" claim.
> - **MaxLevelOffset:** Read at `companion.cpp:3427` inside `CheckForLevelUp()` (ongoing XP gate). NOT a recruit blocker.
> - **Lydl current DB state:** id=10, is_dismissed=0, is_suspended=1, cur_hp=1504, level=53, recruited_level=4. Suspended (death state), not dismissed.
> - **CURRENT real-world blocker for Lydl per c-expert:** Player has 4 active companions (ids 18, 22, 23, 24). Adding Lydl makes 6 in group. `is_re_recruitment_eligible():416` rejects with "Your party is full. Dismiss a companion or group member first." **This is working as designed, not a bug.**
> - **The historical "too low level" the user reported was likely from BEFORE the two-track system landed, OR when LevelRange was set to 3 instead of 50.**
> - **Test infrastructure:** `eqemu/zone/cli/tests/cli_companion_tests.cpp` has 35+ suites including Suite 20 `TestCompanionReRecruitmentHP` (HP/mana restoration only). No end-to-end re-recruitment test exists. Recommend Suite 24+ for full path coverage.
>
> **c-expert's proposed PRD fix:**
> 1. Regression test coverage (TDD per AC-9)
> 2. Lua LevelRange fallback `or 3` → `or 50` to match DB (defense against rule_values reset)
> 3. ReRecruitBonus wire-up or removal (cleanup)
> 4. The "current real-world failure" is "party full" — not a bug, design constraint. User must dismiss one companion to make room for Lydl.

**Response from** architect:

> Two disagreements with lua-expert that need resolution BEFORE architecture commit:
>
> **Disagreement 1: `Companion::Dismiss(bool permanent)` semantics.**
> lua-expert cites `companion.cpp:2553` — `if (permanent) SoulWipe()` — and says `cmd_dismiss` calling `Dismiss(true)` SoulWipes the row. c-expert traced `CreateFromNPC` (the re-recruit path) but did NOT verify the `Dismiss(bool)` implementation. If lua-expert is right, every voluntary `!dismiss` deletes the companion_data row and Track 1 has nothing to find.
>
> **Disagreement 2: User's reported error vs c-expert's diagnosis.**
> c-expert says current blocker is "party full". User reported "too low level". These are different code paths. Either (a) user paraphrased, (b) bug was historical (different code state), or (c) c-expert's diagnosis missed a blocker.
>
> Asked c-expert to:
> 1. Read companion.cpp:2547-2570 directly and confirm/refute lua-expert's SoulWipe claim. Cite file:line.
> 2. grep all SoulWipe call sites.
> 3. Read cmd_dismiss in companion.lua:1434 and confirm what value is passed.
> 4. End-to-end scenario walkthrough: player says "recruit" to Lydl with 4 active companions. Where does it reject? With what message? File:line.

**Outcome:**
1. **Conflict surfaced:** Two advisors disagree on whether `cmd_dismiss` is buggy. Architecture cannot commit until resolved.
2. **Pending:** c-expert's cross-check. If lua-expert's SoulWipe claim is verified, the dismiss fix is real. If refuted, c-expert's "party full" diagnosis stands and the fix may be primarily test coverage + LevelRange fallback hardening.
3. **Side finding:** `ReRecruitBonus` rule is unused in current code. config-expert's earlier characterization of it as "the bypass anchor" was wrong; the bypass anchor is the two-track Lua dispatch. Architecture doc will note ReRecruitBonus as a no-op rule (cleanup candidate, out of scope).
4. **Side finding:** `MaxLevelOffset` is an ongoing XP gate, not a recruit gate. PRD's mention of it as a recruit blocker was inaccurate.
5. **Side finding:** "Too low level" string does not appear in any C++ companion code. Only source is `companion.lua:212` ("is too far from your level to recruit"). The user's "too low level" wording is a paraphrase.

### 2026-04-27 — lua-expert: 4-point follow-up + DISAGREEMENT RESOLVED

**From:** lua-expert → **To:** architect

> Answers to all four cross-check points:
>
> **Point 1 — _on_recruitment_success → C++ contract:** Lua passes ONLY the NPC reference. No "is_rerecruit" flag, no existing_record id. C++ `Companion::CreateFromNPC` runs its OWN identical query independently. The two-track detection is duplicated and independent in both layers. Implication: if Lua's query and C++'s query disagree (e.g., different row picked due to duplicates), state can diverge.
>
> **Point 2 — Does CreateCompanion re-apply level rules?** No. `CreateFromNPC` has zero level/faction/cooldown checks. Only gates: null check, `CompanionsEnabled`, `LoadNPCTypesData` failure. If C++ returns non-null, the companion spawns unconditionally.
>
> **Point 3 — Live SQL reproduction:** Ran the EXACT Lua query against live DB:
> ```sql
> SELECT id, owner_id, npc_type_id, name, level, is_dismissed, is_suspended
> FROM companion_data
> WHERE owner_id = 6 AND npc_type_id = 10162
> AND (is_dismissed = 1 OR is_suspended = 1) LIMIT 1;
> ```
> Result: `id=10, owner_id=6, npc_type_id=10162, name="Lydl the Great", level=53, is_dismissed=0, is_suspended=1`. **The row EXISTS. Track 1 WOULD fire today.** The bug as reported is NOT currently reproducible against this DB+code state — but the underlying defect remains (cmd_dismiss SoulWipe), which will reproduce again on the next `!dismiss`.
>
> **Point 4 — eq.delete_data() / cache:** No stale companion_cooldown_* rows in data_buckets. `eq.delete_data` is working from the Lua side. In-memory server-side cache invalidation is a separate concern (c-expert territory) but moot since there are no rows to clear.
>
> **Synthesis:** The "too far from your level" rejection in BUG-001 would require Track 1 to NOT fire. Lydl's row in valid Track 1 state today means either (a) `LevelRange` was historically lower (e.g., default 3), or (b) the row was manually DELETEd at the time of the bug, or (c) a prior commit partially fixed the issue. The CONFIRMED reproducible bug remains: `companion.lua:1434` calls `Dismiss(true)` = permanent SoulWipe.

**Response from** architect:

> **DISAGREEMENT WITH c-expert RESOLVED.** Reading both side-by-side:
> - lua-expert cited `companion.cpp:2553` — `if (permanent) SoulWipe() else { ... Save(); }`
> - c-expert cited `companion.cpp:2561-2564` — "voluntary dismiss sets both flags" (the **else** branch of the if(permanent) at 2553)
>
> Both descriptions are consistent. They describe different branches of the same conditional. Semantics confirmed: `Dismiss(true)` = SoulWipe; `Dismiss(false)` = preserve. **`cmd_dismiss` invoking `Dismiss(true)` IS a real bug.**
>
> lua-expert's live SQL reproduction also resolves the user's "too low level" report: it was historical (different LevelRange or row manually deleted). Today, with `LevelRange=50` and Lydl's row in valid Track 1 state, the bug as reported would not fire — the "current real-world failure" is now "party full" (c-expert's diagnosis), which is correct behavior, not a bug.
>
> **Architecture FULLY LOCKED. Implementation surface area:**
> 1. `companion.lua:1434`: `Dismiss(true)` → `Dismiss(false)` (one character)
> 2. `companion.lua:15`: doc comment correction
> 3. `companion.lua:207`: LevelRange fallback `or 3` → `or 50` (defense against future rule_values reset)
> 4. New TDD tests in `test_companion_recruitment.lua` (added BEFORE the fix per PRD AC-9):
>    - dismiss preserves companion_data row
>    - re-recruit after dismiss succeeds via Track 1
>    - re-recruit after death succeeds via Track 1 (regression)
> 5. Targeted DELETE of ghost row `companion_data.id=21` (Hollish Tnoops)
> 6. `make test-companion` target in akk-stack (infra-expert) so engineers can run luajit
>
> **Zero C++ changes. Zero schema changes. Zero rule_values changes.**

**Outcome:**
1. **Disagreement resolved.** Both advisors right about different branches. Architecture commits with lua-expert's fix.
2. **User's bug report wording explained.** "Too low level" was historical (older LevelRange or manual cleanup); current code is in valid state. The fix prevents the bug from RE-occurring after future `!dismiss`.
3. **Architecture fully locked.** All implementation surface area enumerated above.
4. **lua-expert task complete.** Implementation tasks captured for Phase 4: companion.lua edits + TDD tests.

### 2026-04-27 — c-expert: 6-priority answers (with one factual error)

**From:** c-expert → **To:** architect

> Full priority-1 through priority-6 answers with file:line citations:
>
> - **Priority 1 (Death/Dismiss):** Death() takes 3 redundant save paths, all set `is_suspended=1` (companion.cpp:646-678 fallback, :1870-1884 Process safety net, :660-678 normal path). Plus a death-despawn-timer at companion.cpp:1888-1913: after `DeathDespawnS=1800s` with no resurrection, sets BOTH is_dismissed=1 AND is_suspended=1 and Save(). Dismiss(bool permanent) at companion.cpp:2553: `if(permanent) SoulWipe(); else { SetSuspended; SetDismissed; Save(); }`.
> - **Priority 2 (CreateCompanion):** CreateFromNPC at companion.cpp:188 pre-checks companion_data; if existing row found → Load → SetHP → clear flags. NO level/faction/cooldown checks in C++. LIMIT 1 selection without ORDER BY (non-deterministic with duplicates).
> - **Priority 3 (ReRecruitBonus):** companion.cpp:3792 has only a comment ("Lua reads this"); zero `eq.get_rule("Companions:ReRecruitBonus")` calls in companion.lua. Rule is unused.
> - **Priority 4 ("too low level"):** Only at companion.lua:212 ("is too far from your level to recruit"); no C++ source. Reachable only on Track 2.
> - **Priority 5 (test infra):** Real test suite at `eqemu/zone/cli/tests/cli_companion_tests.cpp` runs via `./bin/zone tests:companion`. Suite 20 `TestCompanionReRecruitmentHP` partially covers re-recruit. Add `TestCompanionReRecruitInvariant` following the same pattern.
> - **Priority 6 (charm/swarm/merc):** Companion inherits NPC, not Bot/Merc. Zero shared paths.
>
> **Synthesis (CONTAINS FACTUAL ERROR):** "All four hypotheses eliminated. cmd_dismiss() in Lua calls companion:Dismiss(false) (voluntary dismissal, NOT permanent). The current actual blocker is group capacity — player has 4 active companions + 1 = 5 in group; adding Lydl makes 6, hits is_re_recruitment_eligible():416 'Your party is full.' This is working as designed."

**Response from** architect:

> Direct file read of `companion.lua:1430-1434` and `companion.cpp:2553-2570` confirms:
>
> 1. **C++ side** — `Dismiss(bool permanent)` is exactly as c-expert (and lua-expert) cited.
> 2. **Lua side** — `cmd_dismiss` calls `npc:Dismiss(true)`, NOT `Dismiss(false)`. **c-expert's synthesis statement is factually wrong.**
> 3. **Lua doc comment at line 15** — describes `voluntary_bool` with `true=voluntary` semantic, which is opposite of C++ `permanent` semantic.
>
> **Conclusion:** The Lua author intended `true=preserve` but C++ implements `true=SoulWipe`. lua-expert's smoking-gun finding stands. Architecture remains committed at d5f6f68 with the one-character fix.
>
> Replied to c-expert with the ground-truth code snippets and an explanation. c-expert's other priority findings (death has 3 save paths, CreateFromNPC is unconditional, ReRecruitBonus unused, charm/swarm/merc isolated, test infrastructure) all stand and remain load-bearing for the architecture.
>
> **NEW finding from c-expert that I am incorporating:** death-despawn-timer at companion.cpp:1888-1913 sets BOTH is_dismissed=1 AND is_suspended=1 after `DeathDespawnS=1800s`. This explains why Lydl's row currently has is_dismissed=0 (timer hasn't fired yet, or was cancelled by resurrection/zoning). Worth noting in the architecture doc as part of the drop-out paths table.

**Outcome:**
1. **Architecture is correct as committed.** The c-expert factual error about which boolean Lua passes is corrected; the underlying root cause (Lua passes `true` → SoulWipe) is unchanged.
2. **Architecture doc updated** to add the death-despawn-timer drop-out path and direct ground-truth code snippets (for future agents who don't want to re-read the files).
3. **Re-commit pending** — small additive update, not a teardown.
4. **Lesson:** Even careful agents can introduce factual errors in synthesis. Always verify load-bearing claims by reading the actual file.

---

## Implementation Team Conversations

### 2026-04-27 — c-expert: Priority 1-6 deep trace (resolves all hypotheses)

**From:** c-expert → **To:** architect

> Second pass with full Death/Dismiss traces.
>
> **Priority 1 — Death() flag-set: CONFIRMED, three independent paths.**
> - Normal path (`companion.cpp:660-678`): `SetSuspended(true)` + `Save()`, with direct SQL fallback if Save() fails (BUG-028 layer 2).
> - Entity-id-0 fallback path (`companion.cpp:646-657`): direct SQL `UPDATE is_suspended=1` bypassing ORM.
> - Process() safety net (`companion.cpp:1870-1884`): catches HP=0 without suspension on the next process tick.
> - Death despawn timer (`companion.cpp:1888-1913`): after DeathDespawnS seconds with no rez, sets `is_dismissed=1 AND is_suspended=1` + `Save()`. **This is Lydl's path — timer fired.**
> - **Dismiss() parameter is `permanent`, not `voluntary`:** `Dismiss(false)` = voluntary (sets both flags, Save). `Dismiss(true)` = soul-wipe (deletes row). cmd_dismiss calls `Dismiss(false)`.
>
> **Priority 2 — CreateFromNPC does NOT re-apply restrictions: CONFIRMED.**
> - Queries `(is_dismissed=1 OR is_suspended=1) LIMIT 1` with no ORDER BY. Duplicate rows → non-deterministic selection.
> - Track 1: unconditional `Load()` + `SetHP(max)` + flag clear + cooldown clear. Zero level/faction/cooldown re-validation (`companion.cpp:237-281`).
>
> **Priority 3 — ReRecruitBonus: unused in both C++ and Lua.** Comment at `companion.cpp:3792` says "Lua reads this" but `companion.lua` has zero calls to `eq.get_rule("Companions:ReRecruitBonus")`.
>
> **Priority 4 — "too low level": Lua only,** inside `is_eligible_npc()` at `companion.lua:212`. Unreachable via Track 1.
>
> **Priority 5 — Test infrastructure:** Zone CLI tests at `eqemu/zone/cli/tests/cli_companion_tests.cpp`, 35+ suites, no gtest. New `TestCompanionReRecruitInvariant()` follows Suite 20 pattern.
>
> **Priority 6 — No shared paths with charm/swarm/merc.** Companion inherits NPC only. Death() and Dismiss() are Companion-only overrides, no merc/charm-pet intersection.
>
> **ROOT CAUSE: All four hypotheses eliminated. Flags ARE set by all drop-out paths.** Current Lydl blocker is group capacity (4 active companions + player = 5; Lydl would be 6 = full party). The re-recruitment invariant is correctly implemented. Deliverable is test coverage, not a new code fix.

**Outcome:** Pending architect response. c-expert's finding that all drop-out paths correctly write flags contradicts architect's decision locked at item 3 ("single root cause: drop-out paths failing to write is_dismissed/is_suspended"). Pushing back explicitly: the flags ARE written by every path including triple-fallback safety nets. The current production state of Lydl's DB record confirms this.

---

### 2026-04-27 — c-expert: Cross-check of Dismiss(true) + corrected root cause

**From:** c-expert → **To:** architect

> Cross-check complete. lua-expert is correct on Disagreement 1. I was wrong.
>
> **Dismiss(true) is SoulWipe — confirmed from three source locations:**
>
> `lua_companion.cpp:103-107` — Lua binding:
> ```cpp
> void Lua_Companion::Dismiss(bool voluntary)
> {
>     self->Dismiss(voluntary);  // passes boolean unchanged — no inversion
> }
> ```
>
> `companion.cpp:2553-2568` — C++ implementation:
> ```cpp
> if (permanent) {
>     SoulWipe();    // DELETE companion_data row
> } else {
>     SetSuspended(true); SetDismissed(true); Save();  // preserve for re-recruit
> }
> ```
>
> `companion.lua:1434` — cmd_dismiss call:
> ```lua
> npc:Dismiss(true)   -- passes true → C++ permanent=true → SoulWipe
> ```
>
> The Lua binding names the param `voluntary`, the C++ implementation names it `permanent`. Same boolean, opposite semantics in documentation. `cmd_dismiss` passes `true`, meaning "voluntary dismiss, preserve record" per the Lua doc, but C++ executes `SoulWipe()` (DELETE). Every `!dismiss` permanently deletes the row. Track 1 finds nothing on re-recruit. Track 2 fires. Level check applies. Bug confirmed.
>
> **Disagreement 2 — corrected Lydl walkthrough:**
> Lydl's row exists because Lydl DIED (not dismissed). Death never calls `Dismiss()`. Row preserved with `is_suspended=1`. `check_existing_companion_record(10162, 6)` DOES return the row. Track 1 fires. `is_re_recruitment_eligible()` runs. Group check: 4 companions + 1 player = 5. `5 >= 6` → FALSE. Group is NOT full. All five checks in `is_re_recruitment_eligible()` pass. `_on_recruitment_success()` fires. Lydl can currently be re-recruited.
>
> My prior "party full" diagnosis was wrong — I misread the check as blocking at 5 when it actually requires 6.
>
> **Revised root cause:** Single bug at `companion.lua:1434`. Fix is `Dismiss(true)` → `Dismiss(false)`. Also rename `lua_companion.cpp:103` param from `voluntary` to `permanent` to eliminate the semantic mismatch. C++ behavior is correct — only the call site and binding name are wrong.

**Outcome:** Architect's "single root cause = cmd_dismiss passing wrong boolean" is confirmed. c-expert corrects prior incorrect claim that "all flags are written correctly." The voluntary-dismiss path (cmd_dismiss → Dismiss(true) → SoulWipe) does NOT write flags — it deletes the row. Death path is correct; dismiss path is the bug.

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
