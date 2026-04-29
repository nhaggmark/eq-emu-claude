# Round 5 — Four Review Passes

> **Date:** 2026-04-29
> **Architect:** V3R architect
> **Inputs:** Rounds 1–4
> **Purpose:** Perform mandatory four review passes per architect agent definition (Feasibility, Simplicity, Antagonistic, Integration) before writing the V3R architecture document.

---

## Pass 1 — Feasibility

**Question:** Can we actually build this?

### Fix V (Option A — `Companion::Process()` restructure)

**Verifiable extension points:**
- ✓ `Companion::Process()` exists at companion.cpp; c-expert traced from line 1933 (Fix R4) through the entire body (B.1–B.11) with file:line precision.
- ✓ `m_ping_timer`, `m_death_despawn_timer`, `m_rez_delay_timer`, `m_retention_check_timer`, `m_mana_report_timer` are all confirmed Companion-class members with concrete check sites.
- ✓ `bool is_dead = (GetHP() <= 0);` capture is a trivial local-variable pattern with no API changes.
- ✓ `if (!is_dead)` guards are pure structural change; no new functions, no API changes, no struct changes.
- ✓ `NPC::Process()` continues to be called at the end of the function (no return-path divergence).

**Cross-validation:** protocol-agent P-1 independently identified the heartbeat mechanism (`PlayerPositionUpdateServer_Struct`, prior fix at commit 9e4b7dfd1) and confirmed Titanium culling behavior. Two-advisor convergence on root cause + fix shape.

**Build verification:** TDD red commit (V3R.1 task) writes V.1 (`heartbeat_fires_for_dead_companion`), V.2 (`despawn_timer_fires_for_dead_companion`), V.3 (`alive_companion_regen_regression_guard`) tests that fail/pass appropriately pre-fix. Then V3R.2 implements; V3R.4 rebuild + verify all tests pass + Suite 29/Suite 36 V1/V2 tests still pass.

**Verdict:** FEASIBLE. Risk: LOW.

### Fix W α — Two-site `IsCompanion`-aware AoE exclusion

**Verifiable extension points:**
- ✓ `Mob::IsAttackAllowed` at aggro.cpp; c-expert C-9 / D.1 confirmed the `_NPC(x)` matrix is the correct insertion point.
- ✓ `Mob::IsCompanion()` exists and is virtual on the Companion class (returns true).
- ✓ `Companion::GetOwnerCharacterID()` returns `m_owner_char_id`.
- ✓ `Client::CharacterID()` is the standard EQEmu Client API.
- ✓ `IsPetOwnerOfClientBot()` exists at effects.cpp:1143-1145; c-expert D.2 confirmed it as Site 2.
- ✓ Codebase precedent at `entity.cpp:5636` (cone AoE `IsCompanion()` exclusion) confirms pattern is established and accepted in this codebase.

**Cross-validation:** Three-advisor convergence on root cause (c-expert C-2 + config-expert G-3 + data-expert D-3). Lua-expert L-5 confirmed the `members[]` vs `membername[]` distinction does not affect this fix path (the AoE filter is owner-pointer based, not group-membership based).

**Build verification:** V3R.1 writes W.1 (`aoe_excludes_owner_companion`) test; V3R.3 implements both sites; V3R.4 rebuild + verify all tests pass.

**Verdict:** FEASIBLE. Risk: LOW. Codebase precedent reduces unknowns.

### V3R-Empirical-1 (BUG-003 4-test protocol)

**Verifiable mechanisms:**
- ✓ `#set mana [Amount]` confirmed in source (data-expert D-12 read `set_mana.cpp:3-40`).
- ✓ `#set mana_full` / `#mana` confirmed working on companion NPCs.
- ✓ `companion_data` schema is known (data-expert D-1).
- ✓ Rule `Companions:CompanionManaRegenMult` exists with current value 100 (config-expert G-5).
- ✓ `#reloadrules` GM command exists.
- ✓ `!status` companion command displays mana (lua-expert B.5 enumeration).
- ✓ Lashun Novashine (Cleric companion) and Jimble Woodentoe (test rez target) are known on this server.

**Possible failure modes:**
- The protocol depends on game-tester / user being able to time `!status` responses against gsay reports manually. Margin of error in measurement is bounded; the discriminator is "≥100/report vs ≤50/report" which is a 2× delta, well outside human-observation noise.
- Test 3 requires Jimble (or any companion) to be killable and auto-rezzable. If the test environment cannot reliably reproduce the auto-rez (e.g., Cleric ran out of mana), Test 3 may need retry. data-expert D-13 includes a setup check.

