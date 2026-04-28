# Companion Re-recruitment Fix — Product Requirements Document

> **Feature branch:** `bugfix/companion-rerecruit`
> **Author:** game-designer
> **Date:** 2026-04-27
> **Status:** APPROVED — lore-master signed off 2026-04-27

---

## Problem Statement

The companion system is the signature feature of this server. Its core promise
is that a player can pick up an NPC early — say, at level 5 — and travel with
that companion through the entire game, leveling them, gearing them, and
forming a persistent bond. That promise breaks today.

After a companion dies or is dismissed, multiple overlapping mechanisms block
re-recruitment of an NPC the player has already recruited at least once:

1. A **level cap** rejects the NPC as "too low level" (today's reported
   blocker — Lydl the Great in East Freeport).
2. A **cooldown timer** blocks re-engagement for 15 minutes.
3. A stale **dismissed flag** persists on the NPC's companion record after
   death/dismissal, refusing the re-recruit request.

For a 1–3 player server where the user is the only player, every companion
death triggers a manual database cleanup cycle. This is unacceptable. The
re-recruitment path must be friction-free.

## Goals

1. **Lock the re-recruitment invariant:** any NPC that has been recruited
   at least once is re-recruitable indefinitely, with no level rules, no
   cooldown gating, and no flag persistence blocking the attempt.
2. **Preserve continuity:** the re-recruited companion returns at the exact
   level and with the exact gear they had at the moment of death/dismissal.
3. **Fix all three known blockers in one coordinated change** so the
   invariant holds completely. Partial fixes leave the system broken in
   subtle ways and leak through to the player as inconsistent behavior.
4. **Deliver via TDD** so the invariant is machine-verified, not just
   manually observed once and forgotten.

## Non-Goals

- **Removing level caps on FIRST recruitment.** The user did not ask for
  this. Whatever existing rules gate the *initial* recruit of a
  never-before-recruited NPC stay as they are. This change targets
  re-recruitment only.
- **Companion AAs / advancement systems.** Out of scope; future feature.
- **Companion XP rate tuning.** Owned by `feature/xp-retune` (already
  merged). Do not re-tune here.
- **Pet, swarm pet, and charm pet behavior.** Different system. Untouched.
- **NPC spawn/respawn or world-population side effects** (e.g., guards
  vanishing from their post). Flagged as a lore touchpoint, not a scope
  expansion — see Open Questions.
- **Recruitment UX redesign.** No changes to the conversation flow, dialog
  text, or recruit command unless required to enforce the invariant.

## User Experience

### Re-recruitment Invariant (THE design contract)

> Once an NPC has been recruited as a companion at any point, the player
> must ALWAYS be able to re-recruit that NPC after death, dismissal, or any
> other drop-out condition. The companion is re-recruited with their gear
> and level intact. There must be no level rules around re-recruiting. A
> player can recruit an NPC at level 5 and take them through the entire
> game.

### Player Flow

1. Player recruits an NPC for the first time. Existing first-recruit rules
   apply (whatever they are today — unchanged by this feature).
2. The companion adventures with the player, gains levels, and is equipped
   with gear over time.
3. The companion drops out of the group through one of:
   - **Death** in combat
   - **Dismissal** by the player
   - **Any other drop-out condition** (zone disconnect, server restart,
     etc. — anything that ends the active companion session)
4. The player approaches the original NPC again and issues the re-recruit
   command (per `claude/docs/companion-commands-reference.md`).
5. The NPC accepts immediately. No "too low level" error. No "won't
   discuss joining you again so soon" cooldown message. No silent dismiss.
6. The companion rejoins the group at the **exact level** and with the
   **exact gear** they had at the moment they dropped out.

### Example Scenarios

**Scenario A — Low-level companion, high-level player.**
Player recruited Lydl the Great at character level 5. By the time the
player has reached character level 35, Lydl was leveled to 12 in the
intervening sessions, then died fighting a mob in Befallen. The player
returns to East Freeport, finds Lydl, and re-recruits. Lydl rejoins as a
level 12 companion with all prior gear. There is no "too low level"
rejection.

**Scenario B — Dismiss-and-recall.**
Player has Mira the Healer (level 22) recruited but wants to swap to a
different companion for a tradeskill run. Player dismisses Cyrla, runs the
tradeskill loop, and a few minutes later wants Cyrla back. Player
approaches Cyrla and re-recruits immediately. No 15-minute cooldown
applies. Cyrla rejoins at level 22 with full gear.

**Scenario C — Death-and-rejoin with no waiting.**
Companion dies mid-combat in Sebilis. Player ports back to the companion's
home zone and re-recruits. The companion rejoins. No cooldown. No
dismissed-flag rejection. Same level. Same gear.

