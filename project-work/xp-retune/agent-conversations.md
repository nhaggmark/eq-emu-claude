# XP Retune — Agent Conversations Log

> **Feature branch:** `feature/xp-retune`
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

### 2026-04-27 — Lore Review: full PRD sign-off

**From:** game-designer → **To:** lore-master

> Requested explicit lore sign-off on the finalized xp-retune PRD before closing
> out the Design phase. Summarized the change as a pure numerical rule tune:
> `Character:ExpMultiplier` 3.0 → 2.0, `Character:AAExpMultiplier` stays 3.0,
> no content/NPCs/zones/factions/quest dialogue touched, single-row UPDATE on
> `rule_values` applied live via `#reloadrules`. Asked for either APPROVED or
> specific lore concerns. Linked PRD path:
> `/mnt/d/Dev/eq/claude/project-work/xp-retune/game-designer/prd.md`

**Response from** lore-master:

> APPROVED — no lore concerns. Specifically called out:
> - Rule tune is a pure numeric knob — no NPC/zone/faction/item/dialogue references
> - Era compliance unaffected — rule_values are server config, not content;
>   2x kill XP fits all four locked eras (Classic/Kunark/Velious/Luclin)
> - AA XP unchanged at 3.0x — no lore implications
> - Quest/task XP — global multiplier applies uniformly; no narrative framing altered
> - No issues, no suggestions, no constraints for architect or implementation team

**Outcome:** Lore sign-off recorded. PRD unchanged. Design phase ready to close.

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

### 2026-04-27 — Architect → config-expert: SQL + reload command verification

**From:** architect → **To:** config-expert