**Verdict:** FEASIBLE. Risk: MEDIUM (manual observation accuracy). Mitigation: 60s observation window with 4 cycles gives statistical robustness.

### Test Suite Additions (V.1 / V.2 / V.3 / W.1)

**Verifiable extension points:**
- ✓ Suite 36 already exists in `cli_companion_tests.cpp` (V2 added 17 tests in this suite).
- ✓ Test framework supports building & running `./bin/zone tests:companion`.
- ✓ Existing tests in Suite 29 / Suite 36 demonstrate the patterns for testing Process() block behavior, timer state, and AoE target selection.

**Verdict:** FEASIBLE. Risk: LOW.

### Pass 1 Summary

All three fixes (V, W, empirical-first protocol) are feasible with low-medium risk. No additional prototyping required. Codebase precedent exists for both code fixes. The empirical protocol is a manual game-tester scenario with established GM commands. **Feasibility: PASS.**

---

## Pass 2 — Simplicity

**Question:** Is this the simplest approach? Can anything be removed, deferred, or handled by an existing system? Apply YAGNI ruthlessly.

### Fix V — Can it be smaller?

The Option A pattern (`bool is_dead` + guards) is structurally minimal. Alternatives considered:
- **Option B (early-return + inline heartbeat duplication):** Was in the prior V3 plan as fallback. Would require duplicating the heartbeat block into the dead-entity path. **REJECTED** — code duplication of despawn timer body too. Option A is cleaner.
- **Move heartbeat to `Mob::Process` base:** Would generalize the heartbeat to all NPCs. **REJECTED** — out of scope; would change behavior for non-companion NPCs which is an unjustified V3R surface expansion.
- **Conditional Fix R4 (e.g., only short-circuit for some-specific case):** **REJECTED** — Fix R4's intent (no AI dispatch for dead) is correct. The bug is the OVER-application, not the existence of the guard.

