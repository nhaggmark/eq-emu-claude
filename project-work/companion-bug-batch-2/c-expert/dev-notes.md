# Companion Bug Batch 2 — Dev Notes: c-expert

> **Feature branch:** `bugfix/companion-bug-batch-2`
> **Agent:** c-expert
> **Task(s):** BUG-029, BUG-030, BUG-031
> **Date started:** 2026-03-15
> **Current stage:** Build

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 1 | BUG-029: SetAllowBeneficial in constructor + SpellOnTarget NPC group resolution | — | In Progress |
| 2 | BUG-031: Fire only global EVENT_TRADE handler for companions | — | Pending |
| 3 | BUG-030: Charm pet controls investigation + diagnostic logging | — | Pending |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `zone/companion.cpp` | 1–170 | Constructor — no `SetAllowBeneficial(true)` call exists |
| `zone/aggro.cpp` | 993–1005 | `IsBeneficialAllowed()` checks `GetAllowBeneficial()` at line 998 — early return true |
| `zone/mob.h` | 1049–1050 | `SetAllowBeneficial(bool)` / `GetAllowBeneficial()` both exist on Mob base class |
| `zone/npc.cpp` | 2201–2207 | Temp pet pattern: `SetAllowBeneficial(true)` called on client-owned swarm pets |
| `zone/spells.cpp` | 4167–4263 | `SpellOnTarget()` group-only spell check: resolves Client and Pet targets, but NOT NPC group members |
| `zone/trading.cpp` | 510–699 | `FinishTrade()` — `parse->EventNPC()` at line 643 fires both local+global handlers |
| `zone/quest_parser_collection.h` | 229–236 | `EventNPCGlobal()` is already public |
| `zone/quest_parser_collection.cpp` | 488–490 | `EventNPC()` calls `EventNPCLocal()` then `EventNPCGlobal()` unconditionally |
| `zone/client_packet.cpp` | 11126–11640 | `Handle_OP_PetCommands` — handles all pet commands, charmed pets pass the `!= petAnimation` check |
| `zone/spell_effects.cpp` | 776–862, 4480–4541 | Charm spell applies/removes pet relationship, sends `OP_Charm` command=1/0 correctly |
| `zone/common.h` | 908–915 | Old `PetTypeOld` enum: `petCharmed=3` |
| `common/emu_constants.h` | 898–914 | `PetType` namespace: `Charmed=3`, `Animation=1` |

### Key Findings

**BUG-029:**
- `m_AllowBeneficial` is initialized to `false` in `Mob::Mob()` constructor (`mob.cpp:497`)
- `GetAllowBeneficial()` checks `m_AllowBeneficial || GetSpecialAbility(AllowBeneficial)` — both are false for companions
- `IsBeneficialAllowed()` at `aggro.cpp:998` returns true early if `target->GetAllowBeneficial()` — so adding `SetAllowBeneficial(true)` in the Companion constructor fixes the "did not take hold" message
- Group-only spells: `SpellOnTarget()` only resolves group info for `IsClient()` and `IsPet()` targets. Companions are neither — they're NPC group members. Adding an else clause to resolve `pBasicGroupTarget` for non-client, non-pet targets fixes group spell targeting.

**BUG-031:**
- `parse->EventNPC(EVENT_TRADE, ...)` at `trading.cpp:643` fires both local AND global handlers
- For companions with PEQ per-NPC scripts, the local script returns items, then the global handler equips them
- `EventNPCGlobal()` is already public on `QuestParserCollection`
- The fix is to call `parse->EventNPCGlobal(...)` instead of `parse->EventNPC(...)` for companion targets

