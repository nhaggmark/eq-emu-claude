# XP Retune — Product Requirements Document

> **Feature branch:** `feature/xp-retune`
> **Author:** game-designer
> **Date:** 2026-04-27 (v2 — expanded scope: companion XP parity)
> **Status:** Draft v2 (pending lore-master re-sign-off)

---

## Problem Statement

Two related problems with how XP is awarded on this server:

1. **Kill XP rate is too high.** The server-wide XP boost (currently 3.0x
   kill XP) is leveling characters too fast for the intended 1–3 player
   Classic-Luclin experience. Players are outpacing era-appropriate content
   before the intended pacing curve takes hold. Kill XP needs to be dialed
   back to 2.0x. AA XP must stay at 3.0x — the AA grind is the long game and
   is deliberately accelerated to compensate for the low player count.

2. **Companions earn dramatically less XP than the player owning them.** This
   is purely an architectural quirk: the companion XP path bypasses the same
   per-kill multiplier pipeline the player runs through, so even when a
   companion participates in the kill (and is the only reason a small party
   can survive the kill at all), it lags far behind the player in level. For
   a server whose signature feature is recruit-any-NPC companions intended to
   stand in for missing party members, the level gap is a feel problem and a
   power-curve problem. Companions should advance at the same per-share rate
   as the player they belong to.

## Goals

1. **Reduce kill XP gain** so leveling tempo matches a small-group Classic-Luclin pace.
2. **Preserve the accelerated AA XP rate (3.0x)** so AA progression remains fast.
3. **Companion XP parity** — a companion must earn the same XP per-share as
   its owning player, in all group sizes, on every flat-XP event the player
   would receive XP for. Once parity is achieved, a companion in a party of
   N gains the same per-share amount as the player in that same party.
4. **Future-proof the companion XP path for AAs.** Companions do not have AAs
   today and we are NOT adding AAs in this feature. But the refactor that
   delivers parity must leave clean seams a future companion-AA feature can
   plug into without re-doing the work.

## Non-Goals (Explicit Scope Boundaries)

The following are **intentionally not changing**. Calling these out so no one
expands scope mid-implementation:

- **Group XP bonus** — unchanged.
- **Raid XP bonus** — unchanged.
- **HotZone XP bonus** — stays at default +0.75x.
- **`level_exp_mods` table** — levels 66–70 brake stays in place (era-lock pacing).
- **Death XP loss** — already softened to 1.5%/death; stays as-is.
- **Companion AA implementation** — explicitly out of scope. Companions do
  not gain AAs today and will not gain AAs as a result of this feature. The
  refactor must leave AA-friendly seams in the companion XP path (so a future
  feature can enable AAs without ripping out parity), but no AA accrual logic
  is being added now.
- **Quest scripts (Lua/Perl)** — untouched.
- **Server config (`eqemu_config.json`, etc.)** — untouched.
- **Companion-specific XP rules other than `Companions:XPSharePct`** — any
  rule that uniquely targets companion XP and is not load-bearing for parity
  is left alone.
- **Pet/swarm pet XP** — only the recruit-able companion class is in scope.
  Charmed pets, summoned pets, and swarm pets are unchanged.

## User Experience

### Player Flow

1. Player kills a mob and receives less XP than before — the XP bar advances
   roughly 33% slower than at the previous 3x rate.
2. Player earns AA points at the same accelerated rate as before — the AA
   grind is unaffected.
3. **Companion sharing a kill with the player gains XP at the same rate the
   player does for that kill.** A solo player + 1 companion duo will see the
   companion's XP bar advance in step with the player's. A 1-player + 4-companion
   party will see all five XP bars advance in step.
4. All other XP sources (group bonuses, hotzones, raid bonuses, etc.) behave
   exactly as before for both player and companion.
5. The change is invisible from a UI standpoint — no new chat messages, no
   command output, no announcement. Just slower kill XP for the player and
   noticeably faster XP for the companion that closes the gap to parity.

### Example Scenarios

**Solo + 1 companion duo, level 30, killing gnolls in Blackburrow.** Before
the change, a kill that gave the player 100 XP gave the companion roughly
50 XP (an architectural ~50% loss). After the change, the same kill gives
the player ~67 XP (the kill-XP retune) and the companion the same ~67 XP
(parity). The companion no longer falls behind.

**1 player + 3 companions in Sebilis.** A kill is split four ways before
either path applies its multiplier. Before this change, the player
received a multiplied share and each companion received only the
`Companions:XPSharePct` fraction of the same per-member share. After
this change, all four get the same per-share amount.

