# Universal Summon Corpse Spell — Status Tracker

> **Feature branch:** `feature/summon-corpse-spell`
> **Created:** 2026-05-03
> **Last updated:** 2026-05-03 (architecture phase complete; spell-ID precondition flagged)

---

## Workflow Status

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| Bootstrap | bootstrap-agent | Complete | 2026-05-03 | 2026-05-03 |
| Design | game-designer + lore-master | Complete | 2026-05-03 | 2026-05-03 |
| Architecture | architect + protocol-agent + config-expert | Complete | 2026-05-03 | 2026-05-03 |
| Implementation | c-expert + data-expert + config-expert + infra-expert | Not Started | | |
| Validation | game-tester | Not Started | | |
| Completion | _user_ | Not Started | | |

**Current phase:** Implementation (ready to start once team is spawned; data-expert task 0 is the critical precondition)

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
  persisted verbatim. All 6 BLOCKING name issues addressed.
- **Lore sign-off status:** APPROVED (formal). Lore-master replied
  "PRD is clear for architecture" on 2026-05-03.

### architect (architecture team) → implementation team (c-expert + data-expert + config-expert + infra-expert)
- **Date:** 2026-05-03
- **Architecture doc:** `architect/architecture.md` (459 lines, all template sections filled).
- **Source-spike reference:** `architect/context/source-spike-findings.md` (cites every source file:line touched during research, with file-touch summary table for implementation experts and a post-consultation update section reflecting protocol-agent + config-expert findings).
- **All 7 PRD open questions resolved:**
  1. Cooldown enforcement on no-corpse cast → DECOUPLED. Engine CAN decouple via per-Mob bool flag in SummonCorpse case + check before timer.Start in spells.cpp:2839. ~10 lines across 3 files.
  2. Multi-corpse selection order → engine returns OLDEST corpse first (`GetCorpseByOwner` walks `corpse_list` keyed by entity ID). Documented in release-notes guidance; YAGNI-rejected adding "most recent" overload.
  3. Bard scribed-spell routing → standard spell-gem path. Set `buff_duration = 0xFFFF` defensively on all 12 spells. Protocol-agent confirmed this fully bypasses bard_song_mode and produces identical wire behavior to non-Bard casts.
  4. Auto-scribe migration sequencing → single transaction: spells_new → items → merchantlist → character_spells INSERT...SELECT. Idempotent via `NOT EXISTS` guards. Slot pick uses `MIN(MAX(slot_id) + 1, 399)` per character (guards against Titanium SPELLBOOK_SIZE=400 cap).
  5. Vendor placement → resolved by lore-master in design phase (standard class spell vendor in each starting city, no faction gating).
  6. Animation / icon reuse vs bespoke → reuse from existing Necromancer summon-corpse row's `new_icon` and `casting_animation` for all 12.
  7. Rule key validation → no collision (only `Bots:AllowCommandedSummonCorpse` exists). Rule pattern: `RULE_INT(Spells, UniversalSummonCorpseCooldown, 180, "...")` in `ruletypes.h:425+`. Plus `rule_values` seed row in `ruleset_id=1`. Engine reads dynamically at cast time; `#reloadrules` sufficient to retune. **Discriminator key: `spells_new.spell_category`** (per config-expert; avoids leaking into existing NEC/SHM summon-corpse spells).
- **CRITICAL PRECONDITION FLAGGED:** Titanium `SPELL_ID_MAX = 9999` (titanium_limits.h:329). Only 3 unused IDs in [1, 9999] (1348, 5093, 9412). Need 12. Data-expert task 0 reclaims 9+ unused sub-9999 spell rows. This is the gating dependency for all content tasks.
- **Implementation team composition:** c-expert + data-expert + config-expert + infra-expert. NOT spawning lua-expert, perl-expert, or protocol-agent (no implementation-phase work for them).

---

## Implementation Tasks

_Populated by the architect after the architecture doc is approved._

| # | Task | Agent | Status | Notes |
|---|------|-------|--------|-------|
| 0 | **PRECONDITION:** Reclaim 9+ unused sub-9999 spell IDs in `spells_new`. Audit query covers character_spells + all 6 item effect columns + npc_spells_entries + aa_rank_effects + manual quest-script grep. Backup deletes to `claude/tmp/feature-summon-corpse-spell/reclaimed-spells-backup.sql`. Final list of 12 IDs (3 known gaps + 9+ reclaimed) documented in data-expert dev-notes. | data-expert | Not Started | Critical — gates all content tasks |
| 1 | Add `RULE_INT(Spells, UniversalSummonCorpseCooldown, 180, ...)` to `ruletypes.h` before `RULE_CATEGORY_END()` at line 549; clean build | config-expert | Not Started | 1 line + build cycle |
| 2 | Identify existing Necromancer summon-corpse row in `spells_new` for icon/animation/descnum clone-mutate values; assign new unique `spell_category` value for the 12 new spells; share constant with c-expert | data-expert | Not Started | Depends on task 0 |
| 3 | Author 12 INSERT statements for new spells in `spells_new` (using IDs from task 0, cloned cosmetic fields from task 2, and the new spell_category) | data-expert | Not Started | Depends on task 2 |
| 4 | Add `m_summon_corpse_was_noop` flag (`mob.h`); set in SummonCorpse no-corpse branch (`spell_effects.cpp:1851`); read in recast block (`spells.cpp:2817-2841`) gated on `spell_category == kUniversalSummonCorpseCategory`; add `RuleI(Spells, UniversalSummonCorpseCooldown)` override in same block | c-expert | Not Started | Depends on tasks 1, 2; ~15 lines across 3 files |
| 5 | Author 12 INSERT statements for scroll items in `items` | data-expert | Not Started | Depends on task 3 |
| 6 | Enumerate starting-city class spell vendor merchant_ids; author merchantlist INSERTs | data-expert | Not Started | Depends on task 5; ~30-50 rows |
| 7 | Author idempotent character_spells auto-scribe migration (12 INSERT...SELECT blocks with `MIN(MAX(slot_id)+1, 399)` cap) | data-expert | Not Started | Depends on task 3 |
| 8 | Author rule_values seed row for `Spells:UniversalSummonCorpseCooldown` (ruleset_id=1) | config-expert | Not Started | Depends on task 1 |
| 9 | Bundle SQL into single transactional migration; test idempotency on snapshot | data-expert | Not Started | Depends on tasks 3, 5, 6, 7, 8 |
| 10 | Rebuild zone/world; restart full stack per MEMORY.md startup order; apply migration | infra-expert | Not Started | Depends on tasks 4, 9 |
| 11 | Hand off to game-tester for validation | (orchestrator) | Not Started | Depends on task 10 |

