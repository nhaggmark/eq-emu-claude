# Companion Snare AI: Combat Restriction — Dev Notes: c-expert

> **Feature branch:** `feature/companion-snare-ai`
> **Agent:** c-expert
> **Task(s):** 3, 4, 5, 6, 7, 8, 9 (+ task 11 restart)
> **Date started:** 2026-05-03
> **Current stage:** Build

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 3 | Add `m_movement_control_resist_counts`, `m_last_movement_control_target_id` to companion.h. Implement `AI_AttemptMovementControl`, `OnSpellResisted`, `ClearMovementControlResistCounters`. | Task 1 (rules) | In Progress |
| 4 | Replace AI_Druid Root branch (companion_ai.cpp:1235) with helper call. | Task 3 | In Progress |
| 5 | Replace AI_Ranger Snare branch (companion_ai.cpp:1469) with helper call. | Task 3 | In Progress |
| 6 | Replace AI_Bard Snare branch (companion_ai.cpp:1789) with helper call. | Task 3 | In Progress |
| 7 | Hook engagement-end in companion.cpp:1993 to call ClearMovementControlResistCounters(). | Task 3 | In Progress |
| 8 | Hook Mob::SpellOnTarget full-resist branch (spells.cpp:4554) for Companion. | Task 3 | In Progress |
| 9 | Build verification. | Tasks 4-8 | Pending |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `eqemu/zone/companion.h` | 1-601 | Full class declaration. Private members section at line 536. AI helpers section at 258. No existing movement-control members. |
| `eqemu/zone/companion_ai.cpp` | 855-870, 1220-1276, 1459-1501, 1775-1811 | AI_SlowDebuff ends ~869. AI_Druid Root branch: lines 1235-1246. AI_Ranger Snare branch: lines 1469-1483. AI_Bard Snare branch: lines 1789-1802. |
| `eqemu/zone/companion.cpp` | 1985-2010 | m_was_engaged transition at lines 1992-2000. Exact site for ClearMovementControlResistCounters() call. |
| `eqemu/zone/spells.cpp` | 4500-4556 | Full-resist branch: lines 4508-4555. The `safe_delete(action_packet); return false;` is at lines 4554-4555. Hook goes before line 4554. |
| `eqemu/common/ruletypes.h` | 1256-1265 | SnareHpThreshold and SnareResistLimit already registered by config-expert. Task 1 complete. |

### Key Findings

- Config-expert already registered both rules at ruletypes.h:1256-1265. No compile blocker.
- AI_Druid Root branch (1235-1246) does its own `SelectFirstSpell` + `IsRooted()` check inline. The helper will absorb all of that.
- AI_Ranger Snare branch (1469-1483) has `SnareImmunity` and `GetSnaredAmount()` guards inline. Helper absorbs.
- AI_Bard Snare branch (1789-1802) has `SnareImmunity` guard only (no snared check). Helper absorbs.
- The `spells[cast_spell].mana` pattern is used by existing `AIDoSpellCast` calls in all three branches. Helper preserves this.
- The architecture's helper code uses `GetSnaredAmount() >= 0` to detect "not yet snared." Verified against AI_Ranger branch — correct pattern.
- Resist hook insertion point confirmed: line 4554 is `safe_delete(action_packet);`. Hook goes on the two lines immediately before it.
- `m_was_engaged` transition block (companion.cpp:1993-1999): the `ClearMovementControlResistCounters()` call goes after the rez timer block but before `m_was_engaged = currently_engaged`.
- Architecture note: also clear counters in `Death()` and `Unsuspend()` per Pass 3 edge-case table.

### Implementation Plan

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `eqemu/zone/companion.h` | Modify | Add 3 public method declarations + 2 private members |
| `eqemu/zone/companion_ai.cpp` | Modify | Add `AI_AttemptMovementControl` + `OnSpellResisted` + `ClearMovementControlResistCounters` implementations. Replace 3 inline branches. |
| `eqemu/zone/companion.cpp` | Modify | Add `ClearMovementControlResistCounters()` at engagement-end + Death + Unsuspend |
| `eqemu/zone/spells.cpp` | Modify | Add 3-line IsCompanion hook in full-resist branch |

**Change sequence:**
1. `companion.h` — add declarations + private members
2. `companion_ai.cpp` — implement helper + OnSpellResisted + ClearMovementControlResistCounters after AI_SlowDebuff (~line 869)
3. `companion_ai.cpp` — replace AI_Druid Root branch
4. `companion_ai.cpp` — replace AI_Ranger Snare branch
5. `companion_ai.cpp` — replace AI_Bard Snare branch
6. `companion.cpp` — hook engagement-end + Death + Unsuspend
7. `spells.cpp` — resist hook
8. Build

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `std::unordered_map<uint16, uint8>` | Source (existing patterns in companion.h) | Yes | Direct read of companion.h private section |
| `RuleI(Companions, SnareHpThreshold)` | ruletypes.h:1256 | Yes | Already registered |
| `target->GetHPRatio()` | Source (mob.h pattern, existing in companion_ai.cpp) | Yes | Returns float, cast to int for threshold comparison |
| `target->IsFleeing()` | Architecture doc — mob.h:1251 | Yes | O(1) member read |
| `IsCompanion()` + `CastToCompanion()` | companion.h:111 | Yes | Virtual override returns true |
| `LogAIDetail` macro | Existing usage in companion_ai.cpp | Yes | Standard AI logging pattern |
| `Timer::GetCurrentTime()` | Existing usage pattern in companion_ai.cpp | Yes | |
| `SelectFirstSpell` | companion_ai.cpp:261 | Yes | Takes (spells_vec, type_mask, stance, now_ms) |
| `AIDoSpellCast` | companion.h:224 | Yes | Returns bool |
| `SetSpellTimeCanCast` | companion.h:319 | Yes | Sets recast timer |
| `spells[cast_spell].mana` | Existing pattern in all branches | Yes | |
| `spells[cast_spell].recast_time` | Existing pattern in all branches | Yes | |

