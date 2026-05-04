# Universal Summon Corpse Spell — Dev Notes: C Expert

> **Feature branch:** `feature/summon-corpse-spell`
> **Agent:** c-expert
> **Task(s):** Task 4
> **Date started:** 2026-05-03
> **Current stage:** Build (Stage 4)

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 4 | Add `m_summon_corpse_was_noop` flag (mob.h); set in SummonCorpse no-corpse branch (spell_effects.cpp:1851); read in recast block (spells.cpp:2817-2841) gated on `spell_category == kUniversalSummonCorpseCategory`; add `RuleI(Spells, UniversalSummonCorpseCooldown)` override in same block | Tasks 1, 2 | In Progress |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `eqemu/zone/spell_effects.cpp` | 1793–1868 | `case SpellEffect::SummonCorpse` handler. No-corpse branch is `else { MessageString(Chat::LightBlue, CORPSE_CANT_SENSE); }` at line 1849–1852. The flag set must be gated on `TargetClient == CastToClient()` (self-targeting only) — existing NEC/SHM cross-player summon-corpse no-ops must NOT skip their cooldown. |
| `eqemu/zone/spells.cpp` | 2817–2841 | `else if (spells[spell_id].recast_time > 1000 && !spells[spell_id].is_discipline)` block. `recast = spells[spell_id].recast_time/1000`. Standard LAY_ON_HANDS/HarmTouch deductions, then focus reduction, then `if (recast > 0) CastToClient()->GetPTimers().Start(pTimerSpellStart + spell_id, recast)`. The `recast > 0` guard already exists — setting `recast = 0` for a noop case skips timer.Start cleanly. |
| `eqemu/zone/mob.h` | 1743–1758 | `//spell casting vars` section with `casting_spell_id`, `casting_spell_slot`, etc. Best insertion point is after `casting_spell_checks` and `bardsong` members in this block (around line 1758). |
| `eqemu/common/ruletypes.h` | 540–549 | Last few rules before `RULE_CATEGORY_END()` at line 549. `UniversalSummonCorpseCooldown` NOT YET PRESENT — config-expert task 1 is not complete. |

### Key Findings

1. **No-corpse path** at `spell_effects.cpp:1851` is the simple `else` after the `if (corpse)` check at line 1841. The flag set is 3 lines: an `if (TargetClient == CastToClient())` guard wrapping `m_summon_corpse_was_noop = true;`.

2. **Recast block ordering** is correct for the flag-read approach: `SpellFinished` calls `SpellOnTarget` → `Mob::SpellEffect` (where the SummonCorpse case fires and sets the flag) BEFORE the `recast_time > 1000` block at line 2817. The flag is readable there.

3. **`recast > 0` guard already present** at line 2838. Setting `recast = 0` in the noop case correctly skips `GetPTimers().Start()` without additional branching.

4. **`spell_category` discriminator:** Architecture specifies a `static const int kUniversalSummonCorpseCategory` local constant inside the recast block. Value is assigned by data-expert (task 2). Must coordinate before finalizing the spells.cpp edit.

5. **Rule macro dependency:** `RuleI(Spells, UniversalSummonCorpseCooldown)` requires config-expert's `RULE_INT` line in `ruletypes.h` to compile. Task 1 is not yet complete. I can implement mob.h + spell_effects.cpp (no rule dependency) immediately. The spells.cpp recast block edit requires both tasks 1 and 2 to be complete.

### Implementation Plan

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `eqemu/zone/mob.h` | Modify | Add `bool m_summon_corpse_was_noop{false};` in `//spell casting vars` section |
| `eqemu/zone/spell_effects.cpp` | Modify | In the no-corpse `else` at ~line 1851, add `if (TargetClient == CastToClient()) { m_summon_corpse_was_noop = true; }` |
| `eqemu/zone/spells.cpp` | Modify | In the `recast_time > 1000` block, after the `int recast = ...` assignment, add the `spell_category` discriminator block that (a) applies the rule override and (b) clears the noop flag and zeroes `recast` if set |

**Change sequence:**
1. Add flag to `mob.h` (no dependencies)
2. Set flag in `spell_effects.cpp` (depends only on mob.h)
3. Wait for config-expert task 1 + data-expert task 2 confirmation
4. Add rule override + noop check to `spells.cpp`
5. Build and verify

**What to test:**
- Build succeeds (ninja, no errors)
- No-corpse self-cast: cooldown NOT triggered
- Corpse present self-cast: cooldown triggered normally
- Cross-player NEC/SHM no-op cast: cooldown still triggered (not in scope of flag)
- Rule `Spells:UniversalSummonCorpseCooldown` value respected at cast time

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `spells[spell_id].spell_category` field access | Source read: `eqemu/zone/spells.cpp:2817-2841` uses `spells[spell_id].recast_time`, `spells[spell_id].is_discipline` — same pattern | Yes | `spell_category` is `int16` per `spdat.h` |
| `m_summon_corpse_was_noop{false}` in-class initializer | C++20 standard; pattern confirmed by `bool m_hold_combat_position = false;` at mob.h:1557 | Yes | Use `{false}` to match nearby members |
| `RuleI(Spells, CategoryName)` | Confirmed pattern from architecture: `RuleI(Spells, TranslocateTimeLimit)` at ruletypes.h:432 | Yes | Returns int; default returned if DB row absent |
| `static const int kUniversalSummonCorpseCategory` | Architecture doc §Code Changes | Yes | Local constant inside `else if` block; value from data-expert |

