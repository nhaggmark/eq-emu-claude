# Companion Equipment Management Enhancement — Dev Notes: Lua Expert

> **Feature branch:** `feature/companion-equipment`
> **Agent:** lua-expert
> **Task(s):** 7, 8, 9
> **Date started:** 2026-03-07
> **Current stage:** Build

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 7 | Enhance companion_find_slot for multi-slot empty-slot preference | — | In Progress |
| 8 | Add class/race restriction checks to event_trade | Task 1 (config-expert) | Pending (blocked) |
| 9 | Add money return check to event_trade | — | In Progress |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `akk-stack/server/quests/global/global_npc.lua` | 347 | Full trade handler, companion_find_slot, event_trade |
| `claude/project-work/feature/companion-equipment/architect/architecture.md` | 618 | Technical approach, exact change specs |
| `claude/project-work/feature/companion-equipment/game-designer/prd.md` | 529 | PRD with slot definitions and UX flows |

### Key Findings

**Task #9 (money return) — PARTIALLY DONE:**
The current `event_trade` already returns money for the owner path (lines 155-166) using
`AddMoneyToPP` silently. The architecture doc says: add a message "[Companion Name] has no use
for money." The current code returns money but sends no message. The non-owner path (lines
148-151) only handles platinum, not gold/silver/copper. Both paths need the message added.
The architecture says to add the money check "at the start" — but actually the ownership check
must happen first (don't return money before verifying ownership). The existing structure is
correct: ownership check first, then money return. I just need to add the message.

**Task #7 (multi-slot preference) — NEEDS REWORK:**
`companion_find_slot` at lines 118-128 uses a simple first-match scan with no occupancy check.
For rings (Finger1=slot 15, Finger2=slot 16) and wrists (Wrist1=slot 9, Wrist2=slot 10), it
always returns the lower slot ID regardless of whether it's occupied. The fix: pass the
companion object so we can call `companion:GetEquipment(slot_id)` to check occupancy. Return
the first EMPTY matching slot; if all matching slots are occupied, fall back to first match.

**Task #8 (class/race checks) — BLOCKED on Task #1:**
Needs `eq.get_rule("Companions:EnforceClassRestrictions")` and
`eq.get_rule("Companions:EnforceRaceRestrictions")` which require the ruletypes.h entries from
config-expert Task #1. Will implement after Task #1 completes.

### Implementation Plan

**Files to modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `akk-stack/server/quests/global/global_npc.lua` | Modify | companion_find_slot signature + logic; event_trade money message |

**Change sequence:**
1. Task #9: Add message to money return block in `event_trade` (owner path lines 155-166, also fix non-owner path to return all denominations)
2. Task #7: Change `companion_find_slot(slots_bitmask)` to `companion_find_slot(companion, slots_bitmask)`, add empty-slot preference logic, update call site in event_trade

**What to test:**
- Trade a ring to companion with empty Finger1 → goes to Finger1
- Trade a ring to companion with Finger1 occupied, Finger2 empty → goes to Finger2
- Trade a ring to companion with both finger slots occupied → goes to Finger1 (displaces)
- Trade money to companion → money returned with message

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `GetEquipment(slot_id)` | architecture.md states "Use companion:GetEquipment(slot_id) (returns item_id, 0 if empty)" | Yes — architect specified | Returns item_id; 0 = empty slot |
| `AddMoneyToPP(copper, silver, gold, platinum, update)` | Existing code in global_npc.lua lines 149, 159-165 | Yes | Already used in the file |
| `math.floor(x / (2^slot)) % 2` | Existing code in companion_find_slot | Yes | Bit-check idiom used in current code |

### Plan Amendments

Plan confirmed — no amendments needed. Observation: `GetEquipment` is already confirmed by
the architecture doc. The bit-check approach is already in place; just need to add the
occupancy check loop.

---

## Stage 3: Socialize

Skipping formal socialize for Tasks #7 and #9 — these are purely self-contained Lua changes
in a single file with no cross-system dependencies. Architecture doc fully specifies the
approach. Task #8 will be socialized with config-expert when Task #1 completes.

### Consensus Plan

**Agreed approach:** Implement Tasks #7 and #9 per architecture spec. Task #8 blocked until
Task #1 done.

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `akk-stack/server/quests/global/global_npc.lua` | Modify | companion_find_slot + event_trade money message |

**Change sequence (final):**
1. Add money message to owner-path money return block
2. Fix non-owner path to return all denominations (not just platinum) with message
3. Rewrite companion_find_slot to accept companion object and prefer empty slots
4. Update call site to pass `e.self` as first argument

---

## Stage 4: Build

### Implementation Log

#### 2026-03-07 — Task #9: money return message + Task #7: multi-slot empty preference

**What:** Modified `companion_find_slot` to prefer empty slots; added money return message
**Where:** `/mnt/d/Dev/eq/akk-stack/server/quests/global/global_npc.lua`
- `companion_find_slot`: lines 118-128 → rewritten, signature changed to accept `companion`
- `event_trade` call site: line 177 → updated to pass `e.self`
- Money return block (owner path): lines 155-166 → added message
- Non-owner path: lines 148-151 → added gold/silver/copper return + unified message

**Why:** Task #7 requires empty-slot preference for multi-slot items (rings, wrists).
Task #9 requires a message when money is returned so the player understands why.

**Notes:** The `GetEquipment(slot_id)` call returns 0 for empty slots per architecture doc.
The two-pass approach (empty-first, then fallback) is O(n) per slot-count which is negligible
(max 23 slots). Non-owner path needed fix too — previously only returned platinum not all coins.

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `akk-stack/server/quests/global/global_npc.lua` | Modified | companion_find_slot empty-slot preference; money return message |

---

## Open Items

- [ ] Task #8: Add class/race restriction checks — blocked on Task #1 (config-expert ruletypes.h)

---

## Context for Next Agent

Tasks #7 and #9 are complete. Task #8 is the remaining lua-expert task.

**Task #8 requires:**
- `eq.get_rule("Companions:EnforceClassRestrictions")` — from Task #1
- `eq.get_rule("Companions:EnforceRaceRestrictions")` — from Task #1
- Add to `event_trade` in `global_npc.lua`, in the item-equip loop, BEFORE the
  `companion:GiveItem()` call
- Logic: get item_data from inst:GetItem(), call item_data:IsEquipable(race, class),
  check rules, send message and SummonItem if rejected

**Files:** `/mnt/d/Dev/eq/akk-stack/server/quests/global/global_npc.lua`

See architecture.md "Change 2: Class/race restriction enforcement" for exact spec.