**Scenario D — First recruitment regression check.**
Player approaches a never-before-recruited NPC. Whatever rules normally
gate that first recruit (level range, faction requirements, etc.) still
apply — this fix does NOT silently relax them.

## Game Design Details

### Mechanics — three rules to enforce

The invariant decomposes into three rules. The architect determines how
each is enforced; the design contract is that all three must hold.

1. **Re-recruitment bypasses level rules.** If the system has a record of
   the NPC having been recruited before by this character, no level
   comparison gates the re-recruit. The "too low level" path must not be
   reachable for re-recruitment.

2. **Re-recruitment bypasses recruitment cooldown.** If the system has a
   record of the NPC having been recruited before by this character, no
   cooldown timer blocks re-recruitment. The cooldown system may still
   exist for OTHER reasons (e.g., a player abandoning a brand-new recruit
   immediately after recruiting them — that's an existing-rule decision,
   not a re-recruit decision), but the re-recruit path must be cooldown-
   free.

3. **Dismissed/dropped-out state is reversible.** Whatever flag(s) mark a
   companion as currently-not-active must be cleanly cleared on
   re-recruit. The dismissed/dead/suspended state is a transient marker,
   not a permanent gate.

### Continuity Guarantees

- **Level preservation:** the re-recruited companion's level matches their
  level at the moment they dropped out. Not reset to recruit-time level.
  Not reset to NPC base level. Exact preservation.
- **Gear preservation:** all items the companion had equipped or carried
  at drop-out time are present on re-recruit. No gear is lost.
- **Per-character recruitment record:** "previously recruited" is scoped
  to the character who originally recruited the NPC. This bug fix does
  not extend re-recruitment privileges across characters.

### Balance Considerations

- The 1–3 player constraint is the whole reason the invariant exists.
  With one player, losing your recruited companion to a database flag is a
  game-stopping event. The invariant is what makes the companion system
  feel like a real companion, not a temporary summon.
- This is not a power increase. The companion is at the exact level and
  gear they were before. No buffs, no resets, no advantage. The fix
  removes friction; it does not add power.
