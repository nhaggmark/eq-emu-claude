# XP Retune — Product Requirements Document

> **Feature branch:** `feature/xp-retune`
> **Author:** game-designer
> **Date:** YYYY-MM-DD
> **Status:** Draft | In Review | Approved

---

## Problem Statement

The server-wide XP boost (originally 3x kill XP, 3x AA XP) is leveling
players too fast for a 1–3 player Classic-Luclin experience. Characters are
outpacing era-appropriate content before the intended pacing curve takes hold.
Kill XP needs to be dialed back to slow the leveling tempo, while AA XP should
remain at 3x so the AA grind — which is deliberately accelerated for the
small player count — stays on its faster track.

## Goals

1. Reduce kill XP gain so leveling tempo matches Classic-Luclin era pacing.
2. Preserve the accelerated AA XP rate (3.0x) so AA progression remains fast.
3. Apply the change live via `#reloadrules` with no server rebuild required.

## Non-Goals

- Changing group or raid XP bonus multipliers.
- Modifying hotzone XP bonuses.
- Adjusting level_exp_mods for levels 66–70 (era-lock brake — intentional).
- Changing death XP loss (already softened to 1.5%/death — keep).
- Modifying companion XP rules.
- Any C++ source change.

## User Experience

### Player Flow

1. Player kills a mob and receives less XP than before — the XP bar advances
   more slowly, reflecting Classic-era leveling tempo.
2. Player earns AA points at the same accelerated rate as before — the AA grind
   is unaffected.
3. All other XP sources (group bonuses, hotzones, etc.) behave exactly as before.

### Example Scenario

A level 30 warrior farming gnolls in Blackburrow kills at roughly the same
pace as before, but the XP bar fills more slowly — roughly 33% slower than
the previous 3x rate. The player still has a noticeably faster experience
than a live-EQ player (2x is still a significant boost), but no longer blows
through levels so fast that content becomes trivial.

## Game Design Details

### Mechanics

- `Character:ExpMultiplier` rule: lowered from 3.0 to 2.0.
- `Character:AAExpMultiplier` rule: unchanged at 3.0.
- All other XP-related rules: unchanged (see Non-Goals).
- Change is a database `rule_values` UPDATE to ruleset_id = 1 ("default").
- Applied live via `#reloadrules` — no downtime, no rebuild.

### Balance Considerations

A 2x kill XP multiplier still provides a meaningful boost over live EQ,
appropriate for a solo/duo/trio experience where mob density and group
composition cannot match a full raid or classic player base.
Keeping AA XP at 3x means characters who reach max level still build
their AA progression at an accelerated pace, compensating for the small
group count.

### Era Compliance

This feature adjusts numeric rule values only. No content, zones, items,
or NPCs are added or modified. Full compliance with Classic-Luclin era lock.

## Affected Systems

_Which parts of the codebase does this touch? Check all that apply._

- [ ] C++ server source (`eqemu/`)
- [ ] Lua quest scripts (`akk-stack/server/quests/`)
- [ ] Perl quest scripts (maintenance only)
- [x] Database tables (`peq`) — `rule_values` table
- [x] Rule values
- [ ] Server configuration
- [ ] Infrastructure / Docker

## Dependencies

None. This change is self-contained.

## Open Questions

1. Confirm ruleset_id = 1 is the active ruleset before running the UPDATE.
2. Confirm `Character:ExpMultiplier` is the correct rule name (vs any alias).

## Acceptance Criteria

- [ ] `rule_values` row for `Character:ExpMultiplier` reads `2` (ruleset_id = 1).
- [ ] `rule_values` row for `Character:AAExpMultiplier` still reads `3` (ruleset_id = 1).
- [ ] After `#reloadrules`, killing a mob yields noticeably less XP than before the change.
- [ ] After `#reloadrules`, earning AA XP is unaffected (same rate as before).
- [ ] No other XP-related rule values were modified.

---

## Appendix: Technical Notes for Architect

The config-expert pre-audit confirmed:
- Active ruleset_id = 1 ("default")
- Current `Character:ExpMultiplier` = 3.0
- Current `Character:AAExpMultiplier` = 3.0
- The change is a single-row UPDATE: set value = '2' where rule_name = 'Character:ExpMultiplier' and ruleset_id = 1.
- `#reloadrules` reloads rule values live with no restart required.

---

> **Next step:** Pass this PRD to the **architect** for technical feasibility
> assessment and implementation planning.
