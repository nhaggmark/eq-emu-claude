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
- **Verdict:** APPROVED — FINAL. No revisions required.
- **Approved items:**
  - Era Compliance section (Classic-Luclin Cleric rez progression table)
  - Goals + Player Flow ("Cleric does what a Cleric does" framing)
  - NPC companions as rez targets (companion-fiction framing is sound)
  - No deity-based rez restrictions (Goal 2 + Mechanics rule #2)
  - Scenario E (Cleric down, no rezzer — graceful expected behavior)
  - Shaman HARD STOP locked in Non-Goals + Era Compliance
  - Necromancer / Druid / Paladin notes as future-scope flags
- **Issues found:** None.
- **Suggestions offered:**
  - OQ5 (Cleric OOM flavor): silent is more in keeping with EQ NPC
    terseness. Out of scope for this fix; polish pass can revisit.
  - OQ6 (quest-NPC rez): correct framing, architect-awareness flag,
    no lore dimension to it.
  - Shaman scope-creep protection note: already locked in PRD; suggest
    architect carry it through to implementation comments if
    generalizing to other healer classes.
- **Game-designer response:** OQ5 marked RESOLVED in PRD (silent only;
  removed "or chat message" hedge from Out-of-Resources Behavior).
  Status header updated to APPROVED. Ready to commit and push.

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
- **Verdict:** **APPROVED — no revisions required, PRD is clear to hand off to architecture.**
- **Summary:** The companion-rez PRD is fully lore-compliant. Cleric auto-rez is a defining Classic-launch class ability and applies to NPC companions and player targets without era, race, deity, or alignment constraints. The in-scope rez progression (Resurrection 15 / Reanimation 29 / Revive 43 / Resuscitate 53 / Restoration 65) is entirely within Classic-Luclin. The Shaman HARD STOP is locked into Non-Goals and Era Compliance; the architect should preserve that note if implementation ever generalizes to other healer classes. Out-of-mana behavior is silent (no flavor chat) — consistent with EQ NPC characterization. Quest-NPC rez interactions are architect-awareness only, not a lore concern.
- **Remaining concerns:** None at the lore layer. All open questions in the PRD are architect-domain (post-combat delay N, NPC corpse rez confirmation gap, tier preference policy, multi-target ordering, quest-NPC edge case handling, TDD test-scope mapping).

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
