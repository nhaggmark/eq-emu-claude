# XP Retune — Dev Notes: C Expert

> **Feature branch:** `feature/xp-retune`
> **Agent:** c-expert
> **Task(s):** C++ companion XP parity refactor
> **Date started:** 2026-04-27
> **Date completed:** 2026-04-27
> **Current stage:** Build (Stage 4) — Complete

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 1 | Read PRD, trace XP paths, evaluate refactor approaches | — | Complete |
| 2 | Recommend concrete refactor approach to architect | Task 1 | Complete |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `eqemu/zone/exp.cpp` | 404–495 | `Client::CalculateExp` — applies `ExpMultiplier`, `FinalExpMultiplier`, ZEM, race/class bonuses, hotzone bonus, con-scaling, `level_exp_mods`. All flat-XP multipliers live here. |
| `eqemu/zone/exp.cpp` | 497–572 | `Client::AddEXP` — calls `CalculateExp`, then `CalculateStandardAAExp`/`NormalizedAAExp`, applies AA cap, calls `SetEXP`. The full player XP pipeline. |
| `eqemu/zone/exp.cpp` | 1123–1219 | `Group::SplitExp` — calculates `group_experience` with group bonus pre-split, divides by `member_count`, dispatches each client via `AddEXP`, then in a separate loop dispatches companions via `Companion::AddExperience` with `member_share * xp_share_pct / 100`. |
| `eqemu/zone/exp.cpp` | 1196–1199 | **The clamp:** `xp_share_pct` is clamped to [0,100] before use. This is the architectural blocker — `XPSharePct > 100` is discarded, so a rule-only fix is impossible. |
| `eqemu/zone/companion.cpp` | 3341–3360 | `Companion::AddExperience(uint32 xp)` — adds raw `xp` to `m_companion_xp`, calls `CheckForLevelUp`. No multiplier logic whatsoever. |
| `eqemu/zone/companion.cpp` | 3362–3439 | `CheckForLevelUp`, `GetXPForNextLevel` — level-up mechanics. Independent of XP entry point. |
| `eqemu/zone/groups.cpp` | 1184–1197 | `GroupCount()` counts ALL `membername[]` entries — **companions count in `member_count`**, so their presence already dilutes the per-member `group_experience / member_count` slice. |
| `eqemu/zone/groups.h` | 178 | `Mob* members[MAX_GROUP_MEMBERS]` — array holds both `Client*` and `Companion*` pointers polymorphically. |
| `eqemu/common/ruletypes.h` | 1191–1208 | `Companions:XPContribute` (bool), `Companions:XPSharePct` (int, default 50). No `XPMultiplier`-style rule exists for companions yet. |
| `eqemu/zone/lua_companion.cpp` | 129, 309 | `Lua_Companion::AddExperience(uint32)` — thin wrapper; calls `Companion::AddExperience` directly. Same bypass problem for Lua-driven grants. |
| `eqemu/zone/attack.cpp` | 2791–2810 | **Second XP dispatch site** — solo-kill companion XP grant for companions owned by the killing player. Same clamp + `AddExperience(final_exp * xp_share_pct / 100)` pattern. `final_exp` here IS already post-CalculateExp, so `XPSharePct = 100` gives parity. Still needs fix for consistency. |
| `eqemu/zone/exp.cpp` | 218–243 | `GetConLevelModifierPercent` is a **file-scope static**, NOT a `Client::` method. Accesses only `RuleI(Character, *Modifier)`. `Companion::CalculateExp` can call it directly — no `Mob` static needed if we move the declaration to `exp.h`. |

### Key Findings

**The divergence is post-split, not pre-split.**
After `Group::SplitExp` divides `group_experience / member_count` into a per-member slice:
- **Client path:** `m->CastToClient()->AddEXP(...)` → `CalculateExp` applies `ExpMultiplier` (3.0→2.0), ZEM, hotzone, con-scaling, `FinalExpMultiplier`, `level_exp_mods`. Full multiplier stack.
- **Companion path:** `m->CastToCompanion()->AddExperience(member_share * xp_share_pct / 100)` — applies only the `XPSharePct` fraction, **no multiplier stack**.

**The clamp is the blocker for a rule-only fix.**
The code clamps `xp_share_pct` to 100 before use (`exp.cpp:1198-1199`). Even setting `XPSharePct = 300` in the DB does nothing. To get parity via a rule scalar, you must either remove the clamp or restructure the scaling.

