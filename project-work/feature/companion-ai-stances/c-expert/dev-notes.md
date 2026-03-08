# companion-ai-stances — Dev Notes: C Expert

> **Feature branch:** `feature/companion-ai-stances`
> **Agent:** c-expert
> **Task(s):** #1, #2, #3, #4 (includes #5 flee suppression)
> **Date started:** 2026-03-08
> **Current stage:** Build

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 1 | Add IsCompanion() guard in aggro.cpp | — | Complete |
| 2 | Add IsCompanion() guard in npc.cpp | — | Complete |
| 3 | Rewrite Companion::Process() for stance-aware AI | 1, 2, rules | Complete |
| 4 | Flee suppression via CompanionFleeEnabled rule | 1, 3 | Complete |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| zone/companion.cpp | 468-535 | Process() has owner-assist logic only. Calls NPC::Process() at end. |
| zone/companion.h | 37-41, 255-256, 330 | COMPANION_STANCE_* defines, GetStance/SetStance, m_current_stance |
| zone/aggro.cpp | 397-402 | GetOwner() check at line 400 prevents pets from aggro scanning; companions lack this |
| zone/npc.cpp | 775-784 | assist_timer block calls AIYellForHelp() when engaged |
| zone/merc.cpp | 2053-2100 | CheckHateList() template for balanced group-assist scanning |
| zone/mob.h | 785, 793, 1365, 1514, 1731, 1882 | IsEngaged, WipeHateList, GetReverseFactionCon (virtual, overridden in Client), GetCloseMobList, casting_spell_id, currently_fleeing |
| common/faction.h | 27-36 | FACTION_VALUE enum: FACTION_THREATENINGLY=8, FACTION_SCOWLS=9 |
| common/spdat.h | 1778 | IsDetrimentalSpell(uint16 spell_id) |
| common/ruletypes.h | 1209-1210 | AggressiveScanRadius and CompanionFleeEnabled already added by config-expert |

### Key Findings

1. **Rules already added**: config-expert committed `AggressiveScanRadius` and `CompanionFleeEnabled` to ruletypes.h — Task 1 (rules) is complete.
2. **aggro.cpp line 400**: `GetOwner()` check returns false for companions (they use `m_owner_char_id`, not the NPC owner system). Need `IsCompanion()` guard after this check.
3. **npc.cpp line 775**: `assist_timer.Check()` block calls `AIYellForHelp()`. Need `!IsCompanion()` in the condition.
4. **currently_fleeing**: Field in Mob (mob.h:1882), directly accessible. Set to false to suppress flee.
5. **GetReverseFactionCon**: Virtual in Mob (returns INDIFFERENTLY), properly overridden in Client. Get owner Client* and call it with the NPC as arg.
6. **FACTION_THREATENS**: Architecture doc uses this name but real enum is `FACTION_THREATENINGLY` (value 8).
7. **IsOffensiveSpell**: Does not exist. Use `IsDetrimentalSpell(casting_spell_id)` from common/spdat.h instead.
8. **GetCloseMobList**: Returns `std::unordered_map<uint16, Mob*>&`. Loop with `for (auto& [id, mob] : GetCloseMobList(dist))`.
9. **Merc::CheckHateList()**: Uses entity_list.GetNPCList() not GetCloseMobList(). Architecture plan uses GetCloseMobList which is more efficient for our use case.

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `GetCloseMobList(float)` | mob.h:1514, mob.cpp:8612 | Yes | Returns unordered_map<uint16, Mob*>& |
| `IsDetrimentalSpell(uint16)` | common/spdat.h:1778 | Yes | Replaces IsOffensiveSpell which doesn't exist |
| `FACTION_THREATENINGLY` | common/faction.h:35 | Yes | Architecture doc had wrong name (FACTION_THREATENS) |
| `currently_fleeing` | mob.h:1882 | Yes | Protected member, accessible from Companion |
| `IsCasting()` | mob.h:418 | Yes | Returns (casting_spell_id != 0) |
| `InterruptSpell()` | zone/spells.cpp:1233 | Yes | No-arg form calls InterruptSpell(0, 0x121, SPELL_UNKNOWN) |
| `WipeHateList()` | mob.h:793 | Yes | Exists, no params needed |
| `GetReverseFactionCon` | client.h:819 | Yes | Properly overridden in Client |
| `MAX_GROUP_MEMBERS` | common/eq_packet_structs.h:892 | Yes | = 6 |

### Plan Amendments