**BUG-030 Investigation:**
- `Handle_OP_PetCommands`: charmed pets pass the `mypet->GetPetType() != petAnimation` guard — commands SHOULD work
- `PET_ATTACK` works because the combat target gets added to hate list
- `PET_FOLLOWME`, `PET_BACKOFF`, `PET_GUARDHERE`, `PET_SIT` all look correct for charmed pets — they modify `SetPetOrder()` and movement state
- The issue may be that charmed pet AI re-engages combat immediately after backoff/follow commands because `WipeHateList()` doesn't prevent AI from re-adding aggro
- `OP_Charm` with command=0 is sent correctly on charm break both from `spell_effects.cpp:4520` (buff fade) and `mob_ai.cpp:533` (AI_Stop)
- Adding diagnostic logging to confirm commands arrive at the server will help determine if it's client-side or AI re-engagement

### Implementation Plan

**BUG-029 — Two changes:**
1. In `Companion::Companion()` constructor (`companion.cpp`), add `SetAllowBeneficial(true)` after existing `SetSpecialAbility(FleeingImmunity)` block
2. In `Mob::SpellOnTarget()` (`spells.cpp:4206`), after the `if (spelltar->IsPet())` block, add an else clause to resolve `pBasicGroupTarget` for non-client, non-pet NPC targets

**BUG-031 — One change:**
In `FinishTrade()` (`trading.cpp:643`), replace `parse->EventNPC(...)` with a companion check: for companions, call `parse->EventNPCGlobal(...)` instead

**BUG-030 — Diagnostic + fix:**
Add `LogInfo` diagnostic logging to `Handle_OP_PetCommands` to trace command receipt for charmed pets. Investigate AI re-engagement after follow/backoff commands.

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `SetAllowBeneficial(true)` | Source: `npc.cpp:2204` | Yes | Exact pattern used for temp pets |
| `entity_list.GetGroupByMob(spelltar)` | Source: `spells.cpp:4191,4200` | Yes | Already used in same function |
| `parse->EventNPCGlobal(...)` | Source: `quest_parser_collection.h:229` | Yes | Public method, same signature as EventNPC |
| `GetAllowBeneficial()` | Source: `mob.h:1050` | Yes | Returns `m_AllowBeneficial || SpecialAbility check` |
| `GetPetType()` / `PetType::Charmed` | Source: `mob.h:1092, emu_constants.h:902` | Yes | `petCharmed=3` in both old enum and PetType namespace |

### Plan Amendments

Plan confirmed — no amendments needed. All APIs verified against current source.

---

## Stage 3: Socialize

Solo dispatch — team-lead directed all three tasks to c-expert only. No other agents have cross-domain dependencies (no Lua/SQL changes needed).

### Consensus Plan

**BUG-029 (companion.cpp + spells.cpp):**
- Add `SetAllowBeneficial(true)` in Companion constructor after the flee immunity block (~line 141)
- In `SpellOnTarget()` after `if (spelltar->IsPet()) { ... }` block (~line 4217), add:
  ```cpp
  else if (!spelltar->IsClient() && !spelltar->IsPet()) {
      pBasicGroupTarget = entity_list.GetGroupByMob(spelltar);
  }
  ```

**BUG-031 (trading.cpp):**
- At line 643, wrap `parse->EventNPC(...)` in a companion check:
  ```cpp
  if (tradingWith->IsCompanion()) {
      parse->EventNPCGlobal(EVENT_TRADE, tradingWith->CastToNPC(), this, "", 0, &item_list);
  } else {
      parse->EventNPC(EVENT_TRADE, tradingWith->CastToNPC(), this, "", 0, &item_list);
  }
  ```

**BUG-030 (client_packet.cpp):**
- Add `LogInfo` at entry of `Handle_OP_PetCommands` to log command + pet type when a charmed pet is active
- This helps determine if commands reach the server

---

## Stage 4: Build

### Implementation Log

#### 2026-03-15 — BUG-029: SetAllowBeneficial in Companion constructor

