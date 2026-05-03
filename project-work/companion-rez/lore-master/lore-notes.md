# Companion Rez — Lore Notes

> **Feature branch:** `bugfix/companion-rez`
> **Author:** lore-master (transcribed by game-designer per request — lore-master lacks Write tool)
> **Date started:** 2026-04-27

---

## Feature Concept

Bugfix for BUG-001: a Cleric NPC companion automatically resurrects downed
party members (player + recruited NPC companions) after combat ends. Today
the Cleric attempts the cast but the rez does not "take" on NPC companion
targets — corpses stay down. The fix restores broken behavior; it does not
introduce new game systems or narrative content.

Era lock: Classic, Kunark, Velious, Luclin.

---

## Lore Research

### Cleric Class Identity (Classic Lore)

Resurrection is a defining Classic-launch Cleric ability. Every Cleric in
Norrath — regardless of race (Human, Erudite, Dwarf, Half Elf, High Elf,
Gnome, Troll, Ogre, Iksar) or deity affiliation — has rez as a core class
identity. There is no lore or faction constraint that would prevent a
Cleric companion from performing rez on fallen party members. Auto-rezzing
post-combat is fully consistent with the world.

### Resurrection Spells in Era

| Spell | Class | Level | Era | Notes |
|-------|-------|-------|-----|-------|
| Resurrection | Cleric | 15 | Classic | Base-tier Cleric rez |
| Reanimation | Cleric | 29 | Classic | Mid-tier |
| Revive | Cleric | 43 | Classic | Higher-tier |
| Resuscitate | Cleric | 53 | Classic | High-tier |
| Restoration | Cleric | 65 | Luclin | Top-tier in era — within era lock |
| Reincarnation | Druid | 52 | Classic | OK if future scope expands to Druids |
| Revive | Paladin | 44 | Kunark | OK if future scope expands to Paladins |

### Race & Deity

- No deity-based rez restrictions in Classic mechanics. An Erudite Cleric of
  Quellious can rez a Troll. A Troll Cleric of Cazic-Thule can rez a High
  Elf. Auto-rez does NOT need deity / alignment gating.
- No racial restrictions on rez targets.

### Historical Context

Classic-launch design treats rez as a pure class utility, not a narrative
event. Post-combat rez was the standard small-group play loop in 1999–2002
EQ. The fix restores that loop.

---

## Era Compliance Review

| Element | Era | Compliant? | Notes |
|---------|-----|------------|-------|
| Cleric Resurrection (lvl 15) | Classic | Yes | |
| Cleric Reanimation (lvl 29) | Classic | Yes | |
| Cleric Revive (lvl 43) | Classic | Yes | |
| Cleric Resuscitate (lvl 53) | Classic | Yes | |
| Cleric Restoration (lvl 65) | Luclin | Yes | Within era lock |
| Druid Reincarnation (lvl 52) | Classic | Yes (out of current scope) | If future scope expands |
| Paladin Revive (lvl 44) | Kunark | Yes (out of current scope) | If future scope expands |
| Shaman rez | n/a | **NO — HARD STOP** | Shamans have NO rez in Classic–Luclin |
| Necromancer Resurrection | Classic | Conditional | Yields shard / damaged corpse w/ XP penalty — different mechanic |

**Hard stops:**
- **Shaman rez is a HARD STOP.** Shamans do NOT receive any resurrection
  spell in Classic through Luclin. Any future expansion of auto-rez to
  Shaman companions must be blocked. If the PRD or any implementation ever
  references Shaman rez, reject as an era violation.

**Conditional flags:**
- **Necromancer rez** is in-era but mechanically and narratively distinct:
  it produces a damaged-corpse rez with experience penalty, not a clean
  Cleric-style raise. If Necromancer companions are ever given rez
  behavior in a future scope expansion, the implementation must reflect
  that distinction (inferior, dark-flavored). Not a current concern; this
  PRD scopes Cleric only.

---

## PRD Section Reviews

### Review: Early Lore Consult (pre-draft)

- **Date:** 2026-04-27
- **Verdict:** APPROVED
- **Approved items:**
  - Cleric companions auto-rezzing is fully era-compliant
  - NPC companions as valid rez targets is thematically clean (companion
    fiction supports "they're party members and have souls")
  - No deity/alignment/race gating on rez targets — held the line correctly