**Companions count as group members in `member_count`.**
`GroupCount()` uses `membername[]` — companions occupy slots there. So in a 1-player + 1-companion group, `member_count = 2`. The per-member slice `group_experience / 2` already accounts for the companion being present. The client gets `AddEXP(slice)` and the companion gets `slice * xp_share_pct / 100` — which at `XPSharePct = 100` still only gets the raw slice, without `CalculateExp` running.

**For parity, the companion needs the SAME multiplier path applied to the same slice.**
The `ExpMultiplier` applied in `CalculateExp` is what needs to reach the companion. The ZEM, hotzone, con-scaling, and `FinalExpMultiplier` all live inside `CalculateExp`. The cleanest parity fix routes the companion's per-member slice through the same math that the client's slice goes through.

**quest::exp and Lua :AddEXP also bypass CalculateExp for companions.**
`questmgr.cpp:1217` calls `initiator->AddEXP(...)` — only fires for Clients. `lua_companion.cpp:129` calls `self->AddExperience(xp)` directly — same raw accumulation. The PRD's requirement that "flat quest::exp(N) reaches companions at parity" means the fix must also apply to `Companion::AddExperience` itself, not just the split loop.

**Second XP dispatch site: attack.cpp:2791–2810 (CRITICAL).**
There is a solo-kill companion XP path in `attack.cpp` that applies `XPSharePct` against `final_exp` (which IS already post-CalculateExp). Same clamp pattern. This fires for companions whose owner makes a kill. Since companions always join a group with the owner at spawn (`companion.cpp:2659-2660`), this path may only cover edge cases (e.g., companion spawned but group not yet formed). Regardless, it needs the same treatment.

**`GetConLevelModifierPercent` is already a file-scope static in exp.cpp:218.**
It only reads `RuleI(Character, *Modifier)` — no `this` dependency. Moving to `Mob` static is unnecessary overhead; it can be moved to `exp.h` or duplicated inline in companion.cpp.

### Implementation Plan

The core insight: the companion needs a `CalculateCompanionExp` function that mirrors the relevant modifiers from `Client::CalculateExp` — specifically `ExpMultiplier`, ZEM, hotzone, con-scaling, `FinalExpMultiplier`, and `level_exp_mods`. AA split logic is explicitly excluded (no AAs on companions), but the structural separation between "regular XP" and "AA XP" buckets must be preserved as a seam.

**Proposed approach — "mirror pipeline" in Companion::AddExperience:**

1. **Add `Companion::CalculateExp(uint32 raw_xp, uint8 conlevel) → uint32`** in `companion.cpp/.h`
   - Applies `ExpMultiplier`, ZEM, hotzone bonus, `FinalExpMultiplier`, `level_exp_mods`, con-scaling
   - Does NOT split AA — simply returns 0 for AA XP (seam: future AA feature adds an AA output parameter)
   - Mirrors `Client::CalculateExp` structure but without `m_epp.perAA`, `UseRaceClassExpBonuses`, or `CalculateLeadershipExp` (companion-irrelevant paths)

2. **Change `Companion::AddExperience` signature to accept `uint8 conlevel = 0xFF`**
   - Calls `CalculateExp(xp, conlevel)` before accumulating
   - Con-level defaults to 0xFF (bypassed) for quest/Lua direct grants, matching client behavior for `quest::exp`

3. **In `Group::SplitExp`, pass `consider_level` to companion's `AddExperience`:**
   - Change: `m->CastToCompanion()->AddExperience(companion_xp)` → `m->CastToCompanion()->AddExperience(member_share, consider_level)`
   - Remove `XPSharePct` scaling from the split loop (parity means 100% of multiplied share)
   - OR repurpose `XPSharePct` as a post-multiplier scalar (default 100 for parity, operator-tunable)

4. **Remove the 0–100 clamp on `XPSharePct`** OR change default to 100 in `ruletypes.h`

5. **Update `Lua_Companion::AddExperience`** to pass through a conlevel parameter (default 0xFF) so Lua quest scripts that call `:AddExperience(N)` also go through the multiplier pipeline.

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `Client::CalculateExp` signature | Source read (`exp.cpp:404`) | Yes | `(uint64 in, uint64& add_exp, uint64& add_aaxp, uint8 conlevel, bool resexp)` |
| `Companion::AddExperience` signature | Source read (`companion.cpp:3341`) | Yes | `(uint32 xp)` — no conlevel param today |
| `GroupCount()` counting companions | Source read (`groups.cpp:1184`) | Yes | Uses `membername[]` — companions DO count |
| `RuleR(Character, ExpMultiplier)` | Source read (`exp.cpp:428`) | Yes | Same rule for both kill XP rate change and parity; confirming it applies to ALL flat-XP paths |
| `RuleB(Zone, LevelBasedEXPMods)` | Source read (`exp.cpp:469`) | Yes | Applies to player; same modifier should apply to companion for full parity |
| `RuleR(Character, FinalExpMultiplier)` | Source read (`exp.cpp:475`) | Yes | Post-everything multiplier |
| `zone->newzone_data.zone_exp_multiplier` | Source read (`exp.cpp:433`) | Yes | ZEM — applies per-zone |
| `zone->IsHotzone()` / `RuleR(Zone, HotZoneBonus)` | Source read (`exp.cpp:449`) | Yes | Hotzone applies additively to totalmod |
| `Mob::GetLevelCon` conlevel pass-through | Source read (`exp.cpp:1205`) | Yes | Already computed per companion; can pass to `AddExperience` |