**YAGNI:** The prior V3 plan considered a defensive `m_hold_combat_position` heartbeat bypass (V3 Subtlety #2). c-expert ruled it out via empirical math (V3 Amendment 2026-04-29). **Confirmed REMOVED from V3R scope** — not adding it back.

### Fix W — Can it be smaller?

Two sites (`IsAttackAllowed` + `IsPetOwnerOfClientBot`). Could it be one?
- If only Site 1 is fixed: `ST_TargetAENoPlayersPets` AoE class still hits companions. **NOT ACCEPTABLE** — leaves an obvious hole.
- If only Site 2 is fixed: Other detrimental AoE classes still hit companions. **NOT ACCEPTABLE** — leaves the primary symptom unfixed.

**Two sites is the minimal correct fix.** Not reducible.

**Could a new rule replace the C++ change?** config-expert G-1 confirmed `Pets:AESpellHittingPet` does not exist. config-expert G-7 proposed an optional `Companions:AoEExcludesCompanions` rule but **the architect leans NO** — adding a rule for behavior that should always be the correct default introduces operator-tuning surface that can only break things, not improve them. Hardcoded is simpler.

### Fix W α vs β vs γ — Already simplest?

α is two narrow C++ checks. β would be one change but with wide blast radius (rejected per V3R Mandate). γ would be one narrower change (Client-side override) but insufficient (doesn't address Path 2). α is the minimum correct surface.

### V3R-Empirical-1 — Can it be smaller?

- Test 4 (buff-state) is OPTIONAL. Already minimized.
- Test 3 (post-rez Jimble) tests a specific branch. If V3R-4 Test 1 + Test 1.5 + Test 2 produce a clear verdict, Test 3 might be skippable.
- Could the protocol be just Test 1 + Test 1.5? **No** — without Test 2, the misperception-vs-rule-tuning verdict cannot distinguish Branch B-misperception from Branch B-rule definitively if Test 1 is borderline. Test 2 is the discriminator.

**Minimum:** Test 1 + Test 1.5 + Test 2 = 3 tests + 1 conditional rule UPDATE. Test 3 + Test 4 are conditional escalation discriminators, run only if 1-2 produce ambiguous results.

### BUG-005 — Could it be deferred?

The V3R Architecture Mandate's surfacing of BUG-005 makes it a discovered bug, not a planned scope. Could it be deferred to a separate bugfix?

**REJECTED** — same root cause (Fix R4) as BUG-002. Same fix surface. Zero additional code change. Deferring would mean writing TWO fixes that look identical, just to honor scope-tightness. This is the inverse of YAGNI: separate-issue-tracking imposes more surface, not less. Bundle.

### V3R-D6 follow-up bugfix posture

If V3R-4 reveals Branch A/C/D (actual code regression), V3R explicitly does NOT bundle that fix. **Follow-up bugfix.** This applies the regression-discipline feedback principle of not bundling speculative code changes with confirmed code changes. Validates simplicity by holding scope.

### Pass 2 Summary

Fix V: minimal. Fix W: two-site is minimum correct. V3R-Empirical-1: 3-5 tests with conditional escalation, already minimized. BUG-005: bundled because zero additional surface; deferring would expand surface. **Simplicity: PASS.**

---

## Pass 3 — Antagonistic

**Question:** What could go wrong? Steel-man the argument against this approach.

### Edge cases that could break Fix V

**E-1:** What if `GetHP()` returns negative (negative HP from massive damage)? `is_dead = (GetHP() <= 0)` correctly handles this.

**E-2:** What if the entity is actively dying mid-Process (HP transitions from positive to zero during the function call)? The local `is_dead` capture pins the value for the entire function call. Subsequent ticks will see `is_dead=true`. Single-tick window with consistent state.

**E-3:** What if a companion is in `is_suspended=1` state but the in-memory entity has cur_hp > 0 (transient state during rez)? Per data-expert D-1, `cur_hp` is written at lifecycle events. During an active rez via `ResurrectFromCorpse → Spawn(owner)`, the new entity's HP is set explicitly (Fix B). The brief window between `new Companion()` and `SetHP()` is microseconds; not a real concern.

**E-4:** What about the despawn timer firing at the exact same tick as a rez attempt? Fix V keeps despawn timer unconditional. If rez succeeds and creates a new entity, the dead entity is depopped (Fix C atomic-rez behavior). If both fire in the same tick, the depop wins (it's after the timer check in the call order, and the timer fire logic checks state before acting).

### Edge cases that could break Fix W

**E-5:** Cross-server impersonation — what if a companion's `m_owner_char_id` is corrupt (zero or wrong character_id)? The check `mob2->IsCompanion() && CastToCompanion()->GetOwnerCharacterID() == caster_char_id` fails when m_owner_char_id is wrong. Companion is NOT excluded → hit by AoE. **This is correct behavior**: a companion with corrupt owner is essentially orphaned and treated as a generic NPC. Not a regression; arguably an existing exposure.

**E-6:** PVP scenarios — Player A has a companion, Player B casts AoE that includes Player A's companion. Fix W's check requires `caster_char_id == companion's m_owner_char_id`. Player B is not the owner → check fails → companion IS hit. **This is correct PVP behavior** — only the owner is blocked from hitting their own companion.

**E-7:** Companion-cast AoE — Companion casts harmful AoE that includes the owner. `Companion::IsAttackAllowed` override at companion.cpp:832 already handles this case (companion-as-caster). Fix W only modifies Client-as-caster path. **No regression.**

**E-8:** Beneficial AoE from a player to companion — Group heals, bardsongs, group buffs. These go through `IsBeneficialAllowed` (`SetAllowBeneficial(true)` constructor flag — c-expert F.4). Fix W only modifies the detrimental path. **Beneficial AoE still works correctly.**

### Race conditions / data corruption

**E-9:** What about concurrent zone-tick modifications? EQEmu zones are single-threaded. No concurrent reads/writes of companion state. Race window is zero per c-expert E.5 / E.6.

**E-10:** Server crash mid-Process? The Process() call is atomic at the granularity of the tick. A crash mid-Process leaves the database in its last-Save() state (data-expert D-1). Fix V doesn't change persistence behavior; same crash-resilience as pre-V3R.

### Performance concerns

**E-11:** Adding `IsCompanion()` checks to AoE filter — performance? `IsCompanion()` is a virtual function returning a bool. Called once per AoE target during sweep. AoE radius is bounded (`Spells:TargetedAOEMaxTargets=4` etc.). Microsecond-level overhead per cast; entirely negligible.

**E-12:** Adding `bool is_dead` capture + branching in `Companion::Process()` — performance? One bool capture, one branch per tick per companion. Companions are bounded to 5 per player + N players + small zone scale. Sub-microsecond overhead per tick. Negligible.

### Player exploits / abuse vectors

**E-13:** Could a player exploit Fix W to dodge AoE damage? Companions can't shield-soak the player's own AoE because Fix W only excludes companions from the player's AoE — the player still takes their own AoE damage if in radius. No exploit vector.

**E-14:** Could Fix W's owner check be spoofed? `m_owner_char_id` is set server-side at recruitment / Spawn. Not exposed to client modification. Cannot be spoofed.

**E-15:** Could BUG-005 fix interact badly with the `!unsuspend` recovery path? When `!unsuspend` is invoked, the companion is reloaded via `SpawnCompanionsOnZone` path (data-expert + c-expert A.5 confirm). The despawn timer would be re-initialized to disabled state. **No conflict.**

### Backward compatibility

**E-16:** V1 fix (ST_Corpse extension) — Fix V doesn't touch spells.cpp. **Preserved.**

**E-17:** V2 Fix B (Spawn(owner) reroute) — Fix V doesn't touch the rez path. **Preserved.**

**E-18:** V2 Fix A (membername[] clear) — Fix W doesn't depend on group state. **Preserved.**

**E-19:** V2 Fix C (atomic rez + Option D pre-flight) — Fix V doesn't touch the rez path. **Preserved.**

**E-20:** V2 Fix R4 (alive guard) — REPLACED by Fix V Option A. The intent (no AI dispatch for dead) is preserved; the implementation is restructured to keep heartbeat + despawn timer unconditional. **Honored, restructured.**

### What the prior V3 plan missed

- **BUG-005 auto-dismiss timer** — discovered by V3R enumeration; addressed by same Fix V change.
- **The two-site BUG-004 fix (D.2 path)** — prior V3 plan didn't include BUG-004 at all (was scoped only to BUG-002 + BUG-003).
- **The G-10 rule-tuning hypothesis for BUG-003** — prior V3 plan had "likely misperception" but didn't surface the structural 1.75x player-vs-companion regen multiplier gap.

These are improvements, not concerns. They validate the V3R Architecture Mandate's value.

### Antagonistic items left for game-tester

- **C-10 (Fix C atomic-rez coexistence window):** Insert into V3R-8 multi-rez scenario per Round 4 plan. Theoretical only; not a known failure mode.
- **`NPC:OOCRegen` vs `Companions:OOCRegenPct` interaction (G-9):** Insert into V3R-6 long-duration sit regen per Round 4. If observed regen is ~1 HP/tick (NPC base) instead of ~5% of max HP (Companions custom), code-path regression is real.

### Pass 3 Summary

20 antagonistic items considered. No edge case unbroken by the fix. No race condition exposed. No performance concern. No exploit vector. No backward-compatibility breakage. Two items (C-10 + G-9 carry-forward) are validation-time hooks already in the V3R Validation Plan. **Antagonistic: PASS.**

---

## Pass 4 — Integration

**Question:** How do the pieces fit together? Walk through the implementation sequence end to end.

### Task dependency graph

```
V3R.1 (TDD red tests, c-expert)
  └─→ V3R.2 (Fix V implementation, c-expert)
       └─→ V3R.4 (rebuild + run tests, c-expert)
  └─→ V3R.3 (Fix W implementation, c-expert)
       └─→ V3R.4 (rebuild + run tests, c-expert)

V3R.4 (rebuild + verify)
  └─→ V3R.5 (server restart, infra-expert)
       └─→ V3R.6 (in-game validation, game-tester)
            └─→ V3R.7 (architect BUG-003 decision)
                 ├─→ V3R.6.5 (conditional rule UPDATE, data-expert)
                 │    └─→ V3R.8 (commit + push, c-expert)
                 ├─→ Branch A/C/D follow-up bugfix (separate workspace)
                 └─→ V3R.8 (commit + push, c-expert)
```

**Critical path:** V3R.1 → V3R.2 + V3R.3 (parallel) → V3R.4 → V3R.5 → V3R.6 → V3R.7 → V3R.8.

V3R.2 and V3R.3 can be implemented in parallel if c-expert prefers (they are independent file changes). Or sequential if c-expert prefers ordered TDD (one test set at a time). Architect lean: sequential to minimize cognitive overhead and rebuild churn — fix and test V, then fix and test W.

### Dependencies on prior fixes (V1, V2)

- V3R.2 (Fix V) **requires V2 Fix R4 to exist** because it replaces Fix R4 with the Option A pattern. V3R is a forward evolution, not a revert.
- V3R.3 (Fix W) is **independent of V1 / V2** — it modifies `Mob::IsAttackAllowed` and `IsPetOwnerOfClientBot`, neither touched by V1 or V2.
- V3R.6 BUG-003 empirical test uses lifecycle helpers that exist in the post-V2 codebase (`#set mana 0`, `!status`, `#reloadrules`).

### Each expert has enough context

- **c-expert:** Has the full V3R enumeration, the Round 3 fix specs, the test specs, and the c-expert Q1+Q2 answers. **Sufficient context.**
- **infra-expert:** Has the documented full-stack restart procedure (per MEMORY.md). **Sufficient context.**
- **game-tester:** Has the V3R Validation Plan with 9 scenarios plus the V3R-Empirical-1 4-test protocol with decision matrix. Will need access to the MEMORY.md companion-cooldown-clearing reference for the `#set mana 0` Test 2 setup. **Sufficient context.**
- **data-expert:** Has the conditional V3R.6.5 task spec (one rule UPDATE) if Branch B-rule is confirmed. **Sufficient context.**
- **architect:** Rejoins at V3R.7 to make the BUG-003 decision. The decision matrix is pre-defined in Round 3 / Round 4. **Sufficient context.**

### Validation plan covers every changed system

| Changed system | V3R Validation scenarios |
|---|---|
| `Companion::Process()` AI tick (Fix V) | V3R-1 (heartbeat), V3R-2 (despawn timer 30 min), V3R-5 (sustained combat), V3R-6 (long sit regen), Band 3 adjacent-system regression matrix |
| `Mob::IsAttackAllowed` AoE filter (Fix W Site 1) | V3R-3 (PRIMARY AoE friend/foe), V3R-9 (sustained AoE encounter), Band 3 cross-owner + companion-cast scenarios |
| `IsPetOwnerOfClientBot` filter (Fix W Site 2) | V3R-3 with `ST_TargetAENoPlayersPets`-class spell repeat, V3R-9 |
| `m_death_despawn_timer` (BUG-005, restored by Fix V) | V3R-2 (PRIMARY 30-min wait) |
| `m_ping_timer` heartbeat (BUG-002, restored by Fix V) | V3R-1 (PRIMARY), V3R-5 (sustained) |
| `Companions:CompanionManaRegenMult` (conditional V3R.6.5) | V3R-4 Test 1.5, V3R-6 if rule bumped |
| Existing alive-companion regen path (regression guard, V.3) | V3R-4 Test 1, V3R-6 |
| !command dispatch (lua-expert L-6 high-risk consumer) | V3R-8 multi-rez cycle's post-rez !-command sweep |

Every changed system has at least one direct scenario AND an adjacent-system regression scenario. Mandate 5 satisfied.

### Order minimizes wasted work

- **V3R.1 first:** TDD red. Confirms tests are testing the right thing before the fix is applied. If a test passes pre-fix, the test is wrong and reframing happens before the fix.
- **V3R.2 + V3R.3:** Parallelizable (no shared file). Sequential is acceptable.
- **V3R.4:** Single rebuild covers both fixes. Single Suite 36 run validates both.
- **V3R.5:** Single restart. Container + processes.
- **V3R.6:** Game-tester runs all 9 + empirical scenarios in one session. Discovers Branch result for BUG-003.
- **V3R.7:** Architect decision. Either close BUG-003, apply rule UPDATE, or escalate.
- **V3R.6.5:** Conditional. Only if Branch B-rule. Single SQL UPDATE.
- **V3R.8:** Single commit + push to feature branch.

No wasted work. No re-do loops if any single step succeeds. The only re-do trigger is if V3R.4 surfaces a regression — then back to V3R.2 or V3R.3 to refine.

### Pass 4 Summary

Task dependencies clean. No circular deps. Each expert has sufficient context. Validation covers every changed system. Order minimizes wasted work. **Integration: PASS.**

---

## Aggregate Review-Pass Verdict

| Pass | Result |
|---|---|
| Feasibility | PASS |
| Simplicity | PASS |
| Antagonistic | PASS (20 items considered, none unbroken) |
| Integration | PASS |

**V3R architecture is ready for documentation (Task #10) and status.md update (Task #11), then architecture-complete summary to team-lead (Task #12) for relay to user.**