- First-recruit gating is preserved (Non-Goal #1), so this change does
  not let players grab arbitrarily-leveled NPCs they never qualified for.

### Era Compliance

The fix is mechanical and touches no narrative content. Nothing here
introduces post-Luclin systems, items, zones, or NPCs. The recruitable
NPC roster is unchanged.

The re-recruitment mechanic does not attempt to explain an NPC's
absence from their post (e.g., a recruited city guard vanishing from
their gate). This is consistent with Norrath's static-respawn fiction —
vanilla EQ never canonized NPC presence/absence either. Lore-master
approved this framing.

## Affected Systems

The architect determines exact touchpoints during triage. The PRD lists
the systems plausibly involved:

- [x] C++ server source (`eqemu/`) — companion recruitment validation,
      level-rule enforcement, flag handling
- [x] Lua quest scripts (`akk-stack/server/quests/`) — recruit dialog,
      cooldown messaging path (the "won't discuss joining you again so
      soon" message lives in companion.lua per MEMORY reference, but
      verify against current code)
- [ ] Perl quest scripts (maintenance only) — only if a recruitment
      flow uses Perl
- [x] Database tables (`peq`) — `data_buckets` (cooldown entries),
      `companion_data` (suspended/dismissed flags), `companion_inventories`
- [x] Rule values — any `Companions:*` rule gating recruitment
- [ ] Server configuration — unlikely; flag if architect finds otherwise
- [ ] Infrastructure / Docker — n/a

## Dependencies

None. This bugfix is self-contained. `feature/xp-retune` has already
merged and does not block this work.

## Open Questions

1. **Lore touchpoint — named NPCs as permanent companions.**
   Lore-master reviewed the invariant and approved with no lore
   blockers. Two flavor-level edge cases were flagged for the
   architect's awareness (NOT scope expansions for this bugfix):
   - **Guards/merchants/quest-givers vanishing from their post.** Same
     fiction break vanilla EQ already has via static respawn. Noted in
     Era Compliance; no design change required.
   - **Quest-chain NPCs mid-quest.** A recruitable NPC who is also a
     kill-target or dialogue node in an active quest may produce
     awkward quest-state interactions on re-recruit. Lydl the Great is
     himself a kill target in the Lydl Mastat wizard-guild quest. The
     architect should evaluate whether re-recruit logic needs to
     consider active-quest state. The invariant still holds — this is
     a mechanical edge case, not a lore constraint.
2. **First-recruit cooldown semantics (architect to clarify).** If the
   cooldown system serves a purpose for first-recruits (e.g., preventing
   accidental immediate re-recruitment of a new NPC), keep that path
   intact. If the cooldown only ever served as a re-recruit gate, the
   architect may decide to remove it entirely.
3. **In-memory cache flushing (architect).** MEMORY notes that the
   `data_buckets` cache historically did not flush with `#rq`. If
   cooldowns are bypassed at the recruit-validation layer, cache
   staleness may be irrelevant. If they are deleted at the database
   layer, cache invalidation must be considered.
4. **"Other drop-out conditions" enumeration (architect to validate).**
   Death and dismissal are explicit. The invariant uses "or otherwise
   drop out of the group" — confirm the system handles zone-disconnect,
   server-restart, group-disband, and any other drop-out paths the same
   way.

## Acceptance Criteria

The PRD is complete when ALL of these are demonstrably true. Each
criterion maps to a test case in the Validation Plan.

- [ ] **AC-1:** A previously-recruited NPC can be re-recruited at any
      player level, regardless of the player level vs. NPC level
      comparison.
- [ ] **AC-2:** No "too low level" error path is reachable for a
      previously-recruited NPC.
- [ ] **AC-3:** A previously-recruited NPC can be re-recruited
      immediately after death — no cooldown wait.
- [ ] **AC-4:** A previously-recruited NPC can be re-recruited
      immediately after dismissal — no cooldown wait.
- [ ] **AC-5:** Re-recruited companion's level exactly matches their level
      at the moment of drop-out.
- [ ] **AC-6:** Re-recruited companion's gear (equipped + carried) exactly
      matches their inventory at the moment of drop-out.
- [ ] **AC-7:** First-recruitment of a never-before-recruited NPC still
      enforces existing rules (level range, faction, etc.) — no
      regression on the first-recruit path.
- [ ] **AC-8:** Concurrent re-recruit attempts cannot produce a
      double-recruited companion (regression).
- [ ] **AC-9:** Engineers ship failing tests FIRST that prove the
      invariant, then implement to make tests pass. The test suite
      survives in the repo as machine-verified evidence the invariant
      holds.
- [ ] **AC-10:** Re-recruitment of an NPC who is also a kill target or
      dialogue node in an active quest (e.g., Lydl Mastat quest) still
      succeeds per the invariant. Architect evaluates whether quest
      state requires special handling; the invariant itself is not
      contingent on quest status.

## Validation Plan

The architect translates these into specific test types (unit /
integration / in-game). The game-designer specifies the scenarios that
must be covered.

### TDD Approach (design constraint)

Engineers implementing this fix MUST write failing tests first. Each
acceptance criterion above gets at least one test that fails before the
fix lands and passes after. The tests are part of the deliverable.

### Required Test Scenarios

1. **Re-recruit at LOWER player level than companion** — recruit at
   level 30, companion levels to 35, player de-levels (or scenario
   constructed via test fixture), re-recruit succeeds.
2. **Re-recruit at HIGHER player level than companion** — Lydl-style
   case. Recruit at level 5, player advances to level 35, companion
   stays at level 12, re-recruit succeeds.
3. **Re-recruit after death in combat** — companion's `cur_hp=0` /
   suspended state does not block re-recruit.
4. **Re-recruit after explicit dismissal** — `is_dismissed=1` (or
   equivalent) does not persist in a way that blocks re-recruit.
5. **Re-recruit immediately, no cooldown wait** — within seconds of
   drop-out. The "won't discuss joining you again so soon" message
   path is unreachable for previously-recruited NPCs.
6. **Gear preservation across drop-out cycle** — equip the companion
   with a uniquely-identifiable item (e.g., a no-drop quest reward),
   trigger drop-out, re-recruit, verify item is still there.
7. **Level preservation across drop-out cycle** — level the companion
   to a non-default level, trigger drop-out, re-recruit, verify level
   matches exactly.
8. **First-recruit regression check** — never-before-recruited NPC
   still observes existing first-recruit rules. This protects against
   a fix that accidentally removes ALL level/cooldown gating instead
   of only the re-recruit path.
9. **Concurrent re-recruit regression** — two simultaneous re-recruit
   attempts on the same companion produce one companion in the group,
   not two.
10. **Multi-character isolation regression** — character A's
    re-recruit privilege for an NPC does not extend to character B
    (per Game Design Details — per-character recruitment record).

### Validation Phases

- **Engineer-side (unit / integration):** Test scenarios 1, 2, 5, 8, 9,
  10 are most amenable to automated verification. Architect to confirm
  what the C++/Lua test harness supports.
- **Game-tester (in-game):** Test scenarios 3, 4, 6, 7 require live
  server reproduction with a real character, real death, real items.
  Game-tester runs these in-game with a scripted checklist.
- **User confirmation:** Final sign-off after game-tester reports PASS.

## Rollback

Each blocker may live in a different file/system. Rollback is per-fix:

1. **Level-cap fix rollback:** revert the change(s) that added the
   "previously recruited bypass" to the level-validation path. The
   level cap returns to its prior behavior. Players see the
   "too low level" error again on re-recruit, but no other system is
   harmed.
2. **Cooldown-bypass rollback:** revert the change(s) that added the
   bypass to the cooldown check. The cooldown is enforced again.
   `data_buckets` rows continue to be created/cleared as before.
3. **Dismissed-flag rollback:** revert the change(s) that fixed
   dismissed-flag clearing. The flag persists incorrectly again, and
   players hit the original re-recruit failure mode. No corruption
   risk to companion data.

All three reverts are independent and additive. Reverting one does not
require reverting the others. The architect documents the revert
boundary for each fix in the implementation plan.

The TDD test suite stays in the repo even on rollback — the tests
become "known broken" markers for the regressed behavior rather than
being deleted. This preserves the design intent.

---

## Appendix: Technical Notes for Architect

**This appendix is advisory only. The architect makes all
implementation decisions.**

### Context from Bug Report BUG-001

**Re-recruitment invariant (verbatim user statement):**
> "Once I recruit a companion, I should always be able to re-recruit
> that companion after they die or otherwise drop out of the group.
> They become re-recruited with their gear and levels intact. There
> should be no rules around levels on re-recruiting companions. The
> idea is that I can recruit an NPC at level 5 and take them through
> the entire game with me."

### Three Known Blockers (recap for architect)

1. **Level caps** — Lydl the Great in East Freeport returns "too low
   level" on re-recruit. Source of the level-cap rule unknown to
   game-designer; architect to identify (rule_values entry,
   hard-coded check, Lua guard, or a combination).
2. **Cooldown timers** — `data_buckets` companion cooldowns are stored
   with `character_id=0` and `npc_id=0`; the actual IDs are embedded
   in the `key` string as `companion_cooldown_{npc_type_id}_{char_id}`
   (per MEMORY.md `reference_companion_cooldown_clearing`, 44 days old
   — verify against current code). Cooldowns must be matched/cleared
   by key pattern, not by the `character_id` column. Per MEMORY, the
   "won't discuss joining you again so soon" message comes from
   `companion.lua` around line 399 — verify this is still accurate.
3. **Dismissed flag** — `is_dismissed=1` (or equivalent) on
   `companion_data` persists incorrectly after death/dismissal.
   Companion records may also have `cur_hp=0` and `is_suspended=1`
   that interact with the recruit-validation logic.

### TDD as a Hard Design Constraint

The user explicitly asked for TDD. Engineers write failing tests first,
then implement. The architect translates the Validation Plan scenarios
into concrete test types:

- **Unit tests** where the recruit-validation logic can be exercised
  in isolation
- **Integration tests** where a full recruit flow needs the database
- **In-game scripted scenarios** for the game-tester where live server
  state is required (drop-out path, gear preservation, level
  preservation)

### Architect Reference Docs (provided by team-lead)

- MEMORY.md: `project_companion_rerecruit_pain` (44 days old — verify)
- MEMORY.md: `reference_companion_cooldown_clearing` (44 days old —
  verify)
- `eqemu/zone/lua_companion.cpp` — companion Lua binding
- `akk-stack/server/quests/global/global_npc.lua` — global NPC handler
- `akk-stack/server/quests/lua_modules/client_ext.lua` — client
  extensions
- `akk-stack/server/quests/lua_modules/llm_bridge.lua` — LLM bridge
  (relevant only if recruit dialog routes through LLM)

### Tables of Interest (from MEMORY)

- `data_buckets` — cooldown entries, key pattern
  `companion_cooldown_{npc_type_id}_{char_id}`
- `companion_data` — `cur_hp`, `is_suspended`, `is_dismissed`,
  per-character per-NPC record
- `companion_inventories` — companion gear, keyed by
  `companion_data_id`

### Suggested Rule-Name Hint (advisory, not prescriptive)

If level-cap behavior is rule-driven, MEMORY references a rule called
something like `Companions:LevelRange`. The architect should verify
the actual rule name and decide whether to scope the bypass at the
rule-evaluation site (preferred — keeps the rule available for
first-recruit gating) or remove the rule entirely (only if it serves
no other purpose).

---

> **Next step:** Pass this PRD to the **architect** for technical
> feasibility assessment and implementation planning.
