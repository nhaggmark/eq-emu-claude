# Companion Re-recruitment Fix — Product Requirements Document

> **Feature branch:** `bugfix/companion-rerecruit`
> **Author:** game-designer
> **Date:** YYYY-MM-DD
> **Status:** Draft | In Review | Approved

---

## Problem Statement

_What problem does this feature solve? Why does it matter for our 1–3 player
Classic-Luclin server?_

## Goals

_What does success look like? Be specific and measurable where possible._

1.
2.
3.

## Non-Goals

_What is explicitly out of scope for this feature?_

-
-

## User Experience

_How does a player experience this feature? Walk through the interaction
step by step from the player's perspective._

### Player Flow

1.
2.
3.

### Example Scenario

_A concrete example: "A level 30 ranger in North Karana wants to recruit
a nearby druid NPC as a companion..."_

## Game Design Details

### Mechanics

_How does this feature work mechanically? Describe in player-facing terms.
Include thresholds, conditions, and tuning knobs. Focus on WHAT and WHY,
not HOW it should be implemented (that is the architect's job)._

### Balance Considerations

_How does this interact with the 1–3 player constraint? What prevents
it from being too strong or too weak?_

### Era Compliance

_Does this feature respect the Classic-Luclin era lock? Any content
references that need verification?_

## Affected Systems

_Which parts of the codebase does this touch? Check all that apply.
Do NOT prescribe specific implementation approach — list systems affected,
not SQL statements or code changes._

- [ ] C++ server source (`eqemu/`)
- [ ] Lua quest scripts (`akk-stack/server/quests/`)
- [ ] Perl quest scripts (maintenance only)
- [ ] Database tables (`peq`)
- [ ] Rule values
- [ ] Server configuration
- [ ] Infrastructure / Docker

## Dependencies

_Does this feature depend on other features or systems being in place first?_

## Open Questions

_Unresolved decisions or unknowns that need answers before implementation.
Include technical unknowns for the architect to investigate._

1.
2.

## Acceptance Criteria

_How do we verify this feature is complete and working? Write from the
player's perspective — what should be observable in-game?_

- [ ]
- [ ]
- [ ]

---

## Appendix: Technical Notes for Architect

_OPTIONAL. If the game-designer has specific technical insights, rule name
suggestions, or SQL patterns that might help the architect, put them here.
This section is advisory only — the architect makes all implementation
decisions. Never put implementation SQL in the main PRD body above._

### Context from Bug Report BUG-001

**Re-recruitment invariant (user-stated):** Once an NPC has been recruited as
a companion at any point, the player must ALWAYS be able to re-recruit that
NPC after death, dismissal, or any other drop-out condition. The companion is
re-recruited with their gear and level intact. There must be no level rules
around re-recruiting.

**Three known blockers to address:**
1. Level caps — Lydl the Great in East Freeport returns "too low level"
2. Cooldown timers — `data_buckets` keyed on `character_id=0`; delete by key
   pattern, not by column filter (see MEMORY.md `reference_companion_cooldown_clearing`)
3. Dismissed flag — persists incorrectly after death/dismissal

**Approach:** TDD — engineers write tests first proving the invariant, then
implement to make tests pass.

**Architect reference docs:**
- MEMORY.md: `project_companion_rerecruit_pain`
- MEMORY.md: `reference_companion_cooldown_clearing`
- `eqemu/zone/lua_companion.cpp`
- `akk-stack/server/quests/global/global_npc.lua`
- `akk-stack/server/quests/lua_modules/client_ext.lua`

---

> **Next step:** Pass this PRD to the **architect** for technical feasibility
> assessment and implementation planning.