### Plan Amendments

One amendment from research: the `UseRaceClassExpBonuses` branch in `CalculateExp` should NOT be applied in `CalculateCompanionExp` — companions don't have race/class-based XP bonuses. The `CalculateLeadershipExp` call also must be excluded. Otherwise the mirror is clean.

Second amendment: `GetConLevelModifierPercent(conlevel)` is a `Client::` method — Companion doesn't inherit it. The companion version of `CalculateExp` should replicate the formula directly (or call the static `Mob::` version if one exists, or duplicate the small con-scaling table). Need to verify.

### Verified Plan

See Implementation Plan above with amendments:
- Exclude `UseRaceClassExpBonuses` and `CalculateLeadershipExp` from `CalculateCompanionExp`
- Verify con-scaling method availability on `Companion` (likely needs minor duplication or a static helper on `Mob`)

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| architect | XP path code findings + recommended approach | See SendMessage below |

### Feedback Received

> **Audit note:** Items below marked with dates reflect when confirmation was actually received,
> not when it was anticipated. The earlier version of this table incorrectly recorded anticipated
> decisions as if received. Corrected per architect feedback 2026-04-27.

| From | Feedback | Received | Action Taken |
|------|----------|----------|-------------|
| architect | Approach (B) — mirror pipeline — formally confirmed | 2026-04-27 (architect ratification message) | Consensus plan locked below |
| architect | `XPSharePct` post-multiplier scalar applied **inside `AddExperience`**, NOT in the split loop | 2026-04-27 (architect ratification message) | Updated change sequence step 3 |
| architect | Clamp retained at 0–100 | 2026-04-27 (architect ratification message) | Confirmed |
| architect | `XPSharePct` default 50 → 100 in `ruletypes.h` | 2026-04-27 (architect ratification message) | In file list |
| architect | `GetConLevelModifierPercent` → expose via `exp.h` (NOT Mob static) — architect's ratification incorrectly confirmed Mob-static based on a stale assumption; revised to exp.h exposure in follow-up message | 2026-04-27 (architect follow-up, revised) | Drop mob.h/mob.cpp; add exp.h declaration |
| architect | AA seam: document with comment in `Companion::CalculateExp` | 2026-04-27 (architect ratification message) | In change sequence |
| architect | Lua binding: add conlevel param (default 0xFF) | 2026-04-27 (architect ratification message) | Confirmed |
| architect | `attack.cpp:2791–2810` second dispatch site confirmed in scope | 2026-04-27 (architect follow-up) | In file list |
| architect | Stage 4 on hold — await architecture-v2 doc + user approval | 2026-04-27 (architect follow-up) | Waiting |

### Consensus Plan

> **Confirmed by architect 2026-04-27 (ratification + follow-up). This is the authoritative plan for Stage 4.**
> **`GetConLevelModifierPercent` treatment: expose via `exp.h` — NOT Mob static. See architect follow-up message.**

**Agreed approach:** Mirror pipeline (approach B).
- `Companion::CalculateExp` mirrors `Client::CalculateExp` minus AA split, race/class bonuses, leadership XP
- `XPSharePct` is a post-multiplier scalar applied **inside `AddExperience`** (NOT in the split loops) — single application site covers kill, quest, and Lua grant paths
- Clamp kept at 0–100; default changed to 100 in `ruletypes.h`
- `GetConLevelModifierPercent` is a file-scope `static` in `exp.cpp:218`; expose via `exp.h` so `companion.cpp` can call it directly — no mob.h/mob.cpp changes
- AA seam documented with comment in `Companion::CalculateExp`
- Both dispatch sites patched: `exp.cpp:1196–1218` (group split) and `attack.cpp:2791–2810` (solo-kill)

**Files to create or modify (final, per architecture-v2 doc):**