**Quest XP (`quest::exp(N)`), Lua `:AddEXP(N)`, and flat task rewards.**
The companion (when targeted) earns the same flat-XP amount as the player
would have, after the same multiplier path. Percentage-based grants —
`quest::addlevelbasedexp()` and percentage-typed task rewards — are
unchanged for both player and companion (this path is not in scope).

**Max-level character grinding AA in PoP-era zones.** The player gains
AA points at exactly the same rate as before (AA multiplier is unchanged).
Companions still do not gain AAs — that is a future feature.

## Game Design Details

### Mechanics — Kill XP Rate

- `Character:ExpMultiplier` rule: lowered from 3.0 to 2.0.
- `Character:AAExpMultiplier` rule: unchanged at 3.0.
- All other XP-related rules: unchanged (see Non-Goals).
- Change is a database `rule_values` UPDATE on `ruleset_id = 1` ("default").
- Applied live via the correct broadcast reload command (architect/config-expert
  determined the right command — see Appendix).

### Mechanics — Companion XP Parity

The current divergence between player and companion XP is architectural:
after a group's XP pool is split per-member, the player path runs through
a multiplier pipeline (`Character:ExpMultiplier`, `FinalExpMultiplier`,
`level_exp_mods`, ZEM, etc.) while the companion path applies only
`Companions:XPSharePct/100` (and that share is hard-capped at 100 in code).
Parity requires bringing the companion path through the same multiplier
pipeline as the player — at minimum for the modifiers that apply to flat
kill/quest XP — so that each per-member share lands on the companion at
the same final value the player sees.

Concretely, the player-facing requirement is:

- After group split, the companion's awarded XP for any flat-XP event must
  equal the player's awarded XP for the same flat-XP event (per-share, before
  any future companion-specific scaling that may be introduced).
- The hardcoded "max 100" cap on `Companions:XPSharePct` must no longer
  prevent parity — either by removing the cap, by repurposing the rule to
  scale the post-multiplier amount, or by a different mechanism the architect
  chooses. From a player-experience standpoint we only require that parity
  is achievable and stable.
- Group bonuses (already applied pre-split today) continue to apply equally
  to both player and companion. Pre-split bonuses are unchanged.

### Forward-Looking: AA-Friendly Seams (Design Constraint)

Companion AAs are a planned future feature. To avoid rebuilding the parity
work, this refactor must leave the companion XP path in a state where:

- A future change can route a fraction of incoming XP into companion AA
  accrual without re-touching the player/companion split or the parity logic.
- The companion XP entry point can carry an "AA share vs regular XP" decision
  cleanly (mirroring how `Character:AAExpMultiplier` is handled on the player
  side), without that decision being hardcoded to "no AAs."
- Whatever rule(s) end up controlling parity should be structured so a
  companion-AA-specific rule can be added later without overloading them.

The PRD does not prescribe HOW to leave those seams — that is the architect's
call. The PRD requires only that the architect document, in the architecture
plan, where future companion-AA logic would attach.

### Balance Considerations

A 2x kill XP multiplier still provides a meaningful boost over live EQ —
appropriate for solo/duo/trio play where mob density and group composition
cannot match a full classic player base. Keeping AA XP at 3x means
characters who reach max level continue building AA progression at an
accelerated pace, compensating for the low player count.

The 33% slowdown (3x → 2x) is a meaningful but not punishing reduction.
Time-to-level at the new rate is roughly 1.5x what it was at 3x, which
still keeps leveling significantly faster than vanilla EQ.

Companion XP parity is an XP **distribution** change, not an XP **rate**
increase: the same per-member share that the player receives is what the
companion receives. A 1+1 duo still pulls one full XP pool per kill,
split two ways, multiplied by the same modifiers. This brings companions
in line with the per-member share the player already sees today, rather
than awarding bonus XP on top.

### Era Compliance

Numeric rule tune plus a refactor of XP distribution code. No content,
zones, items, NPCs, factions, or in-world fiction is added or modified.
Full compliance with the Classic through Luclin era lock.

## Affected Systems

- [x] C++ server source (`eqemu/`) — companion XP path refactor required.
- [ ] Lua quest scripts (`akk-stack/server/quests/`)
- [ ] Perl quest scripts
- [x] Database tables (`peq`) — `rule_values` table only
- [x] Rule values
- [ ] Server configuration
- [ ] Infrastructure / Docker

## Dependencies

