# BUG-001: Rez'd NPC companion vanishes from group a few minutes after rez

> **Severity:** High
> **Reported by:** User (player)
> **Date:** 2026-05-05
> **Feature:** bugfix-companion-rez-vanish
> **Status:** Open

---

## Observed Behavior

Player was in a group fighting a battle. The NPC companion Wizard died during
the fight. After the fight ended, the NPC companion Cleric successfully cast
Resurrection on the dead Wizard. The Wizard companion came back and rejoined
the group for a few minutes. Then the Wizard companion **vanished entirely**
from the team. Player had to manually go and re-recruit the Wizard.

The user could not determine whether the vanish was time-triggered or
zone-triggered — they did not note exactly when it happened relative to time
elapsed or zone transitions.

## Expected Behavior

A successfully rez'd NPC companion should remain in the player's group
permanently, the same as a companion who never died. The rez should fully
restore the companion's status — including any death-timer / corpse-reaper /
despawn-clock state that would normally cause an unrezzed dead companion to be
cleaned up.

## Reproduction Steps

1. Player in a group with at least one NPC companion Wizard and one NPC companion Cleric
2. Engage in combat sufficient to kill the Wizard companion
3. End combat with Cleric companion still alive
4. Have Cleric companion cast Resurrection on the dead Wizard companion's corpse
5. Wizard accepts the rez and rejoins the group
6. Continue playing for at least a few minutes (and possibly zone)
7. Observe: Wizard companion vanishes from the group entirely

## Evidence

_No logs or screenshots captured at time of report. Tester should capture
zone logs and zone server logs during repro._

## Affected Systems

_Check all that apply. These determine which expert agents are assigned
during triage._

- [ ] C++ server source → c-expert
- [ ] Lua quest scripts → lua-expert
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [ ] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert

_Note: Architect should determine affected systems during triage._

---

## User's Hypothesis (not yet confirmed)

The user guesses there may be a death timer or despawn clock on the dead
companion that isn't being cleared when the rez succeeds, so the companion's
underlying entity ticks forward and despawns at the originally-scheduled time
even after the rez. **This is a hypothesis — architect should triage and
confirm or refute.**

---

## Context for Architect

This server has had previous companion-rez work. Recent merged bugfixes include:
- BUG-002 / bugfix/companion-rez (heartbeat hoist above early-returns)
- bugfix/companion-rerecruit (re-recruit invariant fix V1+V2)

The architect should review those recent fixes when triaging -- this new bug
may be in territory adjacent to those fixes, possibly an incomplete fix or a
different code path that wasn't covered.

---

## Open Questions for the Architect

1. Is there a death-timer or despawn-clock that survives across rez? (User's hypothesis -- start here)
2. Is the rez code path actually clearing the companion's "dead" state correctly? (heartbeat, dismissed flag, follow state, group membership)
3. Does the bug repro across zones, or only in the same zone? (User couldn't confirm -- repro testing should cover both)
4. Is this a regression from a recent change, or has it always been broken?

---

## Fix Notes

_Populated by the implementing agent._

## Validation Notes

_Populated by game-tester after fix is implemented._
