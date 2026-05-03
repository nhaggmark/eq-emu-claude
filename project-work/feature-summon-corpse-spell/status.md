# Universal Summon Corpse Spell — Status Tracker

> **Feature branch:** `feature/summon-corpse-spell`
> **Created:** 2026-05-03
> **Last updated:** 2026-05-03 (design phase complete)

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-05-03 | 2026-05-03 |
| Design | game-designer + lore-master | Complete | 2026-05-03 | 2026-05-03 |
| Architecture | architect + protocol-agent + config-expert | Not Started | | |
| Implementation | _implementation team_ | Not Started | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Architecture

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-05-03
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  Feature brief at `brief.md`. Spawn both agents as teammates for the Design phase.

### design team (game-designer + lore-master) → architect (architecture team)
- **Date:** 2026-05-03
- **PRD:** `game-designer/prd.md` — fully filled out, all template sections
  populated. Status: Approved.
- **Lore review:** `lore-master/lore-notes.md` — lore-master's full review
  persisted verbatim. All 6 BLOCKING name issues addressed exactly as
  recommended. Universal in-world framing chosen: Option A "The Compact
  of the Awakened" (Luclin Nexus-grounded). Final lore-master full-pass
  sign-off requested but not blocking handoff.
- **Scope summary:** Free, level-1, class-flavored Summon Corpse spell
  scribed by all 12 casting-capable classes (CLR, DRU, SHM, NEC, WIZ,
  MAG, ENC, PAL, SHD, RNG, BST, BRD). 0 mana, 6s cast, 3-min cooldown.
  Self-target, same-zone-only, summons caster's own corpse. Vendor
  acquisition for new chars; auto-scribe migration for existing.
  Mechanically identical to existing Necromancer/Shaman summon-corpse —
  just universalized.
- **Open questions for the architect** (full list in PRD §Open Questions):
  cooldown enforcement on no-corpse cast; multi-corpse selection order;
  Bard scribed-spell routing (gem-window vs. song-window); auto-scribe
  migration sequencing; vendor-NPC placement strategy; animation/icon
  reuse-vs-bespoke decisions.
- **Affected systems:** C++ server source, MariaDB (`spells_new`,
  `items`, `merchantlist`, `character_spells` migration), rule-values.
  No Lua, no Perl, no Docker, no config-file changes expected.
- **Lore sign-off status:** APPROVED-IN-SUBSTANCE. All blocking concerns
  resolved; final pro-forma sign-off pass requested. See
  `agent-conversations.md` Unresolved Threads.

---

## Implementation Tasks

_Populated by the architect after the architecture doc is approved._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| | | | | |

---

## Open Questions

_Questions that need answers before work can proceed. Tag the agent or
person responsible for answering._

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| | | | | | |

---

## Blockers

_Anything preventing progress. Remove when resolved._

| Blocker | Raised By | Date | Resolved |
|---------|-----------|------|----------|
| | | | |

---

## Bug Reports

_Bugs discovered during testing or play. Status flow:
Open → Investigating → Fix In Progress → Resolved._

| # | Bug | Severity | Reported By | Status | Assigned To | Resolved |
|---|-----|----------|-------------|--------|-------------|----------|
| | | | | | | |

---

## Decision Log

_Key decisions made during this feature's development._

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| | | | | |

---

## Completion Checklist

### Implementation Complete (agents can check these)

_Filled in after game-tester validation passes._

- [ ] All implementation tasks marked Complete
- [ ] No open Blockers
- [ ] game-tester server-side validation: PASS
- [ ] User completed in-game testing guide: PASS
- [ ] All changes committed and pushed to feature branch in ALL repos
- [ ] Server rebuilt (if C++ changed)
- [ ] All phases marked Complete in Workflow Status table

### Merge & Cleanup (USER-INITIATED ONLY)

_These items happen ONLY when the user explicitly confirms the feature is done.
The orchestrator NEVER initiates merge or branch cleanup on its own._

- [ ] User confirmed feature is complete
- [ ] Feature branch merged to main in ALL affected repos
- [ ] Main pushed to origin in ALL affected repos
- [ ] Stale feature branches deleted (local + remote)

**Merged by:** _name_
**Merge date:** _YYYY-MM-DD_

---

## Notes

_Free-form notes, observations, or context that doesn't fit above._