None external. Internal: the rule-tune piece can land independently of the
parity refactor, but the user wants both shipped under this feature so
companions are not left behind once the player rate drops to 2.0x.

## Open Questions

_All questions from the v1 draft were resolved by the config-expert
pre-audit and the architect/c-expert traces. No outstanding open
questions for the parity scope from a design standpoint — implementation
specifics (cap removal vs. rule repurpose vs. new rule) are explicitly
delegated to the architect._

## Success Metrics

How we know the retune achieved its goal in practice:

1. **Kill XP rate verified at 2x for the player** — a controlled kill of a
   known mob yields roughly 2/3 of the XP it yielded before the change
   (3x → 2x = 0.667x ratio).
2. **AA XP rate unchanged for the player** — at max level, AA points-per-mob
   from the same controlled kill match pre-change rates exactly.
3. **Companion XP parity verified** — for the same controlled kill, the
   companion's XP gain equals the player's XP gain to within rounding
   tolerance, in every supported group composition (see Validation Plan).
4. **No regressions in untouched XP paths** — group XP, raid XP, hotzone
   bonus, death XP loss, and percentage-based quest/task XP grants are
   observably identical to pre-change behavior.
5. **No console errors after the live rule reload** — world.log shows clean
   reload with no rule parse warnings; zone log shows no exceptions in the
   refactored XP path.

## Validation Plan

The game-tester verifies all of the following. Each case is a controlled
test against a known mob or known XP grant, with XP gain compared before
and after the change.

### Player kill-XP rate

| # | Case | Expected |
|---|------|----------|
| 1 | Solo player, single kill of a known mob | Player XP gain ≈ 0.667x of the pre-change amount |
| 2 | Solo player, kill with full hotzone bonus | Hotzone bonus still applies; total scales correctly off the new 2.0x base |

### Companion XP parity (same kill, same group composition)

| # | Case | Expected |
|---|------|----------|
| 3 | 1 player + 1 companion, single kill | Companion XP per-share equals player XP per-share |
| 4 | 1 player + 2 companions, single kill | All three earn equal per-share XP |
| 5 | 1 player + 3 companions, single kill | All four earn equal per-share XP |
| 6 | 1 player + 4 companions, single kill | All five earn equal per-share XP |

### Flat-XP event types reach companions at parity

| # | Case | Expected |
|---|------|----------|
| 7 | `quest::exp(N)` granted to player while companion is in group | Companion gains the same flat amount the player gains |
| 8 | Lua `:AddEXP(N)` on a companion-eligible target | Companion gains parity amount |
| 9 | Flat (non-percentage) task reward XP, player turn-in | Companion in group receives parity share |

### Untouched paths — must NOT change

| # | Case | Expected |
|---|------|----------|
| 10 | `quest::addlevelbasedexp()` percentage grant | Player XP gain unchanged; this path was not in scope |
| 11 | Percentage-typed task reward XP | Unchanged |
| 12 | AA point gain at max level | Unchanged (AA multiplier still 3.0x) |
| 13 | Death XP loss on a level-locked character | Still 1.5%/death |
| 14 | Group XP bonus for a player-only group of 2 | Bonus still applies, scales off new 2.0x base |
| 15 | Pet/swarm pet behavior on kills | Unchanged |

## Rollback Criteria

Rollback is warranted if **any** of these hold after the change is live:

- The rate change causes unintended downstream issues (e.g. a quest XP
  grant or task reward path behaves incorrectly).
- The companion parity refactor introduces a regression on the player XP
  path — player XP gain in any non-companion scenario differs from the
  expected 0.667x ratio.
- The companion parity refactor breaks any non-XP companion behavior
  (recruitment, dismiss, commands, follow, combat AI).
- The user, after playtesting, decides 2.0x is too low and prefers a
  different value (e.g. 2.5x) — rollback for the rate piece is just a
  follow-up `rule_values` UPDATE; rollback for the parity refactor is a
  code revert.

Rollback procedure:

- **Rate-only rollback:** revert the `rule_values` row for
  `Character:ExpMultiplier` to its prior value on `ruleset_id = 1`, and
  re-run the live reload command.
- **Parity-refactor rollback:** revert the C++ commit on `feature/xp-retune`,
  rebuild, restart server processes. The architecture doc must record the
  exact commit boundary so this is a clean revert.

## Acceptance Criteria

### Rate change

- [ ] `rule_values` row for `Character:ExpMultiplier`, `ruleset_id = 1`
      reads `2.0` after the change.