- **Issues found:**
  - None
- **Suggestions offered:**
  - Flag Shaman rez as a HARD STOP for any future scope expansion
  - Note Necromancer rez as conditional (in-era but mechanically distinct)
  - Note Druid (Reincarnation) and Paladin (Revive) as in-era options if
    scope ever expands
- **Game-designer response:** Folded all lore findings into PRD Era
  Compliance section. Added Shaman HARD STOP note in Non-Goals + Era
  Compliance. Added Necromancer / Druid / Paladin notes as future-scope
  flags.

### Review: Full PRD Draft (final sign-off)

- **Date:** 2026-04-27
- **Verdict:** APPROVED
- **Approved items:** Era compliance table; no deity/race/alignment
  gating; Shaman HARD STOP; Necromancer conditional; NPC companions as
  valid rez targets; OQ5 resolved as silent; OQ6 framing as
  architect-awareness only.
- **Issues found:** None.
- **Suggestions offered:** None — all lore guidance from early consult
  was already folded in correctly.
- **Game-designer response:** OQ5 marked RESOLVED in PRD (silent only;
  removed "or chat message" hedge from Out-of-Resources Behavior).
  Status header updated to APPROVED. Committed and pushed to
  `bugfix/companion-rez` (claude repo).

---

## Decisions & Rationale

| # | Decision | Rationale | Alternatives Rejected |
|---|----------|-----------|----------------------|
| 1 | No deity-based restrictions on Cleric rez targets | Not enforced in Classic mechanics; would create UX pain on a 1-3 player server | "Erudite Cleric of Quellious refuses to rez Trolls" — rejected: Classic doesn't gate rez on deity/alignment |
| 2 | Default to silent on Cleric out-of-mana state | Avoids chat spam; chatty Cleric AI breaks immersion | "Cleric says 'I must rest before I can raise the dead, friend.' on OOM" — left as Open Question for final lore-master verdict |
| 3 | Shaman rez is a permanent HARD STOP for any future expansion | Shamans have no rez spell in Classic–Luclin; would be an era violation | None — era lock is non-negotiable |
| 4 | Necromancer rez flagged as conditional, NOT included in this fix's scope | Necro rez is in-era but mechanically distinct (shard / damaged corpse / XP penalty); current fix is Cleric-only | "Generalize auto-rez to all in-era rezzers" — rejected: Cleric is the user's invariant; other classes are future scope |

---

## Final Sign-Off

- **Date:** 2026-04-27
- **Verdict:** APPROVED
- **Summary:** PRD is lore-clean. Cleric auto-rez is canonical Classic
  behavior with no era, faction, deity, or NPC characterization
  conflicts. Spell roster confirmed within Classic–Luclin lock. NPC
  companions as rez targets is consistent with companion system
  fiction. No narrative content introduced by this fix. Shaman HARD
  STOP and Necromancer conditional documented for downstream teams.
- **Remaining concerns:** None for this scope. Shaman rez era violation
  documented as a downstream guard for any future healer-class
  expansion.

---

## Context for Next Phase

For the architect and downstream implementation team:

- **Cleric class identity is the lore anchor.** Auto-rez is what Clerics
  do — there's no special characterization to preserve here, just the
  basic mechanic working right.
- **Era-spell list is the in-scope tier set:** Resurrection (15),
  Reanimation (29), Revive (43), Resuscitate (53), Restoration (65). All
  within Classic–Luclin lock.
- **HARD STOP for any future expansion:** Shaman rez. Reject any
  implementation note, comment, or follow-up feature that mentions
  Shaman rez.
- **CONDITIONAL for any future expansion:** Necromancer rez has
  in-era support but mechanically distinct semantics (damaged corpse /
  XP penalty). Out of current scope; flagged for future awareness.
- **NO deity / race / alignment gating on rez targets.** Architect should
  not introduce any such checks during implementation. If a check exists
  in the current code path that would block a Cleric of Deity X from
  rezzing a Race Y companion, it must be removed (or scoped only to
  initial-spell-cast targeting if that's a separate mechanic — but never
  to gate the rez itself).
- **Quest-NPC rez interactions** (rezzing an NPC who is also a kill
  target / dialogue node in an active quest) are a mechanical edge case,
  not a lore one. Handle as the architect sees fit; lore does not
  constrain the choice.