---

## Open Questions

_Questions that need answers before work can proceed. Tag the agent or
person responsible for answering._

| # | Question | Raised By | Assigned To | Status | Answer |
|---|----------|-----------|-------------|--------|--------|
| _none open_ | | | | | All 7 PRD open questions resolved during design + architecture phases (see Handoff Log above) |

---

## Blockers

_Anything preventing progress. Remove when resolved._

| Blocker | Raised By | Date | Resolved |
|---------|-----------|------|----------|
| _none open_ | | | Spell ID headroom is now task 0 (a precondition, not a blocker) |

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
| 1 | Reuse existing SE_SummonCorpse SPA (effect ID 91) — no new effect handler | architect | 2026-05-03 | The handler is NOT class-gated; works for any client caster. Reusing eliminates a class of regression risk and matches PRD reuse directive. |
| 2 | Decouple no-op self-cast from cooldown via transient bool flag | architect | 2026-05-03 | Engine cast pipeline orders SpellEffect BEFORE the recast timer set, so a flag-set inside the SummonCorpse case can be read in the recast block. ~10 lines across 3 files. |
| 3 | Set buff_duration=0xFFFF defensively on all 12 spells | architect (protocol-agent confirmed) | 2026-05-03 | Engine has explicit short-circuit at spells.cpp:1475. Protocol-agent confirmed this fully bypasses bard_song_mode (not just the pulsing subpath). |
| 4 | Multi-corpse selection: accept oldest-first engine default | architect | 2026-05-03 | YAGNI on adding `GetMostRecentCorpseByOwner`. PRD calls "most recent" a preference, not a requirement. |
| 5 | New rule `Spells:UniversalSummonCorpseCooldown` (default 180s) consulted at cast time | architect | 2026-05-03 | Operator hot-tuning UX worth the ~3-line conditional. |
| 6 | Rule discriminator: `spells_new.spell_category` (NOT spell-ID range, NOT `IsEffectInSpell(SE_SummonCorpse)`) | architect (config-expert recommendation) | 2026-05-03 | Cleaner than spell-ID range (survives ID shuffles); avoids leaking rule into existing NEC/SHM summon-corpse spells. |
| 7 | target_type = ST_Self enforced (not ST_TargetOptional like high-level NEC/SHM) | architect | 2026-05-03 | PRD requires self-only. Engine's `SingleTarget` case at spells.cpp:1910 forces spell_target=this for ST_Self. |
| 8 | Reuse new_icon and casting_animation from existing Necromancer summon-corpse row | architect | 2026-05-03 | Per PRD recommendation; avoids art-pipeline scope creep. |
| 9 | Implementation team = c-expert + data-expert + config-expert + infra-expert | architect | 2026-05-03 | No quest scripts, no protocol-phase implementation; lean team minimizes token use. |
| 10 | timer_id = 0 for all 12 new spells (no shared linked timer) | architect (config-expert finding) | 2026-05-03 | EndurTimerIndex slots 1-19 are all occupied; not a problem because each spell is class-restricted. |
| 11 | Spell ID reclamation (data-expert task 0) is critical precondition | architect (protocol-agent finding) | 2026-05-03 | Titanium SPELL_ID_MAX = 9999, only 3 gaps available, need 12. Reclaim via audit query covering all known reference sites; backup-before-delete. |
| 12 | Migration auto-scribe slot-pick capped at 399 via `MIN(MAX(slot_id)+1, 399)` | architect (protocol-agent finding) | 2026-05-03 | Defensive cap against Titanium SPELLBOOK_SIZE=400. In practice no character on this server is anywhere near 400, but cheap to guard. |

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

_These items happen ONLY when the user explicitly confirms the feature is done._

- [ ] User confirmed feature is complete
- [ ] Feature branch merged to main in ALL affected repos
- [ ] Main pushed to origin in ALL affected repos
- [ ] Stale feature branches deleted (local + remote)

**Merged by:** _name_
**Merge date:** _YYYY-MM-DD_

---

## Notes

**Architecture-phase summary:**
- 1 architect + 1 protocol-agent (research-only, dev-notes 242 lines, 5 questions answered) + 1 config-expert (research + planning, dev-notes ~190 lines, both architect questions answered).
- 12+ source files investigated under `eqemu/zone/`, `eqemu/common/`, and `eqemu/common/patches/`.
- 0 source files modified (architecture is research + planning only).
- 1 architecture doc (459 lines) + 1 source-spike reference (>180 lines) + this status.md + agent-conversations.md (210 lines) all updated and consistent.
- All 7 PRD open questions RESOLVED (1 by lore-master in design, 6 by architect in this phase).
- 1 critical precondition added: data-expert task 0 (spell ID reclamation), gating the rest of the content work.
- Implementation phase ready to start.
