# XP Retune — Product Requirements Document

> **Feature branch:** `feature/xp-retune`
> **Author:** game-designer
> **Date:** 2026-04-27
> **Status:** Approved (pending lore-master sign-off)

---

## Problem Statement

The server-wide XP boost (currently 3x kill XP, 3x AA XP) is leveling
characters too fast for the intended 1–3 player Classic-Luclin experience.
Players are outpacing era-appropriate content before the intended pacing
curve takes hold. Kill XP needs to be dialed back so leveling tempo feels
right for the small-group format, while AA XP must stay at 3x — the AA
grind is the long game and is deliberately accelerated to compensate for
the low player count.

## Goals

1. Reduce kill XP gain so leveling tempo matches a small-group Classic-Luclin pace.
2. Preserve the accelerated AA XP rate (3.0x) so AA progression remains fast.
3. Apply the change live via `#reloadrules` with no server rebuild or downtime.

## Non-Goals (Explicit Scope Boundaries)

The following are **intentionally not changing**. Calling these out so no
one expands scope mid-implementation:

- **Group XP bonus** — unchanged.
- **Raid XP bonus** — unchanged.
- **HotZone XP bonus** — stays at default +0.75x.
- **`level_exp_mods` table** — levels 66–70 brake stays in place (era-lock pacing).
- **Death XP loss** — already softened to 1.5%/death; stays as-is.
- **Companion XP rules** — custom rules unrelated to this change; untouched.
- **C++ source code** — no rebuild required, no source changes.
- **Quest scripts (Lua/Perl)** — untouched.
- **Server config (`eqemu_config.json`, etc.)** — untouched.

## User Experience

### Player Flow

1. Player kills a mob and receives less XP than before — the XP bar
   advances roughly 33% slower than at the previous 3x rate.
2. Player earns AA points at the same accelerated rate as before — the AA
   grind is unaffected.
3. All other XP sources (group bonuses, hotzones, etc.) behave exactly as before.
4. The change is invisible from a UI standpoint — no new chat messages,
   no command output, no announcement. Just slower kill XP.

### Example Scenario

A level 30 warrior farming gnolls in Blackburrow kills at the same pace as
before, but the XP bar fills more slowly. The player still progresses
noticeably faster than a live-EQ player (2x is still a meaningful boost),
but no longer blows through levels so fast that content becomes trivial.
A level 65 character grinding AA in PoP-era zones gains AA points at
exactly the same rate they did yesterday.

## Game Design Details

### Mechanics

- `Character:ExpMultiplier` rule: lowered from 3.0 to 2.0.
- `Character:AAExpMultiplier` rule: unchanged at 3.0.
- All other XP-related rules: unchanged (see Non-Goals).
- Change is a database `rule_values` UPDATE on ruleset_id = 1 ("default").
- Applied live via `#reloadrules` — no downtime, no rebuild.

### Balance Considerations

A 2x kill XP multiplier still provides a meaningful boost over live EQ —
appropriate for solo/duo/trio play where mob density and group composition
cannot match a full classic player base. Keeping AA XP at 3x means
characters who reach max level continue building AA progression at an
accelerated pace, compensating for the low player count.

The 33% slowdown (3x → 2x) is a meaningful but not punishing reduction.
Time-to-level at the new rate is roughly 1.5x what it was at 3x, which
still keeps leveling significantly faster than vanilla EQ.

### Era Compliance

Numeric rule tune only. No content, zones, items, NPCs, factions, or
in-world fiction is added or modified. Full compliance with the Classic
through Luclin era lock.

## Affected Systems

- [ ] C++ server source (`eqemu/`)
- [ ] Lua quest scripts (`akk-stack/server/quests/`)
- [ ] Perl quest scripts (maintenance only)
- [x] Database tables (`peq`) — `rule_values` table only
- [x] Rule values
- [ ] Server configuration
- [ ] Infrastructure / Docker

## Dependencies

None. Self-contained single-row UPDATE.

## Open Questions

_All questions from initial draft were resolved by the config-expert
pre-audit (see Appendix). No outstanding open questions._

## Success Metrics

How we know the retune achieved its goal in practice:

1. **Kill XP rate verified at 2x** — a controlled kill of a known mob yields
   roughly 2/3 of the XP it yielded before the change (3x → 2x = 0.667x ratio).
2. **AA XP rate unchanged** — at max level, AA points-per-mob from the same
   controlled kill match pre-change rates exactly.
3. **No regressions in untouched XP paths** — group XP, raid XP, hotzone
   bonus, death XP loss, and companion XP behavior are observably identical
   to pre-change behavior.
4. **No console errors after `#reloadrules`** — world.log shows clean
   reload with no rule parse warnings.

## Rollback Criteria

Rollback to 3.0x kill XP is warranted if **any** of these hold after the change is live:

- The new rate causes unintended downstream issues (e.g. quest XP grants
  or companion XP behave incorrectly because they reference `Character:ExpMultiplier`).
- `#reloadrules` fails to apply the change live and a restart would be
  required (defeats the "live tune" goal of this feature).
- The user, after playtesting, decides 2.0x is too low and prefers a
  different value (e.g. 2.5x). In that case the rollback is just a follow-up
  rule_values UPDATE — same mechanism, different number.

Rollback procedure: revert the `rule_values` row to value = '3' for
`Character:ExpMultiplier`, ruleset_id = 1, and `#reloadrules` again.

## Acceptance Criteria

- [ ] `rule_values` row for `rule_name = 'Character:ExpMultiplier'`,
      `ruleset_id = 1` reads `rule_value = '2'`.
- [ ] `rule_values` row for `rule_name = 'Character:AAExpMultiplier'`,
      `ruleset_id = 1` still reads `rule_value = '3'` (unchanged).
- [ ] `#reloadrules` executed live; world.log shows clean reload, no errors.
- [ ] Post-reload: a controlled mob kill yields meaningfully less XP than
      the same kill before the change (target ratio ~0.667x).
- [ ] Post-reload: AA XP gain from a controlled mob kill at max level is
      unchanged from before the change.
- [ ] No other XP-related rule values were modified (group, raid, hotzone,
      level_exp_mods, death loss, companion XP all verified unchanged).
- [ ] No server rebuild or restart was required to apply the change.

---

## Appendix: Technical Notes for Architect

The config-expert pre-audit confirmed the following before this PRD was written:

- Active ruleset_id = 1 (named "default").
- Current `Character:ExpMultiplier` rule_value = `3` (target: `2`).
- Current `Character:AAExpMultiplier` rule_value = `3` (no change).
- The change is a single-row UPDATE on `peq.rule_values` —
  `rule_name = 'Character:ExpMultiplier'` AND `ruleset_id = 1`, set `rule_value = '2'`.
- `#reloadrules` reloads rule values live; no restart required.
- Group/raid bonuses, hotzone bonus, death loss, level_exp_mods, and
  companion XP rules are explicitly out of scope and must not be touched.

---

> **Next step:** Pass this PRD to the **architect** for technical feasibility
> assessment and implementation planning.