- [ ] `rule_values` row for `Character:AAExpMultiplier`, `ruleset_id = 1`
      still reads `3.0` (unchanged).
- [ ] Live rule reload executed without errors; world.log clean.
- [ ] Post-reload: a controlled mob kill yields meaningfully less XP for
      the player than the same kill before the change (target ratio ~0.667x).
- [ ] Post-reload: AA XP gain from a controlled mob kill at max level is
      unchanged from before the change.

### Companion parity

- [ ] In every group composition from 1+1 to 1+4, the companion's XP gain
      per kill equals the player's XP gain to within rounding tolerance.
- [ ] Flat `quest::exp()`, Lua `:AddEXP()`, and flat task reward grants
      reach companions at parity with the player.
- [ ] No companion AA point accrual is observed (companions still have
      no AAs).
- [ ] The architecture doc identifies the file(s) and function(s) where a
      future companion-AA feature would attach, and the implementation
      leaves those seams in place.

### No regressions

- [ ] Group XP bonus, raid XP bonus, hotzone bonus, `level_exp_mods` brake,
      death XP loss, percentage-based quest/task XP, and pet/swarm pet
      behavior all verified unchanged.
- [ ] No new console errors or zone exceptions tied to the refactored
      XP code path.

## Implementation Note

This feature is **not pure config** in v2. It requires:

1. A `rule_values` UPDATE on `ruleset_id = 1` (rate change), applied live
   via the correct reload command.
2. A C++ refactor of the companion XP distribution path so it shares the
   player multiplier pipeline post-split, with AA-friendly seams left in
   place. This requires a server rebuild and a process restart cycle.

The two pieces ship together on `feature/xp-retune`. The architect chooses
the implementation approach for the refactor; the PRD only mandates the
player-facing parity outcome and the AA-extensibility constraint.

---

## Appendix: Technical Notes for Architect

The architect/config-expert/c-expert traces from the v1 phase plus the
team-lead brief flag the following landmarks. These are pointers, not
prescriptions — the architect owns the design call.

### Rate change (carried over from v1)

- Active ruleset is `ruleset_id = 1` (named "default").
- Current `Character:ExpMultiplier` value is `'3.0'` (string format) — change to `'2.0'`.
- Current `Character:AAExpMultiplier` value is `'3.0'` — unchanged.
- Live reload command: `#reloadrulesworld` (broadcast to all running zones);
  `#reloadrules` does NOT exist; `#reloadallrules` is zone-local and would
  leave 7 of 8 dynamic zones stale.
- `Character:ExpMultiplier` is consumed by `Client::AddEXP` →
  `Client::CalculateExp` (`exp.cpp:428` / `exp.cpp:510`), which covers all
  flat-XP grants — kill, `quest::exp()`, Lua `:AddEXP()`, flat task rewards.
  Percentage-typed grants route through `Client::AddLevelBasedExp`
  (`exp.cpp:1091`) and are NOT affected.

### Companion parity (new in v2)

- Companion XP entry point: `Companion::AddExperience`.
- Player XP entry point: `Client::AddEXP` → `Client::CalculateExp`
  (`exp.cpp:428` / `exp.cpp:510`).
- Group split + dispatch: `Group::SplitExp` divides the pool by member
  count and dispatches to either `Client::AddEXP` or
  `Companion::AddExperience` (post-split divergence at
  `exp.cpp:1180-1213`).
- Group bonuses are applied PRE-split — both player and companion already
  inherit them equally; no change needed there.
- Hardcoded max-100 cap on `Companions:XPSharePct` at `exp.cpp:1199`
  prevents rule-only tuning from achieving parity — the cap is the
  blocker for a config-only fix.
- `companion.cpp` carries multiple "no AAs on companions" comments —
  these are the seams where companion-AA logic will attach in a future
  feature. Architect should preserve the structural separation between
  "companion gets regular XP" and "companion gets AA XP" so a future
  AA implementation does not require re-routing the parity work.

### Parity outcome the design requires

After the refactor, for any flat-XP event that reaches `Group::SplitExp`,
each companion in the group must end up with the same per-member XP value
that a player in that group would receive (ignoring any companion-specific
modifiers we may introduce later — none are introduced in this feature).
HOW the architect achieves that — removing the cap, repurposing
`Companions:XPSharePct` as a post-multiplier scaler, routing companions
through `CalculateExp`, or another approach — is the architect's call.

---

> **Next step:** Pass this PRD to the **architect** for technical feasibility
> assessment and updated implementation planning (companion XP refactor +
> rate change).