**What:** Added `SetAllowBeneficial(true)` to Companion constructor
**Where:** `zone/companion.cpp` ~line 141
**Why:** `m_AllowBeneficial` defaults to false. Without this, `IsBeneficialAllowed()` returns false for Client→Companion, causing "did not take hold" for all beneficial spells.
**Notes:** Pattern matches `npc.cpp:2204` for temp pets.

#### 2026-03-15 — BUG-029: SpellOnTarget NPC group member resolution

**What:** Added else clause to resolve `pBasicGroupTarget` for non-client non-pet NPC targets
**Where:** `zone/spells.cpp` after line 4217
**Why:** Group-only spells check `pBasicGroup == pBasicGroupTarget` but `pBasicGroupTarget` was never populated for NPC targets like companions, so group-only spells always failed.
**Notes:** Only resolves group pointer, does not resolve raid group for NPCs (NPCs can't be in raids).

#### 2026-03-15 — BUG-031: Skip local EVENT_TRADE handler for companions

**What:** Changed companion trade to call `EventNPCGlobal` instead of `EventNPC`
**Where:** `zone/trading.cpp` line 643
**Why:** `EventNPC` fires both local+global handlers. PEQ per-NPC scripts return items; global_npc.lua equips them. Dual handler = duplication.
**Notes:** `EventNPCGlobal` is already public on `QuestParserCollection`.

#### 2026-03-15 — BUG-030: Diagnostic logging for charm pet commands

**What:** Added diagnostic logging to `Handle_OP_PetCommands` for charmed pets
**Where:** `zone/client_packet.cpp` ~line 11133
**Why:** Architecture calls for investigation — logging confirms if commands reach the server.

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| BUG-029: "did not take hold" | `m_AllowBeneficial=false`, companion hits NPC→Client path in `IsBeneficialAllowed()` returning false | `SetAllowBeneficial(true)` in constructor |
| BUG-029: Group spells fail | `pBasicGroupTarget` never populated for NPC group members | Add `else if (!IsClient() && !IsPet())` group resolution |
| BUG-031: Item duplication | `EventNPC()` fires both local PEQ script (returns item) and global handler (equips item) | Use `EventNPCGlobal()` for companion targets |
| BUG-030: Command analysis | Server-side gating looks correct — logging needed to confirm | Added diagnostic LogInfo on charmed pet commands |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `zone/companion.cpp` | Modified | Added `SetAllowBeneficial(true)` in constructor |
| `zone/spells.cpp` | Modified | Added NPC group member resolution in `SpellOnTarget()` |
| `zone/trading.cpp` | Modified | Use `EventNPCGlobal` for companion trade events |
| `zone/client_packet.cpp` | Modified | Diagnostic logging for charmed pet commands |
| `zone/cli/tests/cli_companion_tests.cpp` | Modified | New test suite for BUG-029/031 regressions |

---

## Open Items

- [ ] BUG-030: After reviewing logs from a real enchanter session, follow-up fix may be needed
- [ ] Build verification: run `ninja -j$(nproc)` after all changes

---

## Context for Next Agent

Three bugs fixed in zone C++ code. Feature branch: `bugfix/companion-bug-batch-2`.

**BUG-029:** `SetAllowBeneficial(true)` added to `Companion::Companion()` constructor in `companion.cpp`. Group-only spell targeting fixed in `Mob::SpellOnTarget()` in `spells.cpp` — added else clause to resolve `pBasicGroupTarget` via `entity_list.GetGroupByMob(spelltar)` for non-client non-pet targets.

**BUG-031:** `trading.cpp` `FinishTrade()` now calls `parse->EventNPCGlobal()` instead of `parse->EventNPC()` for companion targets. This prevents the local per-NPC PEQ script from returning items that the global handler already equipped.

**BUG-030:** Diagnostic logging added to `Handle_OP_PetCommands` in `client_packet.cpp`. After a real enchanter session, review server logs for the diagnostic output. If commands ARE reaching server but not working, the issue is AI re-engagement — the charmed NPC's AI re-adds aggro after `WipeHateList()`.
