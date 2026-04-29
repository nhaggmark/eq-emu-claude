# Round 3 — Fix Proposal and Task Breakdown

> **Date:** 2026-04-29
> **Architect:** V3R architect
> **Inputs:** Round 1 advisor enumerations + Round 2 joint root-cause synthesis
> **Purpose:** Translate the locked root causes into concrete, narrowly-scoped fix proposals with task breakdown for Round 4 (review passes) and Task #10 (architecture.md V3R section).

---

## 1. Fix Surface Summary

The V3R fix surface comprises **two C++ changes** addressing three bugs (BUG-002, BUG-005, BUG-004), plus an **empirical-first BUG-003 workflow** that may or may not produce a conditional fix (one rule UPDATE if Branch B-rule is confirmed; no change if Branch B-misperception; escalation to follow-up bugfix if Branch A is confirmed).

| Fix | Surface | Bugs addressed |
|---|---|---|
| Fix V (Option A) | `Companion::Process()` top-section restructure (~25 lines) | BUG-002 + BUG-005 |
| Fix W (α) | Two-site `IsCompanion`-aware AoE exclusion | BUG-004 |
| Empirical Test V3R-Empirical-1 | 4-test in-game protocol with rule-bump branch | BUG-003 (conditional fix) |

**Tests added:** 4 new failing-first tests in Suite 36 of `cli_companion_tests.cpp`:
1. `heartbeat_fires_for_dead_companion` — V3R V.1
2. `despawn_timer_fires_for_dead_companion` — V3R V.2
3. `aoe_excludes_owner_companion` — V3R W.1
4. `alive_companion_regen_regression_guard` — V3R V.3 (already-passing guard for sustained alive-companion regen)

---

## 2. Fix V (Option A) — `Companion::Process()` Restructure

**Bugs addressed:** BUG-002 (visibility heartbeat) + BUG-005 (auto-dismiss timer) — both stem from V2 Fix R4's blanket early-return for HP<=0 entities.

**Fix shape:** Replace the Fix R4 blanket early-return at `companion.cpp:1933-1935` with a `bool is_dead` capture + `if (!is_dead)` guards on AI-dispatch sections only. Keep the heartbeat block (B.1) AND the death despawn timer block (B.2) UNCONDITIONAL.

**Reference enumeration (c-expert C-1 + C-7 + B.1–B.11):**

