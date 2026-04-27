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

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication.
This table is the quick-reference for anyone catching up._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | PRD approved with no lore changes; pure numerical rule tune confirmed era-safe | game-designer, lore-master | 2026-04-27 | Design phase sign-off |
| 2 | Reload command corrected from `#reloadrules` to `#reloadrulesworld`; rule_value format aligned to `'2.0'`/`'3.0'` | architect, config-expert | 2026-04-27 | Architecture phase verification against live DB and `zone/gm_commands/rules.cpp` |
| 3 | `Character:ExpMultiplier` covers all flat-XP grants (kill, `quest::exp()`, Lua `:AddEXP()`, flat task rewards) via `Client::AddEXP()`; `AddLevelBasedExp` path is the exception | architect, config-expert | 2026-04-27 | Source trace through `exp.cpp:428/510/1091` and `task_client_state.cpp:1069/1076` |
| 4 | Companion XP parity: approach (B) confirmed — `Companion::CalculateExp` mirror pipeline, `XPSharePct` post-multiplier scalar default 100, clamp kept | c-expert, architect | 2026-04-27 | C++ code trace + architect decision |
| 5 | `GetConLevelModifierPercent` → extract to `Mob` protected static; both `Client` and `Companion` delegate to it | architect | 2026-04-27 | Architect decision to keep formula in one place |
| 6 | AA seam = `Companion::CalculateExp` function signature — future feature adds `uint32& add_aaxp` out-param, no other files touched | c-expert, architect | 2026-04-27 | Structural seam documented in c-expert dev-notes |

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