### Plan Amendments

Plan confirmed — no amendments needed. The mob.h and spell_effects.cpp edits can proceed immediately. The spells.cpp edit waits on config-expert (task 1) and data-expert (task 2).

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| config-expert | Task 1 status check | Is `RULE_INT(Spells, UniversalSummonCorpseCooldown, 180, ...)` registered in ruletypes.h yet? |
| data-expert | Task 2 status check | What is the final `spell_category` integer value for the 12 new spells? |

### Feedback Received

_Pending replies — proceeding with mob.h + spell_effects.cpp edits while waiting._

### Consensus Plan

**Agreed approach:** Implement in two phases:
- Phase A (no dependencies): mob.h flag declaration + spell_effects.cpp flag-set
- Phase B (after task 1 + task 2): spells.cpp recast block rule override + noop check

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `eqemu/zone/mob.h` | Modify | Add `bool m_summon_corpse_was_noop{false};` in spell casting vars block |
| `eqemu/zone/spell_effects.cpp` | Modify | Set flag in no-corpse else branch, gated on `TargetClient == CastToClient()` |
| `eqemu/zone/spells.cpp` | Modify | Rule override + noop check in recast block, gated on `spell_category == kUniversalSummonCorpseCategory` |

**Change sequence (final):**
1. mob.h: add bool member
2. spell_effects.cpp: set flag in no-corpse branch
3. spells.cpp: add rule override + noop check (after task 1 + task 2 complete)
4. Build all three together

---

## Stage 4: Build

### Implementation Log

#### 2026-05-03 — Phase A: mob.h flag declaration

**What:** Added `bool m_summon_corpse_was_noop{false};` to the spell casting vars section in `mob.h`.
**Where:** `eqemu/zone/mob.h`, after `casting_spell_checks` in the `//spell casting vars` block (~line 1758)
**Why:** Provides the per-Mob transient state the SummonCorpse handler needs to signal a no-op to the recast block. In-class initializer `{false}` ensures the flag is always false on construction, preventing stale state.
**Notes:** Flag only set true when `TargetClient == CastToClient()` in spell_effects.cpp (self-targeting). Always reset to false when read in spells.cpp recast block.

#### 2026-05-03 — Phase A: spell_effects.cpp no-corpse branch flag-set

**What:** Added `m_summon_corpse_was_noop = true;` inside the no-corpse `else` branch, gated on `TargetClient == CastToClient()`.
**Where:** `eqemu/zone/spell_effects.cpp`, the `else` block at ~line 1849 (after `if (corpse)` check at ~line 1841)
**Why:** Only self-targeting no-ops should skip the cooldown. Cross-player NEC/SHM summon-corpse no-ops must still consume the cooldown (existing behavior preserved).

#### 2026-05-03 — Phase B: spells.cpp rule override + noop check

**What:** Added `kUniversalSummonCorpseCategory` constant and block inside the `recast_time > 1000` branch to (a) apply the `RuleI(Spells, UniversalSummonCorpseCooldown)` override when the spell's `spell_category` matches, and (b) zero out `recast` and clear the flag if `m_summon_corpse_was_noop` is set.
**Where:** `eqemu/zone/spells.cpp:2817-2841`
**Why:** The `recast > 0` guard at line 2838 already skips `GetPTimers().Start()` when `recast == 0`, so the noop path requires no special casing beyond setting `recast = 0`.

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| config-expert task 1 not yet complete | `RULE_INT` not registered at time of coding | Implement mob.h + spell_effects.cpp first; spells.cpp edit added once rule is confirmed |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `eqemu/zone/mob.h` | Modified | Added `m_summon_corpse_was_noop{false}` in spell casting vars block |
| `eqemu/zone/spell_effects.cpp` | Modified | Set flag in no-corpse branch when self-targeting |
| `eqemu/zone/spells.cpp` | Modified | Rule override + noop check in recast block |

---

## Open Items

- [ ] Await data-expert task 2: final `spell_category` value for `kUniversalSummonCorpseCategory`
- [ ] Await config-expert task 1: `RULE_INT` registration confirmation before spells.cpp edit compiles
- [ ] Full build verification after all three edits in place

---

## Context for Next Agent

Task 4 implements the no-op cooldown decouple for the Universal Summon Corpse spell line. Three files are modified:

1. `eqemu/zone/mob.h` — adds `bool m_summon_corpse_was_noop{false}` in the spell casting vars block (~line 1758). This is the transient signal between the SummonCorpse effect handler and the recast timer block.

2. `eqemu/zone/spell_effects.cpp` — in the `case SpellEffect::SummonCorpse` handler's no-corpse `else` branch (~line 1851), sets `m_summon_corpse_was_noop = true` only when `TargetClient == CastToClient()`. This ensures cross-player NEC/SHM no-op casts still consume their cooldown.

3. `eqemu/zone/spells.cpp` — in the `recast_time > 1000` block (~line 2817), adds a discriminator check on `spells[spell_id].spell_category == kUniversalSummonCorpseCategory`. Within that block: applies `RuleI(Spells, UniversalSummonCorpseCooldown)` as the override cooldown, then if `m_summon_corpse_was_noop` is set, zeroes `recast` and clears the flag. The existing `if (recast > 0)` guard at line 2838 then skips `GetPTimers().Start()` cleanly.

The `kUniversalSummonCorpseCategory` constant value comes from data-expert task 2. The `RuleI` macro requires config-expert's task 1 (RULE_INT registration in ruletypes.h) to compile.