- Use `IsDetrimentalSpell(casting_spell_id)` instead of non-existent `IsOffensiveSpell()`
- Use `FACTION_THREATENINGLY` not `FACTION_THREATENS`
- For balanced scanning, iterate NPCs via `GetCloseMobList()` rather than `entity_list.GetNPCList()` for efficiency
- The architecture's balanced scan logic needs a check: only scan for companions not already engaged

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| config-expert | Rules status | Confirmed rules already added to ruletypes.h — Task 1 prerequisite met |

### Consensus Plan

**Agreed approach:** Implement all 4 tasks as described in architecture.md with the corrections noted in research:
- Use `FACTION_THREATENINGLY` (not `FACTION_THREATENS`)
- Use `IsDetrimentalSpell()` for spell check
- Keep the `NPC::Process()` chain intact

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| zone/aggro.cpp | Modify | Add IsCompanion() guard after GetOwner() check (~line 402) |
| zone/npc.cpp | Modify | Add !IsCompanion() to assist_timer condition (line 775) |
| zone/companion.cpp | Modify | Rewrite Process() with stance-aware AI + flee suppression |

**Change sequence (final):**
1. aggro.cpp: 4-line IsCompanion() guard
2. npc.cpp: 1-word addition to assist condition
3. companion.cpp: Process() rewrite (~100 lines)

---

## Stage 4: Build

### Implementation Log

#### 2026-03-08 — Task #1: aggro.cpp IsCompanion() guard

**What:** Added `IsCompanion()` early-return guard in `Mob::CheckWillAggro()` after the existing `GetOwner()` check
**Where:** `/mnt/d/Dev/eq/eqemu/zone/aggro.cpp` after line 402
**Why:** Companions don't use the NPC owner system (`GetOwner()` returns null), so the existing pet guard doesn't protect them. Without this, `DoNpcToNpcAggroScan()` would cause companions to aggro based on their original NPC faction.
**Notes:** Guard is placed immediately after the GetOwner() block for logical grouping.

#### 2026-03-08 — Task #2: npc.cpp assist guard

**What:** Added `!IsCompanion()` to the assist_timer condition
**Where:** `/mnt/d/Dev/eq/eqemu/zone/npc.cpp` line 775
**Why:** Prevents companions from calling `AIYellForHelp()` which would cause nearby same-faction NPCs to attack the companion's target — breaking the clean-break from NPC AI.

#### 2026-03-08 — Task #3+4: companion.cpp Process() rewrite

**What:** Rewrote `Companion::Process()` to implement stance-aware AI with flee suppression
**Where:** `/mnt/d/Dev/eq/eqemu/zone/companion.cpp` lines 468-535
**Why:** Implements the three stance behaviors: passive (clear hate/interrupt spell), balanced (group-assist), aggressive (hostile scan using owner's faction). Flee suppression via `CompanionFleeEnabled` rule.
**Notes:**
- Used `FACTION_THREATENINGLY` (value 8), not the non-existent `FACTION_THREATENS`
- Used `IsDetrimentalSpell(casting_spell_id)` for offensive spell detection
- `currently_fleeing` is a protected member of Mob — accessible from Companion
- Balanced scan uses `GetCloseMobList(200.0f)` and checks if NPC is on any group member's hate list

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| zone/aggro.cpp | Modified | +4 lines: IsCompanion() guard prevents faction-based aggro initiation |
| zone/npc.cpp | Modified | +1 condition: !IsCompanion() prevents companion assist calls |
| zone/companion.cpp | Modified | ~100 lines: stance-aware Process() rewrite + flee suppression |

---

## Open Items

- [ ] Task #6: Build, validate, insert rule_values — pending after all C++ changes done

---

## Context for Next Agent

All C++ changes are complete. The three stance behaviors are implemented in `Companion::Process()`:
- **Passive**: wipes hate list, sets target to null, interrupts detrimental spell casting, skips assist logic, falls through to `NPC::Process()` for regen/movement
- **Balanced**: group-assist scan (checks if any group member is on a nearby NPC's hate list), plus existing owner-target assist logic
- **Aggressive**: scans for NPCs hostile to the owner (using `owner->GetReverseFactionCon(npc)` >= FACTION_THREATENINGLY), engages closest hostile within `AggressiveScanRadius`

Two guards added in other files:
- `aggro.cpp`: `IsCompanion()` prevents faction-based aggro scanning initiation
- `npc.cpp`: `!IsCompanion()` prevents assist yell calls

Next step is Task #6: build, validate, and insert rule_values rows.
