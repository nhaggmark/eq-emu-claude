# Lore Notes — Companion Re-recruitment Fix

> **Feature branch:** `bugfix/companion-rerecruit`
> **Author:** lore-master (transcribed by game-designer at lore-master's
>   explicit request — lore-master lacked Write tooling in this session)
> **Date:** 2026-04-27
> **Status:** APPROVED — no lore blockers; two flavor-level edge cases noted

---

## Sign-off Summary

**APPROVED — no lore blockers.** The companion re-recruitment fix is
mechanical server behavior with no narrative impact. Cleared to proceed
to architecture and implementation.

Two flavor-level edge cases were flagged for awareness (NOT scope
expansions). Both have been folded into the PRD; neither requires a
design change.

---

## Notes by Topic

### Lydl the Great (East Freeport) — repro NPC

- Level 4 human wizard. Wandering "insane" figure who roams North Ro /
  East Freeport.
- Lore-flavor: Innoruuk-corrupted ("Death to you all! Swords cannot harm
  a mighty follower of Innoruuk!").
- No stable city role, no home faction, no quest-giver function. Framed
  as a hostile target.
- Faction hits: killing him *helps* Knights of Truth and *hurts* Dismal
  Rage and Opal Dark Briar.
- **Edge case:** Lydl is himself a kill target in the Lydl Mastat
  Freeport wizard-guild quest. Re-recruitment of a kill-target NPC may
  interact oddly with quest state — flagged for architect, not a lore
  constraint.
- The companion system has never filtered by deity affiliation; no
  reason to start here. Cleared as repro NPC.

### "Once recruited, always re-recruitable" at Norrath scale

No era compliance issues. NPC level is a game abstraction, not a
Norrath narrative element. Death and resurrection mechanics for NPCs
were never canonized in EQ fiction. The companion system is a custom
server feature with no in-world fiction; the invariant is clean.

### Era Compliance

The invariant "once recruited, always re-recruitable, with gear and
level preserved" is purely mechanical. Nothing in
Classic / Kunark / Velious / Luclin lore constrains companion level
advancement or re-recruitment. Level rules, cooldowns, and dismissed
flags are tuning knobs, not lore constructs.

### Quest Interactions

Apart from the Lydl Mastat case noted above, no recruitable NPC has a
quest where their level carries narrative meaning that would be
disrupted by the proposed fix.

---

## Edge Cases Documented in PRD

These were folded into the PRD's Open Questions and Era Compliance
sections per lore-master's recommendation. Neither is a lore blocker.

1. **Guards / merchants / quest-givers vanishing from their post.**
   Same fiction break vanilla EQ already has via static respawn. The
   re-recruitment mechanic does not attempt to explain an NPC's absence
   from their post; this is consistent with Norrath's static-respawn
   fiction. Noted in PRD's Era Compliance section.

2. **Quest-chain NPCs mid-quest.** A recruitable NPC who is also a
   kill target or dialogue node in an active quest may produce awkward
   quest-state interactions on re-recruit. Architect should evaluate
   whether re-recruit logic needs to consider active-quest state. The
   invariant still holds — this is a mechanical edge case, not a lore
   constraint. Noted in PRD's Open Question #1; covered by new
   acceptance criterion AC-10.

---

## Constraints to Carry Forward

None. PRD may proceed to architecture. No lore constraints to carry
forward.

---

**Transcription note:** This file was transcribed verbatim from
lore-master's SendMessage responses by the game-designer at
lore-master's explicit request (lore-master lacks Write tooling in this
session). Original SendMessage exchanges are preserved in
`claude/project-work/companion-rerecruit/agent-conversations.md` as the
canonical audit trail. Final formal sign-off block will be appended
after lore-master reviews the full PRD draft.

---

## Final Sign-Off

**Date:** 2026-04-27
**Verdict:** APPROVED WITH MINOR NOTE
**Reviewer:** lore-master

### Final Lore Assessment

- **Lydl the Great (Scenario A):** APPROVED — confirmed level 4 human
  wizard, East Freeport, no stable world role, no lore conflict with
  re-recruitment.
- **Cyrla the Healer (Scenario B):** APPROVED mechanically; NAME FLAG.
  "Cyrla" collides with Cyrla Shadowstepper — a real EQ NPC, level 61
  Rogue guild master in Highpass Hold (emphatically not a healer).
  Recommended rename to a fully generic invented name (e.g., "Mira the
  Healer") to avoid confusion for the architect / implementation team.
  Not a sign-off condition — game-designer's call.
- **Sebilis (Scenario C):** APPROVED — Kunark-era zone, neutral dungeon
  target for any race/alignment, no lore conflict.
- **Era Compliance section:** APPROVED as written. Nothing post-Luclin.
  Recruitable NPC roster unchanged.
- **Open Question on lore touchpoint:** Addressed in full in prior
  exchanges; no blockers, two edge cases documented for architect
  (static-respawn fiction note in Era Compliance; quest-NPC edge case
  in Open Question #1 and AC-10).

**Final verdict: APPROVED.** PRD may proceed to commit.

### Game-Designer Action on Rename Recommendation

Applied. "Cyrla the Healer" was renamed to "Mira the Healer" in
Scenario B per lore-master's recommendation. Zero-cost change; removes
collision noise for downstream readers.