| Block | File:line | Run when dead? | Wrap behavior |
|---|---|---|---|
| Fix R4 alive-guard (current) | `companion.cpp:1933-1935` | `return NPC::Process()` early | **REMOVE** — replace with `bool is_dead = (GetHP() <= 0);` capture |
| B.2 — `m_death_despawn_timer.Check()` | `companion.cpp:1938-1964` | YES (must run for dead) | UNCONDITIONAL — outside `if (!is_dead)` guard |
| B.3 — `m_rez_delay_timer` engaged→idle tracking | `companion.cpp:1966-1981` | NO (dead doesn't track engagement) | INSIDE `if (!is_dead)` |
| B.4 — `m_retention_check_timer` (mercs) | `companion.cpp:1984-1986` | NO (dead mercs don't pay retention) | INSIDE `if (!is_dead)` |
| B.1 — `m_ping_timer` heartbeat | `companion.cpp:2128-2142` | YES (dead corpse must remain visible) | UNCONDITIONAL — outside `if (!is_dead)` guard |
| B.7 — Sitting sync / stand-when-engage | `companion.cpp:2144-2160` | NO | INSIDE `if (!is_dead)` |
| B.8 — Mana report gsay timer | `companion.cpp:2162-2168` | NO (dead doesn't gsay regen) | INSIDE `if (!is_dead)` |
| B.9 — LOM announcement | `companion.cpp:2171-2188` | NO | INSIDE `if (!is_dead)` |
| B.10 — Combat positioning / formation | `companion.cpp:2190-2218` | NO | INSIDE `if (!is_dead)` |
| B.11 — Attack rounds | `companion.cpp:2203-2218` | NO | INSIDE `if (!is_dead)` |
| Final `return NPC::Process()` | (existing, end of function) | YES (NPC base must run) | UNCONDITIONAL — runs after both guarded and unguarded sections |

**Pseudo-code (illustrative, NOT the exact line edit — c-expert specifies in implementation):**

```cpp
bool Companion::Process()
{
    bool is_dead = (GetHP() <= 0);

    // UNCONDITIONAL — heartbeat must run for dead-but-corpse-visible entities
    if (m_ping_timer.Check()) {
        SentPositionPacket(0, 0, 0, 0, 0);
    }

    // UNCONDITIONAL — death despawn timer must run for dead entities
    if (m_death_despawn_timer.Check()) {
        // (existing despawn handling)
    }

    if (!is_dead) {
        // AI-dispatch sections — these would be incorrect to run for dead entities
        // - rez delay timer (B.3)
        // - retention check (B.4)
        // - sitting sync (B.7)
        // - mana report (B.8)
        // - LOM announcement (B.9)
        // - combat positioning (B.10)
        // - attack rounds (B.11)
    }

    return NPC::Process();
}
```

**Rationale:**
- **Heartbeat unconditional:** A dead companion entity remains visible as a corpse-in-place to the Titanium client. Without periodic position keepalive, Titanium culls the entity. The heartbeat must continue firing for dead entities until the entity is actually depopped (which is what the despawn timer eventually does).
- **Despawn timer unconditional:** This is what BUG-005 surfaced. Without checking the despawn timer, dead-not-rezzed companions never auto-dismiss. The timer must run.
- **AI-dispatch guarded:** Dead entities should not regen, gsay, position-track, or attack. Fix R4's original intent (no AI dispatch for dead entities) is preserved by the guards.

**Confidence:** HIGH. Two-advisor convergence (c-expert C-1 + C-7, protocol-agent P-1) on root cause; c-expert's enumeration enumerates every block to be guarded vs unguarded.

**Failure modes considered:**
- If `is_dead` flips mid-frame (extremely unlikely; HP is set atomically): no race because the local capture pins the value for the entire `Process()` call.
- If the despawn timer fires DURING combat (extremely unlikely; defaults are 30 minutes): not a regression; the timer was supposed to fire and it does.
- If the heartbeat fires for an entity that is in the process of being despawned: benign; the heartbeat is a no-op past depop because the entity is no longer in the entity list.

---

## 3. Fix W (α) — `IsCompanion`-Aware AoE Exclusion

**Bug addressed:** BUG-004 (player harmful AoE hits own NPC companions).

**Fix shape:** Two narrowly-scoped C++ checks following codebase precedent at `entity.cpp:5636` (cone AoE `IsCompanion()` exclusion).

**Reference enumeration (c-expert D.1 / D.2 / H.1 / config-expert G-3 / G-4 / data-expert D-3 / D-4):**

### Site 1 — `Mob::IsAttackAllowed` base (aggro.cpp `_NPC` matrix)

The base `Mob::IsAttackAllowed` at approximately `aggro.cpp:732+` resolves `mob1`/`mob2` to owner-or-self, then matches via the `_CLIENT vs _NPC` matrix. The `_NPC(x) = x->IsNPC() && !x->GetOwnerID()` macro returns true for companions because they don't `SetOwnerID()`.

**Proposed change:** Before the `_CLIENT vs _NPC` branch returns true for client-attacking-NPC, add a check: if the target is a Companion AND the caster's CharacterID matches the Companion's `m_owner_char_id`, return false (not allowed to attack own companion).

The exact line and form of the check is c-expert's specification. Two implementation options:
- **Option 1 (centralized):** Modify the `_NPC(x)` macro to also exclude `IsCompanion()` whose owner is the caster.
- **Option 2 (surgical):** Insert a dedicated `if (mob2->IsCompanion() && mob2->CastToCompanion()->GetOwnerCharacterID() == mob1->CastToClient()->CharacterID()) return false;` BEFORE the `_NPC` matrix.

**Architect lean:** Option 2 (surgical). Macro modification has unintended-consequence risk for any other consumer of `_NPC(x)`; surgical insertion is auditable and follows the existing precedent pattern at entity.cpp:5636.

### Site 2 — `IsPetOwnerOfClientBot` filter for `ST_TargetAENoPlayersPets`

`effects.cpp:1143-1145` filters `ST_TargetAENoPlayersPets` AoE targets via `IsPetOwnerOfClientBot()` which checks pet flags set via `SetOwnerID()`. Companions never set these flags → they are transparent to this filter.

**Proposed change:** Add a parallel check that excludes companions whose `m_owner_char_id` matches the AoE caster's CharacterID. Either:
- Extend `IsPetOwnerOfClientBot()` to ALSO return true if the entity is a Companion owned by a Client/Bot (most centralized), OR
- Add a sibling check in the `ST_TargetAENoPlayersPets` filter site that excludes owned companions (most surgical).

**Architect lean:** Extend `IsPetOwnerOfClientBot()` is acceptable here because this filter's whole purpose is "is this entity a PC's pet for AoE protection." Treating an owned companion as equivalent for this filter's purposes follows the function's intent and only changes behavior in the right direction (fewer companion hits by detrimental AoE). The surgical alternative is acceptable if c-expert prefers it.

**Rationale:**
- **Two sites, not one:** Path 1 (`IsAttackAllowed`) catches the general case. Path 2 (`IsPetOwnerOfClientBot`) catches the specific `ST_TargetAENoPlayersPets` case that has its own filter ahead of the general `IsAttackAllowed` check. Without both, ST_TargetAENoPlayersPets AoE would still hit companions even after Path 1 is fixed.
- **Owner verification:** Both sites must verify the caster's CharacterID matches the companion's `m_owner_char_id`. Otherwise PVP scenarios would incorrectly protect ALL companions from ALL casters — only the OWNER's casts should be blocked.
- **Codebase precedent:** Cone AoE at `entity.cpp:5636` already has `IsCompanion()` exclusion. This fix replicates the pattern in two more AoE filter paths that the cone path doesn't cover.

**Confidence:** HIGH. Three-advisor convergence (c-expert C-2 + config-expert G-3 + data-expert D-3) on root cause; c-expert C-9 confirmed `members[]`/`membername[]` are not consulted by the relevant paths.

**Failure modes considered:**
- **Cross-owner exposure:** Verified via the `m_owner_char_id == caster CharacterID` check. Companions owned by OTHER players are not protected by these fixes (correct — that's PVP behavior preserved).
- **Companion-cast-on-Companion AoE:** Already handled by `Companion::IsAttackAllowed` override at `companion.cpp:832`. Untouched by this fix.
- **Buffer for buffs/heals:** This fix only affects the `_CLIENT vs _NPC` detrimental matrix and the `ST_TargetAENoPlayersPets` filter. Beneficial AoE casting (group heals, group buffs) goes through different paths (`SetAllowBeneficial(true)` at `companion.cpp:147`) and is not affected. Companions still receive group heals correctly.
- **C-10 (rez coexistence window):** During Fix C atomic-rez, corpse + new companion entity briefly coexist. A V3R-fixed AoE sweep during this window would now correctly skip the new companion (confirms it's owned by caster) but would still hit the corpse if it's a valid AoE target. Corpses are ST_Corpse-class, not detrimental-AoE-class, so this is a non-issue.

---

## 4. BUG-003 Empirical-First Workflow

**Bug addressed:** BUG-003 (companion HP/mana regen "1%/report").

**Approach:** No code change in V3R until empirical measurement runs. The 4-test V3R-Empirical-1 protocol from data-expert D-13 + config-expert G-11 Test 1.5 inserted is the gate.

**Protocol (full text in V3R Validation Plan section, summarized here):**

| Test | Setup | Expected outcome | Verdict |
|---|---|---|---|
| Test 1 | `#set mana_full` on Lashun. Sit. 4-cycle observation (60s total) | ≥100 mana per gsay report (~2% of 7907 pool) | If FAIL → run Test 1.5 |
| Test 1.5 | `UPDATE rule_values SET rule_value=175 WHERE rule_name='Companions:CompanionManaRegenMult'`; `#rules reload` (or `#rules set <Rule> <Value>` for transient test); re-run Test 1 | If now ≥100/report → rule bump fixes it | **Branch B-rule:** V3R fix is one rule UPDATE; no code change |
| Test 2 | `#set mana 0` on Lashun. Sit. Same 4-cycle observation | If similar to Test 1 → climb-from-zero is NOT slower | (Confirms misperception is not the explanation if Test 1 was already healthy) |
| Test 3 | Unsuspend Jimble + `#kill` Jimble + wait for auto-rez | If Jimble post-rez regen is slower than Test 2 | **Branch C:** rez path leaves degraded regen → escalate to c-expert |
| Test 4 (optional) | Repeat Test 1 with vs without active regen buffs | If significantly different → buff loss is contributing | **Branch D:** escalate to lua-expert (`!buffs` post-rez behavior) |

**Decision matrix:**

| Test 1 result | Test 1.5 result | Verdict | V3R action |
|---|---|---|---|
| ≥100/report | (skip) | **Branch B-misperception** | Close BUG-003 with runbook note. No V3R fix. |
| ≤50/report | ≥100/report | **Branch B-rule** | V3R fix is one rule UPDATE. **No code change.** |
| ≤50/report | ≤50/report | **Branch A** (or C, or D) | Escalate to c-expert (Branch A) or lua-expert (Branch D) or descope BUG-003 to follow-up bugfix |

**HP regen parallel question:** Pending config-expert follow-up 2 answer. If `Character:HPRegenMultiplier=200` (2x) has a similar gap to companion HP regen rules, the V3R rule fix may extend to a parallel HP regen bump.

**Why this approach:**
- **V3R Mandate 3 (empirical-first):** Required by the architecture mandates. Cannot ship a speculative code change for a bug whose root cause four advisors do not consider a code regression.
- **Highest-probability hypothesis is rule-only:** G-10 explains the user's "back to being extremely slow" framing as a tuning gap, not a refactor regression. Testing this without code change is a 5-minute SQL UPDATE + zone observation.
- **Branch routing keeps scope tight:** Each outcome maps to a clear next step. Branch A or D escalations would be a separate follow-up bugfix, not a V3R surface expansion.

---

## 5. Test Suite Additions

Four new failing-first tests in Suite 36 of `eqemu/zone/cli/tests/cli_companion_tests.cpp`.

| Test | Validates | Pre-fix | Post-fix |
|---|---|---|---|
| V.1 — `heartbeat_fires_for_dead_companion` | After Death and 5s tick wait, `m_ping_timer.Check()` should have fired (confirmed via mock or counter) | FAIL (Fix R4 bypasses heartbeat) | PASS (heartbeat unconditional after Fix V) |
| V.2 — `despawn_timer_fires_for_dead_companion` | After Death and >Companions:DeathDespawnS wait, auto-dismiss should have fired | FAIL (Fix R4 bypasses despawn timer check) | PASS (despawn timer unconditional after Fix V) |
| V.3 — `alive_companion_regen_regression_guard` | After 6s of alive sitting companion, mana should have increased per regen path | PASS (already correct pre-fix; this is a regression guard) | PASS (no change to alive companion path) |
| W.1 — `aoe_excludes_owner_companion` | Detrimental AoE cast by Client owner with companion in radius should NOT include companion in target list | FAIL (BUG-004 — companion is hit) | PASS (Fix W α excludes owned companion) |

Note: V.3 is structural — it's already-passing today, included as a regression guard so future refactors of `Companion::Process()` cannot silently break alive-companion regen.

---

## 6. Implementation Task Breakdown

| # | Task | Agent | Dependencies | Notes |
|---|---|---|---|---|
| V3R.1 | Write 4 failing-first tests in Suite 36: V.1 (heartbeat-for-dead), V.2 (despawn-timer-for-dead), V.3 (alive-regen-regression-guard), W.1 (aoe-excludes-owner-companion). Build the test binary; verify V.1, V.2, W.1 FAIL pre-fix and V.3 PASSES pre-fix. | c-expert | None | TDD red. Commit before any fix. |
| V3R.2 | Implement Fix V Option A: restructure `Companion::Process()` top-section. `bool is_dead = (GetHP() <= 0);` capture + `if (!is_dead)` guards on AI-dispatch sections (B.3, B.4, B.7, B.8, B.9, B.10, B.11). Keep B.1 heartbeat AND B.2 despawn timer UNCONDITIONAL. Reference c-expert enumeration B.1–B.11 for exact line guard mapping. | c-expert | V3R.1 | ~25 lines C++ in companion.cpp top-section of Process() |
| V3R.3 | Implement Fix W α: two-site `IsCompanion`-aware AoE exclusion. Site 1: `Mob::IsAttackAllowed` `_CLIENT vs _NPC` matrix in aggro.cpp — surgical insert checking `mob2->IsCompanion() && CastToCompanion()->GetOwnerCharacterID() == caster_char_id`. Site 2: `IsPetOwnerOfClientBot` extension in effects.cpp:1143-1145 OR a parallel sibling check in the `ST_TargetAENoPlayersPets` filter site. Reference codebase precedent at `entity.cpp:5636`. | c-expert | V3R.1 | ~10-15 lines C++ across 2 sites |
| V3R.4 | Rebuild zone binary (`docker exec ... ninja -j$(nproc)`). Re-run Suite 36 — verify V.1, V.2, W.1 now PASS, V.3 still PASS, all V1/V2 tests unchanged. Run full companion test suite. | c-expert | V3R.2, V3R.3 | runtime |
| V3R.5 | `make restart` + full server stack startup (loginserver / world / 8 dynamic zones per documented procedure). | infra-expert | V3R.4 | runtime |
| V3R.6 | In-game validation per V3R Validation Plan: 8 sustained-play scenarios + V3R-Empirical-1 4-test protocol for BUG-003. User confirms BUG-002 + BUG-005 + BUG-004 closed. BUG-003 outcome routes to one of: close-with-runbook (Branch B-misperception), rule UPDATE (Branch B-rule), c-expert escalation (Branch A), lua-expert escalation (Branch D), or descope to follow-up. | game-tester | V3R.5 | manual + sustained |
| V3R.7 | Architect decides BUG-003 follow-up scope based on V3R.6 results. Either: (a) close with no V3R action, (b) execute the one rule UPDATE for Branch B-rule, (c) file follow-up bugfix for Branch A/C/D. | architect | V3R.6 | analysis |
| V3R.8 | Commit and push V3R changes on `bugfix/companion-rez` in eqemu and claude repos. Includes: code commits for Fix V + Fix W + tests, the rule UPDATE if Branch B-rule confirmed, architecture and status updates. | c-expert | V3R.7 | git |

**Critical orchestration note:** The team-lead's brief explicitly states implementation does NOT proceed without explicit user approval after architecture-complete summary is sent. So the architect-complete summary (Task #12) is the gate before V3R.1 begins. The implementation team is NOT yet spawned.

**Spawn-list when implementation team is approved:**
- c-expert (V3R.1, V3R.2, V3R.3, V3R.4, V3R.8)
- infra-expert (V3R.5)
- game-tester (V3R.6)
- architect rejoins at V3R.7 (decision point)

Do NOT spawn lua-expert / data-expert / config-expert / protocol-agent — they have no V3R implementation tasks. Their Round 1/2/3 advisory work is complete.

**Conditional task injection:**
- If V3R.6 → Branch B-rule: insert `V3R.6.5 — data-expert: execute the rule UPDATE (`UPDATE rule_values SET rule_value='175' WHERE rule_name='Companions:CompanionManaRegenMult';`) + `#rules reload` (or `#rules set <Rule> <Value>` for transient test) + verify` BEFORE V3R.7.
- If V3R.6 → Branch A or D: V3R.7 routes to a separate follow-up bugfix branch with its own design + architecture phase.

---

## 7. Architecture Decisions Log (V3R)

| # | Decision | Rationale |
|---|---|---|
| V3R-D1 | Three independent root causes for BUG-002, BUG-003, BUG-004; not a shared V2 root cause | Three-advisor convergence in Round 1 (c-expert C-2 + config-expert G-3 + data-expert D-3 + lua-expert L-5). Working hypothesis refuted. |
| V3R-D2 | NEW BUG-005 discovered during enumeration: 30-minute auto-dismiss timer broken by Fix R4 | c-expert C-5 / B.2 finding. Same root cause as BUG-002, same fix as BUG-002 (zero additional surface). |
| V3R-D3 | BUG-002 + BUG-005 fix: Option A pattern (`bool is_dead` capture + `if (!is_dead)` guards on AI-dispatch only; heartbeat + despawn timer unconditional) | Identical to prior V3 plan's Option A but with despawn timer kept unconditional (the prior V3 plan implicitly required this but didn't enumerate it). Two-advisor convergence on shape. |
| V3R-D4 | BUG-004 fix shape α (narrow IsCompanion exclusion at IsAttackAllowed + IsPetOwnerOfClientBot) over β (SetOwnerID) over γ (Client-side override only) | β rejected for wide blast radius into pet/charm/buff/aggro/XP-split consumers (V3R Mandate violation). γ rejected as insufficient (does not address D.2 path). α follows codebase precedent at entity.cpp:5636. |
| V3R-D5 | BUG-003 empirical-first via D-13 4-test protocol + G-11 rule-bump as Test 1.5 | V3R Mandate 3 requires empirical measurement before code change. Strongest hypothesis (G-10 rule-tuning divergence) is testable without code change. Decision matrix routes each outcome to clear next step. |
| V3R-D6 | BUG-003 fix is conditional: Branch B-rule (rule UPDATE only) is the most likely outcome; Branch A/C/D escalate to follow-up bugfix | Per regression-discipline feedback: do not bundle speculative code changes with confirmed code changes. If empirical test reveals a code regression, scope a separate follow-up — do not expand V3R surface. |
| V3R-D7 | BUG-005 documented in V3R architecture section with discovery attribution; orchestrator owns BUG-005 report file creation | Per CLAUDE.md, the orchestrator (not architect) creates BUG-NNN report files. Architect surfaces the need in the architecture-complete summary. |
| V3R-D8 | C-10 (Fix C atomic-rez coexistence window) is theoretical only; flagged in Antagonistic review pass for game-tester awareness, no fix needed | Single-threaded zone tick eliminates real race. No advisor identified a path that doubles AoE damage during the rez moment. Validation can include "cast AoE during rez moment" as a sustained-play scenario. |