### Plan Amendments

Plan confirmed — no amendments needed beyond adding Death/Unsuspend clears per architecture Pass 3.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| config-expert | Confirming task 1 complete — rules present | Verified SnareHpThreshold + SnareResistLimit already registered. |

### Feedback Received

| From | Feedback | Action Taken |
|------|----------|-------------|
| config-expert | (awaiting; not blocking — rules confirmed in source) | Proceeding |

### Consensus Plan

**Agreed approach:** Implement exactly per architecture.md. Three helper methods in companion_ai.cpp inserted after AI_SlowDebuff. Replace three inline branches. Hook engagement-end, Death, Unsuspend. Hook spells.cpp resist branch.

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `eqemu/zone/companion.h` | Modify | 3 public declarations + 2 private members |
| `eqemu/zone/companion_ai.cpp` | Modify | ~120 lines: 3 new helpers + 3 branch replacements |
| `eqemu/zone/companion.cpp` | Modify | ~5 lines: engagement-end + Death + Unsuspend clears |
| `eqemu/zone/spells.cpp` | Modify | ~3 lines: IsCompanion hook |

**Change sequence (final):**
1. companion.h declarations + members
2. companion_ai.cpp helper implementations
3. companion_ai.cpp branch replacements (Druid, Ranger, Bard)
4. companion.cpp engagement-end hook
5. spells.cpp resist hook
6. Build + verify

---

## Stage 4: Build

### Implementation Log

#### 2026-05-03 — companion.h: add declarations + private members

**What:** Added 3 public method declarations to the AI helpers section and 2 private members to the private section.
**Where:** companion.h — public AI helpers ~line 270, private section ~line 597
**Why:** Required by all subsequent implementation steps.

#### 2026-05-03 — companion_ai.cpp: implement AI_AttemptMovementControl, OnSpellResisted, ClearMovementControlResistCounters

**What:** Added three new methods after AI_SlowDebuff (~line 869).
**Where:** companion_ai.cpp, after the `return cast_ok;` closing line of AI_SlowDebuff
**Why:** Centralized gate — all three class handlers call this instead of doing inline cast logic.

#### 2026-05-03 — companion_ai.cpp: replace AI_Druid Root branch

**What:** Replaced lines 1235-1246 (inline root spell selection + cast) with call to `AI_AttemptMovementControl(GetTarget(), SpellType_Root)`.
**Where:** companion_ai.cpp:1235-1246
**Why:** Task 4 — gate the root spam.

#### 2026-05-03 — companion_ai.cpp: replace AI_Ranger Snare branch

**What:** Replaced lines 1469-1483 (inline snare spell selection + guards + cast) with call to `AI_AttemptMovementControl(GetTarget(), SpellType_Snare)`.
**Where:** companion_ai.cpp:1469-1483
**Why:** Task 5.

#### 2026-05-03 — companion_ai.cpp: replace AI_Bard Snare branch

**What:** Replaced lines 1789-1802 (inline snare spell selection + guard + cast) with call to `AI_AttemptMovementControl(GetTarget(), SpellType_Snare)`.
**Where:** companion_ai.cpp:1789-1802
**Why:** Task 6.

#### 2026-05-03 — companion.cpp: engagement-end + Death + Unsuspend clears

**What:** Added ClearMovementControlResistCounters() call at the m_was_engaged transition and in Death() and Unsuspend().
**Where:** companion.cpp:1993-1999 region
**Why:** Tasks 7. Death/Unsuspend per architecture Pass 3 edge-case table.

#### 2026-05-03 — spells.cpp: resist hook

**What:** Added IsCompanion() guard + OnSpellResisted call before safe_delete(action_packet) in full-resist branch.
**Where:** spells.cpp:~4554
**Why:** Task 8.

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| | | |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `eqemu/zone/companion.h` | Modified | Added 3 method declarations + 2 private members |
| `eqemu/zone/companion_ai.cpp` | Modified | Added 3 helpers; replaced 3 inline branches |
| `eqemu/zone/companion.cpp` | Modified | Engagement-end + Death + Unsuspend counter clears |
| `eqemu/zone/spells.cpp` | Modified | Resist hook for IsCompanion() |

---

## Open Items

- [ ] Build verification (task 9)
- [ ] Notify config-expert to run task 10 after build

---

## Context for Next Agent

All C++ changes are in the four files above. The consensus plan matches
architecture.md exactly. After build succeeds, config-expert runs task 10
(INSERT rule_values rows + #reloadrules). Then hand off to game-tester.
