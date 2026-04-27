# XP Retune — Lore Notes

> **Feature branch:** `feature/xp-retune`
> **Author:** lore-master
> **Date started:** YYYY-MM-DD

---

## Feature Concept

XP Retune adjusts the server-wide kill XP multiplier from 3.0x to 2.0x while
leaving AA XP at 3.0x. This is a numeric tuning change to rule_values only.
No NPCs, zones, items, dialogue, or world content are added or modified.

---

## Lore Research

_This feature modifies numeric game rules only. No lore research is required —
there are no NPC names, zone references, faction implications, item descriptions,
or dialogue to review for era compliance._

### Zones

| Zone | Short Name | Lore Context | Source |
|------|-----------|--------------|--------|
| N/A | | No zones affected | |

### NPCs & Characters

| NPC | Zone | Role | Faction | Lore Notes | Source |
|-----|------|------|---------|------------|--------|
| N/A | | | | No NPCs added or modified | |

### Factions

| Faction | Key NPCs | Allied With | Hostile To | Notes |
|---------|----------|-------------|------------|-------|
| N/A | | | | No faction changes | |

### Deities & Races

Not applicable. No deity or race-specific content is touched.

### Historical Context

Not applicable. This is a server tuning adjustment with no lore dimension.

---

## Era Compliance Review

| Element | Era | Compliant? | Notes |
|---------|-----|------------|-------|
| rule_values UPDATE | N/A | Yes | Pure numeric config change; no content |

**Hard stops:** None. No content is added or referenced.

---

## PRD Section Reviews

### Review: Full PRD

- **Date:** YYYY-MM-DD
- **Verdict:** APPROVED
- **Approved items:**
  - No NPC names, zone names, item names, or faction references present
  - No dialogue or lore flavor text to review
  - Era compliance: no content additions; pure rule value change
- **Issues found:** None
- **Suggestions offered:** None
- **Game-designer response:** N/A

---

## Decisions & Rationale

| # | Decision | Rationale | Alternatives Rejected |
|---|----------|-----------|----------------------|
| 1 | No lore review required | Feature touches only numeric rule values | Full lore audit (unnecessary overhead) |

---

## Final Sign-Off

- **Date:** _YYYY-MM-DD_
- **Verdict:** _APPROVED_
- **Summary:** XP Retune is a pure rule value tuning change. No lore content,
  NPC references, zone names, or dialogue are present. Era compliance is not
  at issue. Lore-master approves with no concerns.
- **Remaining concerns:** None.

---

## Context for Next Phase

No lore constraints apply. The architect may proceed without any lore-driven
restrictions on this feature.

---

## PRD Section Reviews — v2 (Companion XP Parity expanded scope)

### Review: Full PRD v2

- **Date:** 2026-04-27
- **Verdict:** APPROVED
- **Scope of v2:** v1 rule_values tune (`Character:ExpMultiplier` 3.0 → 2.0)
  PLUS a new C++ refactor scope to bring companion XP per-share into parity
  with player XP per-share, plus a forward-looking design constraint to
  leave AA-friendly seams for a future companion-AA feature (not in scope now).
- **Approved items:**
  - Companion narrative dynamic: companion system is wholly custom; no
    Classic-Luclin lore establishes a power-growth hierarchy between player
    and recruited NPC companion. XP parity is lore-neutral.
  - Era-pacing concern: none. The four locked eras (Classic, Kunark, Velious,
    Luclin) have no in-world narrative about companion advancement rates.
    This is a server mechanical concern, not a fiction surface.
  - Quest-flavored interactions: no existing quest scripts reference
    companion XP accumulation or level progression as a narrative beat.
    Companion level appears in mechanics (follow, guarding) but not in
    lore dialogue or quest conditions that would conflict with parity.
  - No NPC, zone, item, faction, or deity references introduced.
  - No quest dialogue or in-world fiction added or modified.
- **Issues found:** None
- **Suggestions offered:** None
- **Game-designer response:** N/A

**Note on logging:** Lore-master had no Write tool in this session and
asked game-designer to record this v2 sign-off on their behalf. Entry
captured here per lore-master's verbatim review.

---

## Final Sign-Off — v2

- **Date:** 2026-04-27
- **Verdict:** APPROVED (covers v1 rule tune + v2 companion XP parity + AA seams constraint)
- **Summary:** XP Retune v2 adds a C++ refactor of the companion XP
  distribution path to achieve per-share parity with the player, plus a
  forward-looking constraint to leave AA-friendly seams. Both scope
  components are lore-neutral — no narrative surface, no era-pacing
  concern, no quest content affected. Lore-master approves with no
  concerns.
- **Remaining concerns:** None.
