# XP Retune — Dev Notes: C Expert

> **Feature branch:** `feature/xp-retune`
> **Agent:** c-expert
> **Task(s):** C++ companion XP parity refactor (architecture phase — planning only)
> **Date started:** 2026-04-27
> **Current stage:** Socialize (Stage 3)

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

| From | Feedback | Action Taken |
|------|----------|-------------|
| (awaiting architect response) | | |

### Consensus Plan

_Pending architect response. Implementation Plan above is the c-expert recommendation._

---

## Stage 4: Build

_Not started. Planning phase only._

---

## Open Items

- [ ] Verify `GetConLevelModifierPercent` is `Client`-only or has a `Mob`-level static equivalent
- [ ] Confirm architect's decision: remove XPSharePct clamp, or repurpose as post-multiplier scalar, or add new `XPMultiplier` rule for companions
- [ ] Confirm `Lua_Companion::AddExperience` binding needs conlevel passthrough for quest parity (PRD requirement case 7–8)
- [ ] Architect decision: should XPSharePct default change from 50 to 100 in `ruletypes.h`, or is the SQL update sufficient?

---

## Context for Next Agent

The companion XP path is entirely in `eqemu/zone/companion.cpp` (`AddExperience`, `CheckForLevelUp`). The divergence from the player path happens at `Group::SplitExp` in `eqemu/zone/exp.cpp:1196–1218`. The player pipeline goes through `Client::CalculateExp` (`exp.cpp:404`) which applies all multipliers. The companion path bypasses this entirely, applying only `XPSharePct/100` with a hard clamp at 100.

**The recommended refactor:**
1. Add `Companion::CalculateExp(uint32 raw_xp, uint8 conlevel) → uint32` that mirrors `Client::CalculateExp` minus AA split, race/class bonuses, and leadership XP. This is the AA-seam: future companion AAs add an `add_aaxp` out-parameter here, exactly mirroring how `Client::CalculateExp` does it.
2. Call it from `Companion::AddExperience` (add `conlevel` parameter, default 0xFF).
3. In `Group::SplitExp`, pass `consider_level` to companion `AddExperience` and pass the raw `member_share` (remove `* xp_share_pct / 100` scaling, or set default to 100 via rule change).
4. Remove or lift the 0–100 clamp on `XPSharePct` so the rule can be used as a post-parity fine-tune scalar if needed.

**Files to modify:**
- `eqemu/zone/companion.h` — add `CalculateExp` declaration, update `AddExperience` signature
- `eqemu/zone/companion.cpp` — implement `CalculateExp`, update `AddExperience`
- `eqemu/zone/exp.cpp:1196–1218` — pass `member_share` (not scaled) and `consider_level` to `AddExperience`; remove/lift clamp
- `eqemu/zone/lua_companion.cpp` — update `AddExperience` binding for conlevel passthrough

**AA seam location:** `Companion::CalculateExp` — future companion-AA feature adds `uint32& add_aaxp` out-parameter and AA split logic here, exactly parallel to `Client::CalculateExp`. No other files need touching for the AA seam.
