# Companion Re-recruitment Fix — Status Tracker

> **Feature branch:** `bugfix/companion-rerecruit`
> **Created:** 2026-04-27
> **Last updated:** 2026-04-27

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-04-27 | 2026-04-27 |
| Design | game-designer + lore-master | Complete | 2026-04-27 | 2026-04-27 |
| Architecture | architect + protocol-agent + config-expert | Not Started | | |
| Implementation | _implementation team_ | Not Started | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Architecture (handoff complete)

---

## Handoff Log

_Record each handoff between agents with context and any notes._

### bootstrap-agent → design team (game-designer + lore-master)
- **Date:** 2026-04-27
- **Notes:** Workspace created. PRD template ready at `game-designer/prd.md`.
  Bug report BUG-001 seeded at `bugs/BUG-001-rerecruit-level-cap/report.md`.
  Spawn both agents as teammates for the Design phase.

### design team (game-designer + lore-master) → architect
- **Date:** 2026-04-27
- **Notes:** PRD finalized at `game-designer/prd.md` (status: APPROVED).
  Locks the re-recruitment invariant: any previously-recruited NPC is
  re-recruitable indefinitely, with level and gear preserved, no level
  rules, no cooldown, no dismissed-flag persistence. All three known
  blockers (level cap, cooldown, dismissed flag) in scope as a single
  coordinated fix.
  - **TDD as design constraint:** engineers write failing tests first;
    test suite ships in repo as machine-verified evidence.
  - **10 acceptance criteria** + **10 validation scenarios**, split
    between engineer-side (1,2,5,8,9,10) and game-tester in-game
    (3,4,6,7).
  - **Lore-master sign-off:** APPROVED 2026-04-27. No lore blockers.
    Two flavor-level edge cases folded into PRD: static-respawn
    fiction note (Era Compliance), quest-NPC interaction (Open
    Question #1 and new AC-10 covering Lydl Mastat-style cases).
    "Cyrla the Healer" renamed to "Mira the Healer" in Scenario B to
    avoid collision with real EQ NPC Cyrla Shadowstepper.
  - **Open questions for architect:** first-recruit cooldown semantics
    (preserve or remove?); in-memory cache flushing on bypass vs.
    delete; "other drop-out conditions" enumeration (zone disconnect,
    server restart, group disband); quest-state interaction on
    re-recruit of quest-target NPCs.
  - **Reference docs:** `eqemu/zone/lua_companion.cpp`,
    `akk-stack/server/quests/global/global_npc.lua`,
    `akk-stack/server/quests/lua_modules/client_ext.lua`,
    MEMORY entries `project_companion_rerecruit_pain` and
    `reference_companion_cooldown_clearing` (both 44 days old —
    architect to verify against current code).
  - **Lore-master transcription note:** lore-master lacked Write
    tooling this session; their findings transcribed verbatim into
    `lore-master/lore-notes.md` and SendMessage exchanges preserved
    in `agent-conversations.md` as the canonical audit trail.

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
| 1 | First-recruit cooldown semantics — preserve cooldown for first-recruits (anti-thrash) or remove entirely if it only ever served as a re-recruit gate? | game-designer | architect | Open | |
| 2 | In-memory cache flushing — if cooldown is bypassed at validation layer, cache staleness is irrelevant; if deleted at DB layer, cache invalidation must be considered | game-designer | architect | Open | |
| 3 | "Other drop-out conditions" enumeration — verify zone disconnect, server restart, group disband, etc., are all covered by the invariant | game-designer | architect | Open | |
| 4 | Quest-state interaction on re-recruit of quest-target NPCs (e.g., Lydl Mastat) — does re-recruit logic need to consider active-quest state? Invariant still holds; this is about quest-state cleanliness, not gating | lore-master | architect | Open | |

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
| BUG-001 | Re-recruitment blocked by level cap (and possibly cooldowns + dismissed flag) | High | user | Open | TBD | |

---

## Decision Log

_Key decisions made during this feature's development._

| # | Decision | Made By | Date | Rationale |
|---|----------|---------|------|-----------|
| 1 | Fix all three known blockers (level caps, cooldown timers, dismissed flag) as one coordinated change | user | 2026-04-27 | The re-recruitment invariant must hold completely; partial fixes leave the system broken |
| 2 | TDD approach: engineers write tests first proving the invariant, then implement to make tests pass | user | 2026-04-27 | Ensures invariant is machine-verified, not just manually tested |
| 3 | Lore review APPROVED — no blockers; two flavor edge cases (static-respawn fiction, quest-NPC interaction) folded into PRD as architect-awareness notes, not scope changes | game-designer + lore-master | 2026-04-27 | Companion system is a custom feature with no in-world fiction; invariant is purely mechanical |
| 4 | Rename "Cyrla the Healer" → "Mira the Healer" in Scenario B | game-designer + lore-master | 2026-04-27 | Cyrla collides with real EQ NPC Cyrla Shadowstepper (level 61 Rogue, Highpass Hold). Generic invented name avoids noise for downstream readers |
| 5 | Added AC-10: re-recruit of an NPC who is also a quest kill target (e.g., Lydl Mastat) still succeeds per the invariant; architect evaluates whether quest state needs special handling | game-designer + lore-master | 2026-04-27 | Lore-master flagged Lydl Mastat quest as an example of the broader edge case; invariant must hold regardless |

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

### Re-recruitment Invariant (stated by user)

Once an NPC has been recruited as a companion at any point, the player must
ALWAYS be able to re-recruit that NPC after death, dismissal, or any other
drop-out condition. The companion is re-recruited with their gear and level
intact. There must be no level rules around re-recruiting. The whole point of
the companion system is that a player can recruit an NPC at level 5 and take
them through the entire game.

### Known Blockers (from MEMORY.md)

1. **Level caps** — today's reported blocker (Lydl the Great "too low level")
2. **Cooldown timers** — `data_buckets` companion cooldowns keyed on
   `character_id=0`; must be deleted by key pattern, not column filter
3. **Dismissed flag** — persists incorrectly after death/dismissal

### Reference Docs

- MEMORY.md entries: `project_companion_rerecruit_pain`, `reference_companion_cooldown_clearing`
- Companion Lua binding: `eqemu/zone/lua_companion.cpp`
- LLM bridge: `akk-stack/server/quests/lua_modules/llm_bridge.lua`
- Client extensions: `akk-stack/server/quests/lua_modules/client_ext.lua`
- Global NPC handler: `akk-stack/server/quests/global/global_npc.lua`