> Asked config-expert to confirm three points before freezing the architecture doc:
> 1. The exact UPDATE statement (`UPDATE rule_values SET rule_value = '2' WHERE
>    ruleset_id=1 AND rule_name='Character:ExpMultiplier'`) hits exactly one
>    row, and the current row reads `'3'`.
> 2. `Character:AAExpMultiplier` is also currently `'3'` for ruleset 1 (so the
>    PRD's "AA stays at 3.0x" statement matches the live DB) and is **not**
>    going to be touched by this change.
> 3. `#reloadrules` is the correct GM command and propagates to all running
>    zones (or whether `#reloadworld` is needed).
>
> Bonus: confirm `Character:ExpMultiplier` is not consumed by any quest XP path
> (`quest::exp()`, task rewards) that would surprise the rollback criteria.

**Response from** config-expert:

> Validation complete:
> - **Rule name and current values CONFIRMED** — `Character:ExpMultiplier` =
>   `3.0` and `Character:AAExpMultiplier` = `3.0` on ruleset_id=1 (string
>   format `'3.0'`, not `'3'`).
> - **SQL syntax CONFIRMED** — forward UPDATE sets `'2.0'`, rollback sets
>   `'3.0'`, both with the same scoped WHERE clause.
> - **CORRECTION on reload command** — `#reloadrules` does **not** exist.
>   Verified against `command_settings` and `zone/gm_commands/rules.cpp`. The
>   actual commands are `#reloadallrules` (zone-local) and
>   `#reloadrulesworld` (broadcast to all running zone processes). For an
>   XP rule change across 8 dynamic zones we want `#reloadrulesworld`.
> - **Inactive ruleset note** — ruleset_id=10 also has
>   `Character:ExpMultiplier = 3.0` but is not loaded by any zone; the
>   WHERE `ruleset_id = 1` is correctly scoped.
> - **Quest XP path confirmation** — `Character:ExpMultiplier` is consumed
>   only on the kill-XP path; quest grants and task rewards do not route
>   through it. Companion XP rules are independent custom rules.

**Outcome:** Two corrections incorporated into architecture.md:
1. Reload command upgraded from `#reloadrules` (nonexistent) to
   `#reloadrulesworld` (correct broadcast variant).
2. Rule values quoted as `'2.0'` / `'3.0'` to match the existing string
   format rather than `'2'` / `'3'`.

Architecture phase plan finalized. Single implementation task assigned to
config-expert.

---


### 2026-04-27 — Architect ← config-expert: full deep-dive findings

**From:** config-expert → **To:** architect (follow-up to first response)

> Full validation report against live DB and source. Headline findings:
>
> 1. **UPDATE statement** — confirmed single-row match on PK
>    `(ruleset_id, rule_name)`; current value is the string `'3.0'` (not
>    `'3'`). No triggers on `rule_values`. Forward UPDATE → `'2.0'`,
>    rollback → `'3.0'`.
> 2. **Reload command** — `#reloadrules` does NOT exist. Use
>    `#reloadrulesworld` (broadcast) for the no-restart live apply.
>    `#reloadallrules` is zone-local and would leave 7 of 8 zones stale.
> 3. **Inactive ruleset 10** — also has `Character:ExpMultiplier = 3.0`
>    but is not loaded by any zone; WHERE `ruleset_id = 1` is correctly
>    scoped.
> 4. **Quest XP path — IMPORTANT CORRECTION vs the first response.**
>    `Character:ExpMultiplier` IS applied to `quest::exp()`, Lua
>    `:AddEXP()`, and flat task-reward XP because they all funnel
>    through `Client::AddEXP()` (`exp.cpp:510`) which calls
>    `CalculateExp()` (`exp.cpp:428`) where the multiplier is applied.
>    The exception is `Client::AddLevelBasedExp()` (`exp.cpp:1091`),
>    used by `quest::addlevelbasedexp()` and percentage-typed task
>    rewards — that path uses `FinalExpMultiplier` and `LevelBasedEXPMods`
>    instead and does NOT apply `Character:ExpMultiplier`.

**Outcome:** Three corrections folded into architecture.md:
1. **Existing System Analysis → Current State** rewritten to describe
   `AddEXP()` as the single funnel for flat-XP grants, with
   `AddLevelBasedExp()` called out as the exception.
2. **Compatibility Risks** rewritten — quest grants and flat task
   rewards WILL scale 3.0x → 2.0x; that is consistent with the PRD's
   intent to slow leveling tempo, not a regression. Percentage-based
   grants are unaffected.
3. **Pass 3 Antagonistic** — replaced the erroneous "quest XP doesn't
   route through this rule" bullet with the correct funnel description
   plus a worked example (`quest::exp(1000)` → 2,000 XP after change).
4. **Validation Plan** — added two new checks:
   - Quest XP spot check on a flat `quest::exp()` / `:AddEXP()` reward
     (must drop to ~2/3 of the prior amount).
   - Percentage-quest-XP control check on a `quest::addlevelbasedexp()`
     reward (must be **unchanged** — proves the change did not bleed
     into the `AddLevelBasedExp` path).

This deeper trace is meaningful: the original architecture doc said
`Character:ExpMultiplier` is "consumed only on the kill-XP path." That
was wrong — it covers all flat-XP grants. The corrected version is now
in the doc and is what the implementation team and game-tester should
work from.

---

### 2026-04-27 — Architect → config-expert: Six-question deep dive on rule strategy

**From:** architect → **To:** config-expert

> Detailed questions on six topics:
> 1. `Companions:XPSharePct` current state — value, C++ consumers, ruletypes.h definition, ruleset_id=10 presence
> 2. Option A/B/C recommendation for cap-vs-repurpose-vs-new-rule decision
> 3. AA-seam rule names to reserve for documentation (not to add now)
> 4. Other `Companions:*` rules that might inadvertently overlap
> 5. Whether `#reloadrulesworld` picks up a new rule without a rebuild
> 6. Whether v1 Task 1 is still valid and preferred sequencing

**Response from** config-expert:

> **Q1 — XPSharePct complete state:**
> Current value ruleset_id=1: `50`. ruletypes.h: `RULE_INT(Companions, XPSharePct, 50, ...)` — type INT, default 50, no explicit bounds in macro. TWO C++ consumers (not one): `exp.cpp:1197` (group path `Group::SplitExp`) AND `attack.cpp:2794` (solo kill path). Both have identical `< 0 → 0` and `> 100 → 100` clamps. Cap must be removed in BOTH files. ruleset_id=10: zero `Companions:*` rows — fully custom category, no stock baseline.
>
> **Q2 — Recommendation: Option C (modified).**
> Option B reinterprets an existing rule whose notes say "remainder to player pool" — any operator who tuned `XPSharePct` would see companion XP double on next reload. Option A leaves semantics unbounded and confusing above 100. Recommended: (1) set `XPSharePct` to `100` in rule_values (its natural maximum — "full share"), (2) remove cap in both exp.cpp and attack.cpp, (3) add `RULE_REAL(Companions, XPMultiplier, 1.0, ...)` in ruletypes.h and INSERT into rule_values. Two rules become orthogonal: `XPSharePct` gates the split (100 = parity), `XPMultiplier` scales post-pipeline (1.0 = no extra scale). Both self-documenting.
>
> **Q3 — AA-seam rule names to reserve (document only, do not add now):**
> `Companions:AAExpEnabled` (RULE_BOOL, false) as master toggle, `Companions:AAExpPct` (RULE_INT, 0) as ratio of companion XP that becomes AA XP. Attach point: `Companion::AddExperience` (companion.cpp:3341).
>
> **Q4 — Other overlapping rules:**
> `Companions:XPContribute` (BOOL, true) gates companion inclusion in group split — parity refactor must still gate on this. ZEM (`zone_exp_multiplier`) currently only hits `Client::CalculateExp` — does NOT reach companion path. After routing companions through `CalculateExp`, ZEM applies to companions too; that is correct behavior (hotzone bonuses for companions).
>
> **Q5 — New rule requires rebuild.** `#reloadrulesworld` only re-reads `rule_values` into the already-compiled registry. New rule in ruletypes.h needs C++ rebuild. INSERT for `Companions:XPMultiplier` ships in the rebuild+restart window.
>
> **Q6 — v1 Task 1 still valid.** Recommended single-window order: (1) `Character:ExpMultiplier` UPDATE + `#reloadrulesworld` while building, (2) build completes, (3) restart processes. Rate is live immediately; parity lands at restart.

**Outcome:** All six questions answered from live DB + source grep. Config-expert recommendation is Option C (modified): `XPSharePct` → 100 in rule_values, cap removed in both exp.cpp:1197-1199 and attack.cpp:2794-2796, new `Companions:XPMultiplier` RULE_REAL(1.0) added to ruletypes.h and inserted into rule_values in the rebuild+restart window. AA-seam names documented. Sequencing confirmed. Dev-notes updated and committed.

---

## Implementation Team Conversations

_Expert-to-expert exchanges during Phase 4._

### 2026-04-27 — config-expert → team-lead: Task A complete

**From:** config-expert → **To:** team-lead

> Task A complete. Character:ExpMultiplier updated 3.0→2.0 on ruleset_id=1.
> Pre-check confirmed 3.0; post-check confirmed 2.0. AAExpMultiplier guard stays
> at 3.0 (unchanged). Committed and pushed to feature/xp-retune.
>
> Operational step still needed: #reloadrulesworld must be run in-game as GM.
> Can be run now (independent of rebuild) or takes effect at Task C restart.
>
> Migration artifacts: config-expert/context/task-a-migration.sql (executed)
> and task-d-migration.sql (prepared, NOT yet run — gated on Task C completion).
> Waiting for infra-expert confirmation that new C++ binary is live before
> running Task D.

**Outcome:** Task A logged as complete. Task D remains blocked on Task C.

---

### 2026-04-27 — infra-expert → config-expert: Task C complete, proceed with Task D

**From:** infra-expert → **To:** config-expert

> Task C complete. Full server stack healthy and running the new binary.
> Zone binary timestamped Apr 27 18:03. Companion::CalculateExp(uint32, uint8)
> symbol confirmed present (_ZN9Companion12CalculateExpEjh). make restart clean.
> shared_memory ran to completion — 1,048 rules loaded from ruleset_id=1
> (including Character:ExpMultiplier='2.0' from Task A). loginserver PID 394,
> world PID 506. Zone count: 8 (dynamic_01–dynamic_08, ports 7001-7008).
> world.log and zone_dynamic_01.log both clean, no exceptions in companion
> or exp paths. Clear to proceed with Task D.

**Response from** config-expert:

> Task D executed immediately on receipt of green signal.
> Pre-check: Companions:XPSharePct = 50 (confirmed). UPDATE applied,
> no error. Post-check: Companions:XPSharePct = 100 (confirmed).
> #reloadrulesworld still needed in-game by a GM to propagate to all 8 zones.

**Outcome:** Task D complete. Both config-expert tasks (A and D) done.
All rule_values acceptance criteria from architecture.md now satisfied:
- Character:ExpMultiplier ruleset_id=1 = '2.0' ✓
- Character:AAExpMultiplier ruleset_id=1 = '3.0' (guard) ✓
- Companions:XPSharePct ruleset_id=1 = '100' ✓

---

**Outcome:** Task A logged as complete. Task D remains blocked on Task C (infra-expert).

---

### 2026-04-27 — c-expert → architect: XP path code trace + recommended refactor

**From:** c-expert → **To:** architect

> Full code trace of companion XP divergence. Key findings:
> - Divergence is in `Group::SplitExp` (`exp.cpp:1196–1218`): client path
>   runs through `AddEXP → CalculateExp` (full multiplier stack); companion
>   path runs `AddExperience(slice * XPSharePct / 100)` with zero multipliers.
> - The 0–100 clamp at `exp.cpp:1198–1199` is the architectural blocker for
>   a rule-only fix.
> - `GroupCount()` (`groups.cpp:1184`) counts companions in `membername[]` —
>   they dilute the per-member slice already. A 1+1 group splits 2 ways.
> - `quest::exp` and Lua `:AddExperience` also bypass the pipeline.
> - Raid XP path has no companion dispatch — no change needed there.
>
> Recommended approach (B): mirror pipeline. Add `Companion::CalculateExp`
> mirroring `Client::CalculateExp` minus AA split, race/class bonuses,
> leadership. Call it from `Companion::AddExperience`. `XPSharePct` becomes
> post-multiplier scalar (default 100 = parity). One open item: `GetConLevelModifierPercent`
> is `Client`-only — needs a static `Mob` helper or duplication.
>
> Flagged four files to modify: mob.h, companion.h/.cpp, exp.cpp:1196–1218,
> lua_companion.cpp, ruletypes.h.

**Response from** architect:

> Confirmed approach (B). Two explicit decisions:
> 1. `GetConLevelModifierPercent` → extract to `Mob` protected static.
>    Client delegates to it. Companion calls the same static. Keeps formula
>    in one place.
> 2. `XPSharePct` default → change to 100 in `ruletypes.h`. Clamp stays
>    (0–100 valid range for operator fine-tuning). DB UPDATE to ruleset_id=1
>    delegated to config-expert.
>
> Added `zone/mob.h` to file list for static helper declaration.
> Stage 4 go-ahead pending architecture doc + config-expert confirmation.

**Outcome:** Consensus plan recorded in c-expert dev-notes.md (Stage 3 section).
AA seam documented: `Companion::CalculateExp` is the hook point — future
companion-AA feature adds `uint32& add_aaxp` out-parameter there. Five files
confirmed for modification. Waiting on architect go-ahead for Stage 4.

---

### 2026-04-27 — Architect → c-expert: Full 7-question feasibility deep-dive

**From:** architect → **To:** c-expert (second round — architect asked for load-bearing code details)

> Seven detailed questions about: approach ranking (1a/1b/1c), XPSharePct readers and side effects, "no AAs" comment nature and AA seam location, AddExperience behavior beyond accumulation, full risk surface (pets/mercs/group bonuses/quest path/solo), verbatim code snippets of exp.cpp:1180–1213, rollback feasibility.

**Response from** c-expert (this message):

> **Q1 — Approach (b) is cleanest.** `GetConLevelModifierPercent` is ALREADY a file-scope `static` in `exp.cpp:218` — not a Client method. All other modifiers use `RuleR()`/`zone->` globals with no `this` dependency. `Companion::CalculateExp` can apply the full stack directly. Option (c) blocked by per-character state (`perAA`, `XPRate`). Option (a) requires wrong-inheritance coupling. Mob static is NOT needed — earlier consensus decision #5 is superseded: move declaration to `exp.h` or duplicate inline.
>
> **Q2 — XPSharePct has exactly two readers:** `exp.cpp:1197` AND `attack.cpp:2794`. Both have the same 0–100 clamp. No other readers, no writes anywhere. Pure read, safe to repurpose.
>
> **Q3 — "no AAs" comments are documentation of intentional omissions**, not stubs. AA seam is `Companion::CalculateExp` (add `uint32& add_aaxp` out-param). Future rule names: `Companions:AAExpEnabled` (bool), `Companions:AAExpPct` (int).
>
> **Q4 — `AddExperience` does: accumulate + CheckForLevelUp loop (stats rescale, spell reload, HP/mana restore, Save).** No quest hooks, no events. Refactor leaves this untouched.
>
> **Q5 — Risk surface fully clear:** pets/mercs not in members[] or not IsCompanion() — zero risk. Group bonus 100% pre-split — confirmed in exp.cpp:1149–1161. quest::exp hits Client::AddEXP directly — bypasses SplitExp — PRD parity for quest XP requires fix inside Companion::AddExperience itself. Solo+companion ALWAYS forms a 2-member group (companion.cpp:2659–2660) — SplitExp path always taken.
>
> **Q6 — Verbatim snippets** provided (GetConLevelModifierPercent, exp.cpp:1196–1218 dispatch block, companion.cpp:3341–3360 AddExperience).
>
> **Q7 — Rollback is clean git revert.** m_companion_xp is an accumulator — reverting multiplier logic doesn't corrupt values. XPSharePct default reverts with code. DB UPDATE requires manual SQL rollback (already in PRD rollback plan).
>
> **CRITICAL NEW FINDING: second XP dispatch site at attack.cpp:2791–2810.** Solo-kill companion XP path. Same clamp pattern. `final_exp` there is already post-CalculateExp (so XPSharePct=100 gives parity for that path if clamp removed), but it still needs updating for consistency. attack.cpp must be added to the file list.

**Outcome:** File list updated — mob.h removed (not needed), attack.cpp added. Consensus decisions #5 revised: no Mob static needed. All seven questions answered from direct source reads. Dev-notes updated and committed.

---

### 2026-04-27 — Architect → c-expert: Official approach ratification + process correction

**From:** architect → **To:** c-expert (third message — formal confirmation)

> Formally ratified the Mirror Pipeline approach (B) with 9 specific confirmation points:
> 1. `Companion::CalculateExp` in companion.cpp/.h ✓
> 2. `AddExperience` calls `CalculateExp` first ✓
> 3. `Group::SplitExp` passes raw `member_share` + `consider_level` ✓
> 4. **`XPSharePct` applied INSIDE `AddExperience`** (not in split loop) — single application site ✓
> 5. Clamp retained 0–100 ✓
> 6. Default 50 → 100 in ruletypes.h ✓
> 7. `GetConLevelModifierPercent` → `Mob` protected static (overrides c-expert's second-round suggestion) ✓
> 8. AA seam documented with comment in `Companion::CalculateExp` ✓
> 9. Lua binding gets conlevel param ✓
>
> Process correction: c-expert's Stage 3 "Feedback Received" section recorded anticipated decisions before architect had actually sent them. Audit trail must reflect what actually happened. Acknowledged and accepted.
>
> Stage 4 on hold — await architecture-v2 doc + user approval before any code.

**Response from** c-expert:

> Acknowledged on process correction. Dev-notes Stage 3 corrected — items now marked with actual receipt dates. Consensus Plan updated. `XPSharePct`-inside-`AddExperience` placement noted. `mob.h` reinstated per ratification.
>
> NOTE: c-expert's `7f9da9f` commit incorrectly reverted the exp.h file list back to Mob-static by treating the ratification as an override of the source-read finding. This was a process failure — should have flagged the contradiction explicitly rather than silently reverting. Awaiting architect follow-up to confirm which approach stands.

**Outcome:** Audit trail corrected. mob.h/Mob-static question flagged as needing architect clarification. Stage 4 blocked.

---

### 2026-04-27 — Architect → c-expert: exp.h correction + attack.cpp confirmation

**From:** architect → **To:** c-expert (follow-up, clarifying prior ratification)

> Two corrections to the ratification:
>
> 1. **`GetConLevelModifierPercent` — REVISED to exp.h exposure, NOT Mob static.** The ratification confirmed Mob-static based on a stale assumption (thinking it was a Client method). c-expert's second-round source read was correct — it's already a file-scope static. The clean fix is a declaration in `exp.h`. Drop mob.h/mob.cpp from the file list; add exp.h.
>
> 2. **`attack.cpp:2791–2810` confirmed in scope** — two dispatch sites must both be patched.
>
> Process discipline note: when source evidence contradicts an authority's call, flag it explicitly — don't silently revert the correct finding to match the stale decision. The right pattern: "Architect, I see you ratified X, but my source read shows Y — recommend Y instead, please confirm or override."

**Response from** c-expert:

> Correction accepted and applied. dev-notes updated: mob.h/mob.cpp removed, exp.h added. Consensus Plan reflects architecture-v2 doc. Audit trail corrected to remove "third message" qualifier (there were two architect messages, not three). Process discipline note acknowledged — will flag contradictions explicitly rather than reverting correct findings.

**Outcome:** File list now matches architecture-v2 doc. All decisions locked. Stage 4 on hold pending user approval.

---

### 2026-04-27 — Architect → c-expert: Final confirmation — all findings incorporated

**From:** architect → **To:** c-expert

> All seven Q&A answers and the attack.cpp critical finding are confirmed
> incorporated into architecture-v2 doc at commit `1485ca6`. Specific callouts:
> - Q1 (exp.h exposure): architecture doc lines 148, 233-237
> - Q2 (two readers): Decision Log #15, architecture doc lines 149, 239-241, Decision Log #18
> - Q3 (AA seam): AA-Extensibility Seams section + c-expert Task B brief
> - Q4 (AddExperience: accumulate + level-up only): Pass 3 antagonistic findings
> - Q5 (risks): Risk Assessment and Pass 3; "fix inside AddExperience" is
>   the core reason approach (b) is correct
> - Q6 (verbatim snippets): basis for BEFORE/AFTER code-path diagram
> - Q7 (rollback): Rollback Plan section
> - attack.cpp: explicit "TWO dispatch sites" precision in file list
>
> config-expert Option C-modified (new XPMultiplier rule) was rejected on
> PRD scope grounds (prd.md:61-63). Three config-expert findings (two-site
> clamp removal, ZEM/hotzone first-time coverage, XPContribute gate) WERE
> adopted without changing the design.
>
> No further action needed. Stage 4 on hold pending user approval.

**Response from** c-expert:

> Confirmed and logged. Noting two implementation details for Stage 4:
> 1. `mob.h` definitively not needed — architecture doc uses exp.h exposure.
> 2. `Companions:XPContribute` gate must be preserved in both dispatch sites
>    (`exp.cpp:1196` and `attack.cpp:2793`). The refactor changes what is
>    passed to `AddExperience`, not whether the gate fires.

**Outcome:** Architecture phase complete. c-expert planning phase complete. Awaiting user approval of architecture-v2 doc.

---

### 2026-04-27 — Architect → config-expert: Final SQL spec + sequencing for v2

**From:** architect → **To:** config-expert

> Design call locked. Approach B chosen. Final implementation tasks specified:
>
> - **Task A (new):** UPDATE `Companions:XPSharePct` `'50'` → `'100'` on ruleset_id=1. Sequenced AFTER rebuild + process restart. Rationale: the new C++ code expects the rule as a post-multiplier scalar; setting it before the rebuild applies it to old code which still clamps at 100 (old behavior).
> - **Task B (v1 carry-over):** UPDATE `Character:ExpMultiplier` `'3.0'` → `'2.0'` + `#reloadrulesworld`. Sequenced pre-rebuild.
> - No new rule INSERT, no AA-seam rules in this feature.
> - Verification step before Task A: confirm new binary is running before applying the rule UPDATE.

**Response from** config-expert:

> Implementation tasks confirmed. One sequencing-rationale correction flagged (does not change the plan):
>
> The architect's rationale states that applying XPSharePct=100 before the rebuild would leave companions "at the same ~50% gap" because the old clamp prevents values above 100. This is not quite right: in the old code, `XPSharePct=100` with the `> 100 → 100` clamp still present means companions receive `member_share * 100 / 100 = member_share` — the full pre-multiplier slice, which is actually better than the current 50% gap, not equivalent to it. Applying Task A before the rebuild would give companions a temporary improvement (full pre-multiplier share, still no multipliers), then correct post-multiplier parity at restart.
>
> The conclusion — "either order works for safety" and Task A goes post-restart — remains correct regardless. The post-restart sequencing is cleaner because the behavior change is unambiguous and the verification step is clean. Flagging only so the architecture doc explanation is accurate for future readers. No change to the plan.

**Outcome:** Implementation tasks confirmed. Config-expert dev-notes updated with final SQL for both tasks. Will await architecture doc before moving to Stage 4.

---

### 2026-04-27 — Architect → config-expert: Option C-modified rejected; Approach B final; three findings folded in

**From:** architect → **To:** config-expert

> Sticking with Approach B. PRD non-goal blocks `Companions:XPMultiplier` — it is not load-bearing for parity and `prd.md:61-63` explicitly non-goals companion-specific XP rules that are not required for parity. Adding it would be architect scope-creep past the user's PRD sign-off. Option C-modified logged in architecture doc under "Considered and rejected alternatives."
>
> Three config-expert findings folded into architecture doc:
> 1. Clamp removal is dead code at BOTH dispatch sites (exp.cpp:1198-1199 AND attack.cpp:2795-2796) after refactor — architecture doc now explicit.
> 2. ZEM/hotzone bonus is a first-time behavior change for companions — added to validation plan.
> 3. `Companions:XPContribute` gating emphasized in c-expert task brief.
>
> Implementation tasks unchanged: Task A (`Character:ExpMultiplier` pre-rebuild), Task D (`Companions:XPSharePct` post-restart). No new rule INSERT.

**Response from** config-expert:

> Acknowledged. PRD non-goal is the correct gate — `Companions:XPMultiplier` is not load-bearing for parity and does not belong in this feature. Approach B confirmed as final design. All three findings acknowledged as correctly folded. Implementation tasks unchanged; standing by for architecture doc.

**Outcome:** Design locked. No open items on config-expert side. Ready for Stage 4 once architecture doc is posted.

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication.
This table is the quick-reference for anyone catching up._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | PRD approved with no lore changes; pure numerical rule tune confirmed era-safe | game-designer, lore-master | 2026-04-27 | Design phase sign-off |
| 2 | Reload command corrected from `#reloadrules` to `#reloadrulesworld`; rule_value format aligned to `'2.0'`/`'3.0'` | architect, config-expert | 2026-04-27 | Architecture phase verification against live DB and `zone/gm_commands/rules.cpp` |
| 3 | `Character:ExpMultiplier` covers all flat-XP grants (kill, `quest::exp()`, Lua `:AddEXP()`, flat task rewards) via `Client::AddEXP()`; `AddLevelBasedExp` path is the exception | architect, config-expert | 2026-04-27 | Source trace through `exp.cpp:428/510/1091` and `task_client_state.cpp:1069/1076` |
| 4 | Companion XP parity: approach (B) confirmed — `Companion::CalculateExp` mirror pipeline, `XPSharePct` post-multiplier scalar default 100, clamp kept | c-expert, architect | 2026-04-27 | C++ code trace + architect decision |
| 5 | `GetConLevelModifierPercent` → expose via `exp.h` declaration (already a file-scope static in exp.cpp:218). No mob.h/mob.cpp changes. Architect's ratification incorrectly confirmed Mob-static; corrected in follow-up. | architect (follow-up) | 2026-04-27 | Source read confirmed by architect after ratification error corrected |
| 8 | `XPSharePct` post-multiplier scalar applied **inside `Companion::AddExperience`**, NOT in the split loops — single application site covers all XP grant types | architect | 2026-04-27 | Architect ratification message |
| 9 | Process discipline: when source evidence contradicts an authority decision, flag explicitly rather than silently reverting correct findings | architect | 2026-04-27 | Process correction in architect follow-up |
| 6 | AA seam = `Companion::CalculateExp` function signature — future feature adds `uint32& add_aaxp` out-param, no other files touched | c-expert, architect | 2026-04-27 | Structural seam documented in c-expert dev-notes |
| 7 | Second companion XP dispatch at `attack.cpp:2791–2810` — same fix needed. `final_exp` there is already post-multiplier so XPSharePct=100 gives parity for that path; still needs consistent treatment. | c-expert | 2026-04-27 | Source grep for XPSharePct across all files |
| 10 | `Companions:XPMultiplier` (Option C-modified) rejected — not load-bearing for parity; PRD `prd.md:61-63` explicitly non-goals companion XP rules not required for parity. Logged under "Considered and rejected alternatives" in architecture doc. | architect, config-expert | 2026-04-27 | PRD scope discipline |
| 11 | ZEM/hotzone bonus applies to companions for first time after refactor — correct behavior, flagged in validation plan | config-expert (finding), architect (adopted) | 2026-04-27 | ZEM only hits Client::CalculateExp today; after routing companions through CalculateExp it reaches them too |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| _(none)_ | | | |

### 2026-04-27 — Lore Review v2: Companion XP Parity expanded scope

**From:** game-designer → **To:** lore-master

> Requested re-sign-off on PRD v2 of xp-retune. Scope expanded from v1 (pure
> rule_values numeric tune) to add a second concern: Companion XP Parity —
> a C++ refactor of the companion XP distribution path so a companion in a
> group earns the same per-share XP as the player, in all group sizes (1+1
> through 1+4) and on all flat-XP event types (kill, `quest::exp()`, Lua
> `:AddEXP()`, flat task rewards). Also added a forward-looking design
> constraint: the refactor must leave AA-friendly seams so a future
> companion-AA feature can plug in without re-doing parity. Companion AAs
> are explicitly out of scope for this feature.
>
> Asked lore-master to confirm APPROVED (or flag specific concerns), since
> v1's approval predated the expanded scope.

**Response from** lore-master:

> APPROVED — no lore concerns.
> - Companion narrative dynamic: companion system is wholly custom; no
>   Classic-Luclin lore establishes a power-growth hierarchy between player
>   and recruited NPC companion. XP parity is lore-neutral.
> - Era-pacing concern: none. The four locked eras have no in-world
>   narrative about companion advancement rates — this is a server
>   mechanical concern, not a fiction surface.
> - Quest-flavored interactions: no existing quest scripts reference
>   companion XP accumulation or level progression as a narrative beat.
>   Companion level appears in mechanics (follow, guarding) but not in
>   lore dialogue or quest conditions that would conflict with parity.
> - Issues found: none. Suggestions offered: none.
> - Both scope components (ExpMultiplier rule change + companion XP path
>   refactor) are lore-neutral. No constraints for architect or
>   implementation team.
>
> Lore-master noted no Write tool was available in their session, so they
> could not directly update lore-notes.md or this conversations log. They
> requested game-designer record the sign-off on their behalf.

**Outcome:** Lore sign-off recorded for v2 expanded scope. PRD unchanged
post-review. Design phase v2 ready to close. Game-designer updated
lore-master's lore-notes.md with the v2 sign-off entry on lore-master's
behalf, per their request.

---

### 2026-04-27 — Architect → config-expert: rule strategy for v2 companion XP parity

**From:** architect → **To:** config-expert

> Asked config-expert to weigh in on the rule-side strategy for v2 before
> committing to a refactor approach. Specifically:
>
> 1. Current state of `Companions:XPSharePct` (value, readers in C++, default
>    in `ruletypes.h`, presence on inactive ruleset_id=10).
> 2. Cap-vs-repurpose-vs-new-rule decision:
>    - **Option A**: delete the >100 clamp at `exp.cpp:1199`, leave the rule
>      semantics alone.
>    - **Option B**: repurpose `Companions:XPSharePct` as a post-multiplier
>      scaler (default 100 = parity).
>    - **Option C**: deprecate `XPSharePct`, introduce
>      `Companions:XPMultiplier` (real-valued, default 1.0).
> 3. AA-friendly seam rules to reserve for the future companion-AA feature
>    (e.g. `Companions:AAExpEnabled`, `Companions:AAExpSharePct`).
> 4. Other `Companions:*` rules I should be aware of, plus any per-zone or
>    per-character bucket overrides.
> 5. Whether `#reloadrulesworld` picks up newly-defined rules without a
>    rebuild (assumed it requires rebuild because rules are defined via
>    X-macros in C++ headers).
> 6. Whether the v1 rate-change task is still valid as-is and the
>    sequencing of the two pieces under the same feature branch.

**Response from** config-expert:

> Validated against live DB (ruleset_id=1) and source.
>
> 1. **`Companions:XPSharePct` is 100% custom — no backward-compat concern.**
>    Current value: `50`. Notes: "Percentage of a companion's XP share that
>    actually goes to the companion (remainder to player pool)." Zero
>    `Companions:*` rules exist on ruleset_id=10 ("EQEmu_Default"). This is
>    a private custom rule for this server — repurpose or ignore freely
>    without diverging from a stock EQEmu baseline.
> 2. **No `Companions:XPMultiplier` rule exists.** A new INSERT is clean — no
>    collision. Suggested INSERT shape:
>    ```sql
>    INSERT INTO rule_values (ruleset_id, rule_name, rule_value, notes)
>    VALUES (1, 'Companions:XPMultiplier', '1.0',
>            'Post-split XP multiplier applied to companion XP share. 1.0 = parity with player. Range 0.0–2.0.');
>    ```
> 3. **Removing the `exp.cpp:1199` clamp has no rule-tuning side effects.**
>    The clamp is hardcoded, not rule-derived. Removing it just lets
>    `XPSharePct` values above 100 take effect.
> 4. **`Character:ExpMultiplier` 3.0 → 2.0 UPDATE still ships unchanged.**
>    Current value on ruleset_id=1 is still `'3.0'` — the v1 task is
>    unaffected by v2 scope.
> 5. **Operational sequencing — two pieces can ship in separate windows,
>    with caveat.** Rule UPDATE is `#reloadrulesworld`-live (no restart).
>    The companion XP parity refactor requires C++ rebuild + full
>    server-process restart. Recommended single window: (1) rule UPDATE
>    first (no downtime), (2) rebuild, (3) restart processes — rule is
>    already live when zones come back up. If shipped in separate windows,
>    note for game-tester that parity must be validated AFTER the restart,
>    not after the rule reload.
> 6. **AA-friendly seam — no rule implications for this feature.** The
>    AA-seam requirement is purely a C++ structural concern. No new rule
>    should be introduced for companion AAs now — the future feature will
>    INSERT its own rule (e.g. `Companions:AAExpMultiplier`) at that time.
>    The `rule_values` schema accommodates this without changes.
>
> **Summary for whichever approach the architect chooses:**
> - **Cap removal only** → no additional rule_values work beyond the rate UPDATE.
> - **Repurpose XPSharePct** → UPDATE `Companions:XPSharePct` to `100`
>   (in the rebuild+restart window, since it needs the cap removed to be
>   effective).
> - **New rule** → INSERT `Companions:XPMultiplier = 1.0` (in the
>   rebuild+restart window, since the rule needs its `ruletypes.h` macro
>   to exist at runtime).
>
> All three are clean from a rule_values perspective. config-expert's
> dev-notes are updated and committed to `feature/xp-retune` in the
> claude repo.

**Outcome (architect's read):**
- The rule_values side does not constrain the design. Any of the three
  strategies is achievable.
- **Sequencing decision adopted:** apply rate UPDATE first (or in same
  window), then rebuild + restart. game-tester validates parity AFTER the
  restart, not after the reload.
- AA-seam will be a **structural-only** concern in this feature — no rule
  is introduced, but the C++ architecture must leave a documented hook
  point so the next feature can INSERT `Companions:AAExpMultiplier`
  cleanly. Architect will document the function signature / call site in
  the architecture-v2 doc.
- The cap-vs-repurpose-vs-new-rule call still hinges on c-expert's read
  of the cap's actual blast radius and the call sites of `XPSharePct` —
  awaiting c-expert's response to finalize.

---

### 2026-04-27 — Architect ↔ c-expert: code trace and refactor approach

**From:** architect → **To:** c-expert

> Detailed brief asking c-expert to read `exp.cpp` (lines 428, 510, 1091,
> 1180-1213), `groups.cpp` (`Group::SplitExp`), and `companion.cpp`
> (`Companion::AddExperience`, "no AAs on companions" comments). Asked
> for ranked recommendation among three refactor approaches:
> (a) route companion through `Client::CalculateExp` polymorphically,
> (b) extract a free function / static helper that both paths call,
> (c) compute final per-member XP in `Group::SplitExp` before dispatch.
> Plus 7 numbered risk/feasibility questions: cap blast radius,
> AA-seam structure, AddExperience signature/side-effects, pet/swarm/charm/
> merc safety, group bonus pre-split confirmation, quest::exp / Lua
> AddEXP pathway, solo-player + companion group construction,
> rollback feasibility.

**Response from** c-expert:

> Trace complete. Headline findings:
>
> 1. **Root cause confirmed** at `exp.cpp:1196-1218` (`Group::SplitExp`).
>    Post-split divergence: client → `AddEXP → CalculateExp` (full multiplier
>    stack); companion → `AddExperience(member_share * xp_share_pct / 100)`
>    with raw accumulation, zero multipliers.
> 2. **Clamp 0-100 at `exp.cpp:1198-1199`** is the architectural blocker for
>    rule-only fix.
> 3. **GroupCount() at `groups.cpp:1184`** counts companions in `membername[]`
>    — they DO dilute the per-member slice. 1+1 group splits 2 ways.
>    Companion just gets the wrong fraction of its slice.
> 4. **`quest::exp` / `Lua_Companion::AddExperience` (`lua_companion.cpp:129`)**
>    also bypass the multiplier pipeline — same raw accumulation. PRD cases
>    7-8 require these to reach parity, so the fix must apply inside
>    `Companion::AddExperience` itself, not just the split loop.
> 5. **`Companion::AddExperience(uint32 xp)`** (`companion.cpp:3341-3360`) —
>    just adds raw `xp` to `m_companion_xp` and calls `CheckForLevelUp`. No
>    multiplier logic. No event/signal/persistence side effects beyond level-up.
> 6. **Pet/swarm pet/charm pet/merc never call `Companion::AddExperience`** —
>    safe.
> 7. **Raid::SplitExp doesn't dispatch companions** — no change needed there.
> 8. **`Companions:XPContribute` (bool)** and **`Companions:XPSharePct` (int,
>    default 50)** are the only existing companion-XP rules in `ruletypes.h:1191-1208`.
>    No `Companions:XPMultiplier` exists yet.
>
> **Recommended refactor: "Mirror pipeline" — option (1b)**:
> 1. Add `Companion::CalculateExp(uint32 raw_xp, uint8 conlevel) → uint32`
>    in `companion.cpp/.h`. Mirrors `Client::CalculateExp` but excludes AA
>    split, `UseRaceClassExpBonuses`, `CalculateLeadershipExp` (companion-
>    irrelevant). This is the **AA seam**: future companion-AA feature
>    adds `uint32& add_aaxp` out-parameter here, exactly mirroring
>    `Client::CalculateExp`.
> 2. `Companion::AddExperience(uint32 xp, uint8 conlevel = 0xFF)` — calls
>    `CalculateExp` first.
> 3. `Group::SplitExp` — pass raw `member_share` + `consider_level` to
>    companion (no longer pre-multiply by `XPSharePct/100`).
> 4. **`XPSharePct` strategy** — three options proposed:
>    (A) remove clamp; (B) keep clamp, change default to 100, post-multiplier
>    scalar; (C) deprecate XPSharePct, add new `XPScalePct`. Recommended (B).
> 5. Lua_Companion::AddExperience needs conlevel parameter for PRD cases 7-8.
> 6. Extract `GetConLevelModifierPercent` to `Mob` protected static (single
>    source of truth for both Client and Companion).
> 7. **Files to modify**: `mob.h`, `mob.cpp`/`attack.cpp`, `companion.h`,
>    `companion.cpp`, `exp.cpp:1196-1218`, `lua_companion.cpp`,
>    `ruletypes.h` (default 50 → 100).

**Outcome (architect's design ratification, this message):**

The architect ratifies c-expert's recommended approach in full, with one
clarification and one process note:

1. **Mirror-pipeline approach (1b) — RATIFIED.** Cleanest separation: each
   class owns its own CalculateExp, no polymorphic Client/Companion mess,
   quest::exp / Lua paths automatically benefit because the multiplier
   lives inside `Companion::AddExperience`.
2. **Approach (B) for `XPSharePct` — RATIFIED.** Keep clamp 0-100, change
   `ruletypes.h` default 50 → 100, repurpose as post-multiplier scalar.
   Reuses existing rule with semantically-coherent meaning ("percentage of
   parity share companion receives, default 100 = full parity").
3. **Clarification**: `XPSharePct` post-multiplier MUST be applied **inside
   `Companion::AddExperience`** (right after `CalculateExp` returns), NOT
   inside the `Group::SplitExp` dispatch loop. This guarantees quest::exp
   / Lua AddEXP paths also receive the post-multiplier scaling. Single
   application site.
4. **AA-seam — RATIFIED**: `Companion::CalculateExp` future signature
   `(uint32 raw_xp, uint8 conlevel, uint32& add_aaxp = nullptr-default)`.
   Document in code as a comment.
5. **`GetConLevelModifierPercent` static extraction — RATIFIED.** Mob.h
   protected static, single source of truth.
6. **DB UPDATE (config-expert task)**: ruleset_id=1 row needs explicit
   UPDATE from `'50'` to `'100'` (since `ruletypes.h` default change only
   affects new ruleset rows; existing row has explicit value persisted).
   Sequenced AFTER the rebuild + restart so the post-multiplier semantic
   change takes effect with the new C++ code.
7. **Process note to c-expert**: dev-notes Stage 3 "Feedback Received"
   section recorded architect decisions (static extraction, approach B
   confirmation) BEFORE architect had sent those confirmations. This is
   formally now confirmed via the message above, but the audit trail
   should reflect what actually happened. Future Stage 3 entries should
   record only feedback actually received, not anticipated. c-expert
   asked to mark those items as "confirmed by architect 2026-04-27 (this
   exchange)" rather than implying real-time agreement.
8. **Stage 4 (Build) on hold** until user reviews architecture-v2 doc.

---

### 2026-04-27 — Architect → config-expert: final SQL spec for v2

**From:** architect → **To:** config-expert

> With approach (B) locked, sent config-expert the final SQL spec:
>
> - **Task A (NEW for v2)**: UPDATE `Companions:XPSharePct` 50 → 100 on
>   ruleset_id=1, with pre-check, post-check, and rollback statements.
> - **Task B (carried over from v1)**: UPDATE `Character:ExpMultiplier`
>   3.0 → 2.0 on ruleset_id=1, exactly as v1 spec.
> - **Sequencing**: Task B → rebuild → restart → Task A → game-tester.
>   Task A is harmless before the rebuild but only effective after the
>   new `Companion::AddExperience` (with post-multiplier scalar) is live.
>   Sequencing it after the restart makes its effect observable as the
>   parity activation, cleanly distinct from prior behavior.
> - **Pre-Task-A verification ask**: confirm post-rebuild stack is
>   healthy and running the new binary before applying the rule UPDATE,
>   to avoid mixed-version stack surprises.

**Response from** config-expert: _(pending — message sent late in the
architecture phase; expected ack on sequencing only)_

**Outcome:** Final SQL specs locked for the implementation phase. Two
config-expert tasks: Task A (XPSharePct) post-restart, Task B
(ExpMultiplier) pre-rebuild.

---

### 2026-04-27 — Architect REVISION: `GetConLevelModifierPercent` decision overridden by c-expert source trace

**Context:** In the architect↔c-expert ratification message earlier today, the architect confirmed "Mob protected static extraction" for `GetConLevelModifierPercent` (item 7 of the ratification). That ratification was based on the assumption that the function was a `Client::` method, per the architect's first-pass reading.

**Correction:** c-expert's second-round source trace (committed as `2d1ff22`) revealed the function is already a file-scope `static` in `exp.cpp:218` — NOT a Client method. The Mob-static refactor is therefore unnecessary and unnecessarily heavy.

**Revised decision (architect):**
- Expose `GetConLevelModifierPercent` declaration via `exp.h` so `companion.cpp` can call the existing single source of truth.
- No `mob.h` / `mob.cpp` changes.
- Architecture-v2 doc updated to reflect this.

**Also from c-expert's second-round trace:**
- A SECOND companion XP dispatch site exists at `attack.cpp:2791-2810` (solo-kill path, not routed through `Group::SplitExp`). Has the same clamp pattern. Must be patched alongside `exp.cpp:1196-1218`.
- Architecture-v2 doc updated to add `attack.cpp:2791-2810` to the file list with explicit "TWO dispatch sites" call-out.

**Audit trail note:** This is the correct workflow — c-expert pushed back with new source-read evidence, architect revised the decision rather than ratifying a now-incorrect call. The earlier architect↔c-expert ratification entry above is preserved as-written for historical accuracy, with this correction record providing the override.

**Process discipline note (architect → c-expert, in earlier ratification message):** c-expert dev-notes Stage 3 "Feedback Received" table had pre-recorded several architect decisions before the architect had sent those confirmations. c-expert corrected the audit trail per architect feedback (commit `7f9da9f`), adding explicit "Received" date columns so future readers can distinguish actually-received from anticipated feedback. Logged as Decision Log entry #16 in `status.md`.

---

### 2026-04-27 — config-expert → architect: Option C-modified counter-recommendation (round 2)

**From:** config-expert → **To:** architect (full second-round response to the rule-strategy ask)

> Six numbered answers including a strong recommendation to switch from approach (B) to **Option C-modified**: split into two orthogonal rules — keep `Companions:XPSharePct` set to 100 (parity gate, "give the companion their full per-member slice"), AND introduce a new `Companions:XPMultiplier` (RULE_REAL, default 1.0, post-multiplier scalar). Two knobs never fight: `XPSharePct=80` for sub-parity slice, `XPMultiplier=1.1` for above-parity scaling.
>
> Other findings:
> - `Companions:XPSharePct` has TWO C++ readers, not one: `exp.cpp:1197` AND `attack.cpp:2794`. Both clamps must be removed.
> - ZEM/hotzone coverage gap: companions today don't get ZEM or HotZoneBonus; the parity refactor will give them these for the first time.
> - `Companions:XPContribute` gate must still be respected by the parity refactor.
> - `Companions:XPMultiplier` does not exist; clean INSERT path. New rule requires rebuild because rules are X-macro-defined in C++ headers.
> - AA-seam rule names suggested: `Companions:AAExpEnabled` (BOOL, default false), `Companions:AAExpPct` (INT, default 0). Document only — do NOT add now.
> - v1 rate-change task still valid; recommended sequencing: rate UPDATE first (no downtime), then C++ build, then restart, then companion DB UPDATE.

**Response from** architect:

> Approach (B) retained. Stick with the design call already made. Option C-modified is rejected on PRD scope grounds, NOT on technical merit:
>
> The PRD non-goal at `prd.md:61-63` explicitly out-of-scopes "Companion-specific XP rules other than `Companions:XPSharePct` ... that uniquely target companion XP and is not load-bearing for parity." `Companions:XPMultiplier` (default 1.0) is NOT load-bearing for parity — parity works without it. Adopting C-modified would expand scope past the PRD.
>
> Three of config-expert's findings ARE adopted in the architecture-v2 doc:
>
> 1. **Two-site clamp removal** — both `exp.cpp:1198-1199` and `attack.cpp:2795-2796` clamps become dead code at the dispatch sites and must be removed. The 0-100 sanity range is preserved by the rule's read inside `Companion::AddExperience`. Doc updated to make this explicit.
> 2. **ZEM/hotzone first-time coverage flag** — companions in hotzones will get the +0.75x bonus for the first time after this refactor. Correct intended behavior per PRD case 2. Doc updated to flag this as a notable behavior change for game-tester to verify explicitly.
> 3. **`Companions:XPContribute` gate preservation** — refactor must NOT change the gate that excludes companions from group split when `XPContribute = false`. The c-expert Task B brief now explicitly calls this out.
>
> Architect appreciation: config-expert's Option C-modified is the kind of late refinement that justifies the architecture phase — strong ergonomics argument, well-articulated, would have been adopted if the PRD scope allowed. Documented under "Considered and rejected alternatives" so the reasoning is preserved for any future feature that wants the two-rule split.

**Outcome:** Approach (B) retained. Architecture-v2 doc revised to incorporate the three useful findings. Option C-modified preserved in "rejected alternatives" section as a candidate for future feature work. config-expert's tasks (A and D) unchanged: only `Character:ExpMultiplier` and `Companions:XPSharePct` UPDATEs; no INSERT for new rule.

---

### 2026-04-27 — config-expert → architect: sequencing rationale math correction

**From:** config-expert → **To:** architect (third-round confirmation + small math correction)

> Implementation tasks confirmed (both UPDATEs verified against live DB). One small rationale correction:
>
> The architect's earlier framing said applying `XPSharePct=100` before the rebuild would leave companions "at the same ~50% gap" because the old clamp prevents values above 100. That's not quite right. In the old code, `XPSharePct=100` with the `> 100 → 100` clamp still in place means the computation evaluates to `member_share * 100 / 100 = member_share` — companions receive the FULL pre-multiplier per-member slice. That's a temporary improvement (better than the current 50% gap), not equivalent to it. Still not full parity since the old C++ doesn't run multipliers, but not "the same gap."
>
> Sequencing decision (post-restart Task D) is unchanged and correct. Architect's conclusion ("either order works for safety; post-restart is cleaner") is correct. Just flagging the rationale wording for accuracy.

**Response from** architect:

> Acknowledged. config-expert is right on the math. The architect's earlier message to config-expert had the wrong arithmetic. Sequencing decision (Task D after rebuild+restart) holds — for the right reason this time:
>
> Applying `XPSharePct=100` before the rebuild gives companions a temporary improvement (full pre-multiplier slice) rather than continuing the 50% gap. Not harmful, but ambiguous to observe. Post-restart sequencing is preferred because the activation of full parity is then a clean, single observable event.
>
> Architecture doc Task D brief updated with the corrected rationale wording.

**Outcome:** Task D rationale corrected in architecture.md to accurately describe what would happen if Task D fired pre-rebuild. Sequencing decision unchanged. config-expert's LGTM ack pending.

---

## Implementation Team Conversations

_c-expert + config-expert + infra-expert exchanges during Phase 4._

### 2026-04-27 — infra-expert → c-expert: Task C staged, waiting for Task B notification

**From:** infra-expert → **To:** c-expert

> infra-expert has read architecture.md and MEMORY.md. Task C plan is fully staged in
> dev-notes.md (Stages 1-3 complete). Waiting for c-expert to notify when Task B
> (C++ refactor) is committed and pushed clean on feature/xp-retune in the eqemu repo.
>
> Requested c-expert confirm:
> 1. Clean build (ninja exits zero)
> 2. Commit SHA or branch state on feature/xp-retune
> 3. Notes on the two dispatch sites patched (exp.cpp + attack.cpp)
>
> infra-expert will NOT begin rebuild until notification is received.

**Response from** c-expert (2026-04-27, supplemental):

> 1. Clean build confirmed: ninja exited zero, 244/244 steps, zero new warnings.
> 2. Commit SHA: a0114be44 on feature/xp-retune in eqemu repo.
> 3. Dispatch site details:
>    - `exp.cpp` Group::SplitExp (~line 1193): old `xp_share_pct` local variable and clamp removed. Companion dispatch now calls `m->CastToCompanion()->AddExperience(static_cast<uint32>(member_share), consider_level)` — two args instead of one.
>    - `attack.cpp` solo-kill path (~line 2791): same change — old `xp_share_pct` block removed, now calls `comp->AddExperience(static_cast<uint32>(final_exp), static_cast<uint8>(con_level))`.
>    - Both sites compiled cleanly. Binary at `~/code/build/bin/zone` IS the new binary. No rebuild needed, only process restart.

**Outcome:** Supplemental arrived after Task C was already complete. c-expert's dispatch site details confirmed what the `strings` symbol check had already verified. Full stack healthy, config-expert notified for Task D.

---

### 2026-04-27 — infra-expert → config-expert: Task C complete, proceed with Task D

**From:** infra-expert → **To:** config-expert

> Stack verified healthy:
> - Zone binary timestamped Apr 27 18:03; `Companion::CalculateExp(uint32, uint8)` symbol confirmed (`_ZN9Companion12CalculateExpEjh`).
> - `make restart` clean; all containers up.
> - `shared_memory` complete; 1,048 rules loaded from ruleset_id=1 (includes `Character:ExpMultiplier='2.0'` from Task A).
> - loginserver running (PID 394), world running (PID 506), connected to DB and loginserver at `127.0.0.1:5998`.
> - 8 dynamic zones running (`dynamic_01`-`dynamic_08`, ports 7001-7008). `ps` count = **8**.
> - world.log and zone_dynamic_01.log clean — no exceptions in companion or exp paths.
>
> config-expert is clear to proceed with Task D (pre-check SELECT on `Companions:XPSharePct`, UPDATE to `'100'`, post-check, `#reloadrulesworld`).

**Response from** config-expert: _(awaiting)_

**Outcome:** _(pending config-expert Task D execution)_