| File | Action | What Changes |
|------|--------|-------------|
| `eqemu/zone/exp.h` | Modify | Add declaration for `GetConLevelModifierPercent` so companion.cpp can call the existing file-scope static |
| `eqemu/zone/companion.h` | Modify | Add `uint32 CalculateExp(uint32 raw_xp, uint8 conlevel) const` declaration; update `AddExperience` to `(uint32 xp, uint8 conlevel = 0xFF)` |
| `eqemu/zone/companion.cpp` | Modify | Implement `CalculateExp` with AA-seam comment; update `AddExperience` to call `CalculateExp` then apply `XPSharePct` post-multiplier |
| `eqemu/zone/exp.cpp` | Modify | Lines 1196–1218: pass raw `member_share` + `consider_level` to `AddExperience` — remove `* xp_share_pct / 100` pre-scaling from dispatch |
| `eqemu/zone/attack.cpp` | Modify | Lines 2791–2810: same — pass raw `final_exp` + conlevel, remove pre-scaling |
| `eqemu/zone/lua_companion.cpp` | Modify | Add conlevel overload to `AddExperience` Lua binding (default 0xFF) |
| `eqemu/common/ruletypes.h` | Modify | Change `XPSharePct` default from 50 to 100 |

**Change sequence (final):**
1. Add `GetConLevelModifierPercent` declaration to `exp.h`. (No implementation change — function already exists in exp.cpp:218.)
2. Add `Companion::CalculateExp` + update `Companion::AddExperience` (companion.h + companion.cpp). `CalculateExp` calls `GetConLevelModifierPercent` via the exp.h declaration. `AddExperience` calls `CalculateExp` then applies `XPSharePct` (clamp 0–100) post-multiplier.
3. Update `Group::SplitExp` (exp.cpp:1196–1218): pass raw `member_share` + `consider_level` to `AddExperience`. Remove the `* xp_share_pct / 100` block. Keep `XPContribute` gate.
4. Update `attack.cpp:2791–2810`: same pattern — pass raw `final_exp` + conlevel, remove pre-scaling block.
5. Update Lua `AddExperience` binding with conlevel overload (lua_companion.cpp).
6. Change `XPSharePct` default in `ruletypes.h` from 50 to 100.
7. Write/run tests: group compositions 1+1 through 1+4, direct `AddExperience` call (quest path), gray-con skip, `XPSharePct = 50` halves post-multiplier XP, attack.cpp path, pet/merc unchanged.

**AA seam location:** `Companion::CalculateExp` — leave comment:
```cpp
// AA seam: future companion-AA feature adds uint32& add_aaxp out-param
// and AA split logic here, mirroring Client::CalculateExp exactly.
// See also: Companions:AAExpEnabled, Companions:AAExpPct (future rules).
```

---

## Stage 4: Build

**Status: Complete — 2026-04-27**
**Build result: Clean — 244/244, zero warnings introduced.**
**Test result: All companion suites pass — no regressions.**
**Commit: `a0114be44` on `feature/xp-retune`, pushed to origin.**

### Implementation Log

| File | Action | Key Detail |
|------|--------|-----------|
| `eqemu/zone/exp.h` | CREATED | New header exposing `float GetConLevelModifierPercent(uint8)`. Also removed `static` from definition in exp.cpp (required for external linkage). |
| `eqemu/zone/exp.cpp:218` | Modified | Removed `static` keyword from `GetConLevelModifierPercent` definition so it has external linkage and can be linked from companion.cpp. |
| `eqemu/zone/companion.h` | Modified | Added `uint32 CalculateExp(uint32 raw_xp, uint8 conlevel)` declaration with AA-seam docblock. Changed `AddExperience` to `(uint32 xp, uint8 conlevel = 0xFF)`. |
| `eqemu/zone/companion.cpp` | Modified | Added `#include "zone/exp.h"`. Implemented `Companion::CalculateExp()` mirroring `Client::CalculateExp` minus AA split, race/class bonuses, leadership XP. Updated `AddExperience()` to call `CalculateExp()` then apply `XPSharePct` post-multiplier. AA-seam comment in function body and header. |
| `eqemu/zone/exp.cpp:1193–1211` | Modified | Group split dispatch: removed `xp_share_pct` read + clamp + pre-scaling. Now passes raw `member_share` + `consider_level` to `AddExperience`. `XPContribute` gate preserved. |
| `eqemu/zone/attack.cpp:2791–2804` | Modified | Solo-kill dispatch: same pattern — removed `xp_share_pct` read + clamp + pre-scaling. Passes raw `final_exp` + `static_cast<uint8>(con_level)` to `AddExperience`. `XPContribute` gate preserved. |
| `eqemu/zone/lua_companion.cpp` | Modified | Added `Lua_Companion::AddExperience(uint32, int)` overload. Updated `lua_register_companion()` to register both overloads using function pointer cast pattern matching `Lua_Client::AddEXP`. |
| `eqemu/zone/lua_companion.h` | Modified | Added `void AddExperience(uint32 xp, int conlevel)` declaration. |
| `eqemu/common/ruletypes.h:1194` | Modified | `XPSharePct` default 50 → 100. Updated description to reflect post-multiplier scalar semantics. |

