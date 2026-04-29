# Round 2 — Joint Root-Cause Synthesis

> **Date:** 2026-04-29
> **Architect:** V3R architect (this session)
> **Inputs:** Round 1 advisor enumerations from c-expert, lua-expert, config-expert, data-expert (4 of 5 fully closed); protocol-agent pre-findings P-1/P-2/P-3 covering substantive packet-layer needs (formal structured enumeration outstanding but not blocking)
> **Purpose:** Synthesize Round 1 enumerations into a unified root-cause picture across all four bugs (BUG-002, BUG-003, BUG-004, BUG-005). Serves as input to Round 3 fix design and Task #10 (architecture.md V3R section).

---

## 1. Working Hypothesis Refutation

**Initial working hypothesis (per V3R brief and the user's correlation observation):**
> "All three bugs share a root cause in V2's entity-registration / Spawn-pipeline changes. V2's Fix B routed `ResurrectFromCorpse` through `Spawn(owner)` and Fix A cleared `membername[]` slot at Death. Downstream subsystems that consume customized companion entity-list metadata, group-membership state, or owner-pointer ownership may have been silently affected."

**Round 2 verdict: REFUTED by three-advisor convergence.**

| Advisor finding | What it refutes | Evidence |
|---|---|---|
| c-expert C-2 + C-9 | The hypothesis that group-membership state ties BUG-004 to Fix A | `Mob::IsAttackAllowed` does NOT call `IsGroupMember`/`SameGroup` on the `_CLIENT vs _NPC` path. The `_NPC(x) = x->IsNPC() && !x->GetOwnerID()` matrix doesn't consult group state at all. **Fix A is irrelevant to BUG-004.** |
| lua-expert L-5 | The hypothesis that Fix A's `membername[]` clear affects any Lua-callable path | `Group::members[]` (Mob* pointer array) and `Group::membername[]` (char[64] string array) are SEPARATE arrays. `HandleGroupChatMentions` walks `members[]`. Fix A clears only `membername[]`. No Lua-callable consumer reads `membername[]`. |
| data-expert D-3 + D-2 | The hypothesis that V2's Spawn(owner) changed pet-system ownership | Companions don't use the `character_pet_*` tables at all. The companion system is PARALLEL to the pet system, not derived. Companion group membership has ZERO DB persistence. So V2 could not have orphaned a DB row that downstream consumers read back. |
| All four advisors (C-3, L-1, G-5, D-9) | The hypothesis that BUG-003 regen is a V2 code regression | Four independent reads converge: alive-companion regen code path is unchanged by V2. `NPC::Process()` regen branch is intact; `Companion::CalcManaRegen` and sitting-regen bonus block are intact; gsay reporting is C++-driven by `m_mana_report_timer` (untouched by V2). |

**Refined verdict:** Three independent root causes for the three originally reported bugs, plus one fourth bug (BUG-005) discovered by the enumeration that shares root cause with BUG-002.

---

## 2. Per-Bug Root Cause Lock

### BUG-002 — Visibility Heartbeat Regressed in Combat

**Root cause:** V2 Fix R4 early-return at `companion.cpp:1933-1935` for HP<=0 entities calls `return NPC::Process()` immediately, bypassing the `m_ping_timer` heartbeat block at `companion.cpp:2128-2142`. Without periodic `SentPositionPacket(0,0,0,0,0)` keepalive, the Titanium client culls the stationary entity from its render set after ~5-10 seconds of no position packets.

**Advisor convergence:** Two-advisor lock.
- c-expert C-1 (B.1 enumeration entry) — code-grounded trace from Fix R4 site to heartbeat block
- protocol-agent P-1 — independently confirmed Titanium culling behavior on `PlayerPositionUpdateServer_Struct` cessation; identified the prior fix at commit `9e4b7dfd1` (2026-03-09) that introduced the `m_ping_timer(5000)` keepalive

**V2 touchpoint:** Fix R4 (single-fix attribution).

**Manifestation window:** From companion's first HP<=0 tick until either rez OR auto-dismiss. During that window, the dead-but-still-corpse-visible companion entity has stopped emitting position packets → Titanium culls it → user perceives "vanished from screen during combat."

**Why it didn't surface in V2 brief encounters:** Fix R4 was added as a defense-in-depth alive-guard for the dead-cleric-self-rez edge case. Its blast-radius into the heartbeat block was not enumerated in the V2 architecture phase. Brief test scenarios that did not include sustained dead-companion observation did not surface the regression.

---

### BUG-005 — Auto-Dismiss Timer Broken for Dead Companions (NEWLY DISCOVERED)

**Root cause:** Same Fix R4 early-return that breaks BUG-002 ALSO bypasses `m_death_despawn_timer.Check()` at `companion.cpp:1938-1964`. Since `m_death_despawn_timer` is a Companion-class member, `NPC::Process()` has no knowledge of it. The 30-minute `Companions:DeathDespawnS` auto-dismiss is therefore not enforced for dead-not-rezzed companions.

**Advisor attribution:** Single-advisor discovery (c-expert C-5 / B.2). Confidence: 90%. Round 2 antagonistic pass should verify there is no `NPC::Process()` path that fires the timer indirectly.

**V2 touchpoint:** Fix R4 (same as BUG-002).

**Why it didn't surface in V2 testing:** Brief test scenarios did not include 30+ minute dead-companion observation. The timer-fires-but-not-checked failure mode is silent (no error message), only detectable by absence of expected auto-dismiss after the configured TTL.

**Critical relationship to BUG-002:** Same root cause as BUG-002 → same fix as BUG-002. Both are addressed by the Option A restructure of `Companion::Process()` top-section that keeps both blocks (heartbeat + despawn timer) unconditional while wrapping AI-dispatch in `if (!is_dead)` guards.

---

### BUG-004 — Player Harmful AoE Hits Own NPC Companions

**Root cause:** PRE-EXISTING gap (NOT a V2 regression). Companions never call `SetOwnerID()` — they use custom `m_owner_char_id` tracking which is invisible to the standard pet-ownership chain. Two independent paths in the AoE filter consult the standard ownership state:

1. **Path 1 — `Mob::IsAttackAllowed` base function (aggro.cpp:732+):**
   - `_NPC(x) = x->IsNPC() && !x->GetOwnerID()` returns true for companions (because `GetOwnerID()=0`)
   - Client-vs-NPC matrix branch returns `true` unconditionally → client allowed to attack companion
   - Used by `EntityList::AESpell()` detrimental filter at `effects.cpp:1198-1201`

2. **Path 2 — `IsPetOwnerOfClientBot()` filter for `ST_TargetAENoPlayersPets` (effects.cpp:1143-1145):**
   - Checks `pet_owner_bot || pet_owner_client` flags set via `SetOwnerID()` chain
   - Companions never set these flags → companions transparent to this filter
   - SECOND independent path by which companions get hit by AoE supposed to skip PC pets

**Advisor convergence:** Three-advisor lock plus one cross-validation.
- c-expert C-2 + C-9 + D.1/D.2/H.1 — code-grounded trace through `IsAttackAllowed` and `IsPetOwnerOfClientBot`
- config-expert G-3 + G-4 — independently identified `GetOwner()` requires `GetPetID()==GetID()` which companions don't satisfy; also surfaced existing codebase precedent at `entity.cpp:5636` (cone AoE `IsCompanion()` exclusion)
- data-expert D-3 + D-4 — DB-layer confirmation that companions are PARALLEL to pet system, not derived; faction-based exclusion is not viable (no "companion" faction)
- lua-expert L-5 cross-check answered by c-expert C-9: AoE filter does NOT consult group `members[]`, so Fix A is irrelevant to BUG-004

**V2 touchpoint:** None directly. V2 Fix B (Spawn(owner) reroute) MAY have made rezzed companions more reliably present in entity-list, exposing the pre-existing gap more consistently post-rez than before V2 — but the gap predates V2.

**Why it surfaced in the V2 regression-family report window:** User correctly observed correlation with V2 (saw the bug after V2 landed). The correlation is real but the causation is exposure, not introduction. Pre-V2, rezzed companions had unreliable entity-list registration, which intermittently masked the bug. V2 made registration correct, surfacing the latent gap.

**Fix-shape decision (locked):** α (narrow `IsCompanion`-aware exclusion) over β (SetOwnerID with wide blast radius) and γ (Client-side override only).

| Shape | Surface | Why preferred / rejected |
|---|---|---|
| α | Two C++ checks: aggro.cpp `_NPC` matrix + effects.cpp `ST_TargetAENoPlayersPets` filter | **PREFERRED.** Codebase precedent exists at entity.cpp:5636. Surface stays narrow (2 sites). Follows project's existing IsCompanion-exclusion pattern. |
| β | One change: companions call `SetOwnerID(owner_entity_id)` during Spawn(owner) | **REJECTED.** Wide blast radius into pet/charm/buff/aggro/XP-split consumers. Direct violation of V3R Architecture Mandate principle of minimum blast radius. Many consumers would now suddenly see non-zero `GetOwnerID()` for companions for the first time. |
| γ | Client::IsAttackAllowed override mirroring Companion::IsAttackAllowed | **INSUFFICIENT.** Only addresses Path 1; does not fix Path 2 (`IsPetOwnerOfClientBot`). |

---

### BUG-003 — Companion HP/Mana Regen Drastically Slowed

**Root cause:** Most likely **rule-tuning divergence**, NOT a V2 code regression. Detailed hypothesis branches:

- **Branch (a) — Actual server-side regen broken at code level:** RANKED LOW. Four-advisor convergence (c-expert C-3 + C-8, lua-expert L-1, config-expert G-5, data-expert D-9) confirms regen code path is unchanged by V2. No code path identified that gates regen on V2-touched state.
- **Branch (b) — Misperception / freshly-rezzed climb from 0 mana:** PLAUSIBLE. Confirmed consistent with the math (level 54 cleric with `meditate=295` and `Companions:AlwaysMeditateRegen=true` produces ~36-63 mana/tick; against a 7907 max_mana pool, "1%/report" matches a fresh-from-zero observation). data-expert D-1 + D-9 frames this.
- **Branch (c) — Indirect via buff loss (lua-expert L-8):** PLAUSIBLE-LOW. If `!buffs` was applying regen-boosting buffs pre-death, AND Fix A breaks group membership in a way `!buffs` post-rez fails, AND those buffs are missing → perceived slow regen. Testable via D-13 Test 4. data-expert D-6 confirms `companion_buffs` table is empty (zero buff persistence).
- **Branch (d) — RULE-TUNING DIVERGENCE (config-expert G-10):** RANKED HIGHEST. Player has `Character:ManaRegenMultiplier=175` (1.75x), but companions have `Companions:CompanionManaRegenMult=100` (no scaling). The structural 1.75x gap explains the user's "back to being extremely slow" framing as a long-term tuning gap that finally became visible, NOT as a V2 refactor regression. **Testable WITHOUT any code change.**

**Advisor convergence:** Four-advisor agreement on (a) being unlikely; config-expert independently surfaced (d) with strongest explanation power.

**V2 touchpoint:** None directly identified. The user's perceived correlation with V2 may be coincidental — the user noticed sustained-sit regen as an issue when sustained-sit play patterns increased post-V2 (because rez was now reliable, leading to longer adventures and more sit-down windows).

**Empirical-first gate (per V3R Mandate 3):** Resolved via the data-expert D-13 four-test scenario plus config-expert G-11 rule-bump inserted as Test 1.5. Decision matrix:

| Test 1 (current rules) | Test 1.5 (rule bump) | Verdict | V3R action |
|---|---|---|---|
| ≥100/report | (skip 1.5) | Branch (b) misperception | Close BUG-003 with runbook note. **No V3R fix.** |
| ≤50/report | ≥100/report | Branch (d) rule-tuning divergence | V3R fix is one rule UPDATE: `Companions:CompanionManaRegenMult` 100 → 175. **No code change.** |
| ≤50/report | ≤50/report | Branch (a) or (c) confirmed | Escalate to c-expert C++ investigation OR descope BUG-003 to follow-up bugfix. |

**HP regen parallel question (config-expert follow-up 2):** Does `Character:HPRegenMultiplier=200` (2x) have a similar gap to `Companions:OOCRegenPct=5` + `Companions:HPRegenPerTic=1`? Pending config-expert answer. If so, V3R rule fix may extend to a parallel HP regen rule bump.

---

## 3. Cross-Bug Synthesis

### Three Independent Fix Surfaces (Plus Optional Rule)

| Bug | Fix surface | Code/config |
|---|---|---|
| BUG-002 | `Companion::Process()` top-section restructure | C++ (1 site) |
| BUG-005 | (same as BUG-002) | C++ (0 additional sites — solved by BUG-002 fix) |
| BUG-004 | Mob::IsAttackAllowed + IsPetOwnerOfClientBot ST_TargetAENoPlayersPets path | C++ (2 sites) |
| BUG-003 | Empirical test → likely 1 rule UPDATE; possibly C++ if branches (a) or (c) confirmed | Conditional |

### Why the Working Hypothesis was Wrong

The user observed all three bugs in the same window after V2 landed. That correlation is real and was a reasonable basis for the initial hypothesis. The three-bug-share-root-cause framing collapsed in Round 2 because:

1. **BUG-002 ↔ BUG-004 share NO surface.** BUG-002 is in `Companion::Process()` AI tick loop. BUG-004 is in `Mob::IsAttackAllowed` AoE filter. Different functions, different files, different consumers.
2. **BUG-003 root cause is at a different layer entirely** (likely rule values, not code).
3. **The shared correlation is "V2 reduced the noise floor for dead-companion behavior."** Pre-V2, rez was unreliable. Players never saw a rezzed companion in sustained play. V2 made rez reliable. With reliable rez, sustained-play patterns increased, which exposed:
   - The latent BUG-002 / BUG-005 (both in dead-entity Process tick path that V2's Fix R4 broke for the first time during sustained dead-companion windows)
   - The latent BUG-004 (in AoE filter that pre-existed but was masked by intermittent rez registration)
   - The user's growing awareness of BUG-003 perception (sustained sit-down windows became more common)

The V2 changes did not introduce all three bugs. **V2 reduced the masking, surfacing pre-existing or independently-introduced issues.**

### Antagonistic Pass — Items to Verify in Round 3 / Validation

- **C-10 (E.5 coexistence window):** During Fix C atomic-rez, corpse + new companion entity briefly coexist. Theoretical AoE-sweep race could double-hit. Practical risk: low (zone is single-threaded). Validation plan should include: cast AoE during the rez moment specifically and observe.
- **C-6 / G-9 cross-reference:** Does companion regen exercise the base `NPC:OOCRegen=1` path or the custom `Companions:OOCRegenPct` path? c-expert C-9 Q3 indicates "no path found that depends on owner/group/V2 state" but didn't fully resolve the layer ordering. Empirical Test 1 + Test 1.5 will give signal — if Test 1.5 (CompanionManaRegenMult bump) doesn't help but `NPC:OOCRegen=0` does, companions are on the wrong code path.
- **L-8 buff-state branch:** Test 4 in D-13 covers it. Listed as low probability but enumerable.

### Round 2 Open Items Pending

- **protocol-agent formal enumeration:** Outstanding. Pre-findings P-1/P-2/P-3 cover substantive needs. Formal enumeration would add depth on (B) group/raid display packet diff between V2 paths and (F) Spawn-struct fields. Not blocking Round 3.
- **c-expert git audit of `CompanionManaRegenMult` history:** Pending. Documentation-only; not load-bearing for fix design.
- **config-expert HP regen parallel question:** Pending. Affects whether V3R rule fix includes HP regen bump.
- **data-expert SQL column name verification (`owner_id` vs `owner_char_id`):** Pending. Affects validation plan SQL snippet correctness.