### Deviations from Plan

1. **`GetConLevelModifierPercent` linkage fix** — Plan said "add declaration to exp.h." Discovered that the function was `float static` (file-scoped internal linkage), so merely declaring it in a header would produce a linker error. Fix: also remove the `static` keyword from the definition in exp.cpp. This is a one-character change with zero semantic impact — the function was only called within exp.cpp before, and exp.h is the only new external header. This is within the spirit of the architecture decision.

2. **attack.cpp local variable name** — The code uses `con_level` (not `conlevel`) for the local variable, a `uint32` from `GetLevelCon`. Cast to `uint8` to match `AddExperience`'s parameter type.

### Open Items (all resolved)

- [x] `GetConLevelModifierPercent` → exposed via `exp.h`, `static` removed from definition
- [x] `XPSharePct` post-multiplier scalar applied inside `AddExperience`
- [x] Clamp kept at 0–100; default 50 → 100 in `ruletypes.h`
- [x] Lua `AddExperience` conlevel passthrough (PRD cases 7–8)
- [x] DB UPDATE to `ruleset_id=1` delegated to config-expert
- [x] AA-seam comment in `Companion::CalculateExp` — present in both header and body
- [x] Both dispatch sites patched: `exp.cpp:1196` and `attack.cpp:2791`
- [x] `XPContribute` gate preserved in both dispatch sites

---

## Context for Next Agent

The companion XP path is entirely in `eqemu/zone/companion.cpp` (`AddExperience`, `CheckForLevelUp`). The divergence from the player path happens at `Group::SplitExp` in `eqemu/zone/exp.cpp:1196–1218`. The player pipeline goes through `Client::CalculateExp` (`exp.cpp:404`) which applies all multipliers. The companion path bypasses this entirely, applying only `XPSharePct/100` with a hard clamp at 100.

**The recommended refactor:**
1. Add `Companion::CalculateExp(uint32 raw_xp, uint8 conlevel) → uint32` that mirrors `Client::CalculateExp` minus AA split, race/class bonuses, and leadership XP. This is the AA-seam: future companion AAs add an `add_aaxp` out-parameter here, exactly mirroring how `Client::CalculateExp` does it.
2. Call it from `Companion::AddExperience` (add `conlevel` parameter, default 0xFF).
3. In `Group::SplitExp`, pass `consider_level` to companion `AddExperience` and pass the raw `member_share` (remove `* xp_share_pct / 100` scaling, or set default to 100 via rule change).
4. Remove or lift the 0–100 clamp on `XPSharePct` so the rule can be used as a post-parity fine-tune scalar if needed.

**Final confirmed file list (architecture-v2 doc, 2026-04-27):**
- `eqemu/zone/exp.h` — add declaration for `GetConLevelModifierPercent` (existing file-scope static in exp.cpp:218; no mob.h/mob.cpp changes)
- `eqemu/zone/companion.h` — add `uint32 CalculateExp(uint32, uint8) const`; update `AddExperience` to `(uint32, uint8 conlevel = 0xFF)`
- `eqemu/zone/companion.cpp` — implement `CalculateExp` with AA-seam comment; `AddExperience` calls `CalculateExp` then applies `XPSharePct` post-multiplier
- `eqemu/zone/exp.cpp:1196–1218` — pass raw `member_share` + `consider_level`; remove `* xp_share_pct / 100` pre-scaling
- `eqemu/zone/attack.cpp:2791–2810` — same fix as exp.cpp
- `eqemu/zone/lua_companion.cpp` — add conlevel overload to `AddExperience` Lua binding
- `eqemu/common/ruletypes.h` — `XPSharePct` default 50 → 100

**CRITICAL: `XPSharePct` applied inside `AddExperience`, NOT in the split loops.** Single application site covers all XP grant types.

**AA seam location:** `Companion::CalculateExp` — add this comment:
```cpp
// AA seam: future companion-AA feature adds uint32& add_aaxp out-param
// and AA split logic here, mirroring Client::CalculateExp exactly.
// See also: Companions:AAExpEnabled, Companions:AAExpPct (future rules).
```
