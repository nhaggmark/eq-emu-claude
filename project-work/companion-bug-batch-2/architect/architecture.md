# Companion Bug Batch 2 — Architecture & Implementation Plan

> **Feature branch:** `bugfix/companion-bug-batch-2`
> **PRD:** N/A (bug-fix batch — bug reports serve as design input)
> **Author:** architect
> **Date:** 2026-03-15
> **Status:** In Review

---

## Executive Summary

Three companion bugs require fixes across the C++ spell system, trade system, and
Lua quest scripts. BUG-029 (buffs not taking hold) is caused by the `IsBeneficialAllowed()`
function not recognizing companions as valid beneficial spell targets. BUG-030 (charm pet
controls) is a general EQEmu charm issue with the Titanium client, not companion-specific.
BUG-031 (gear duplication) is caused by dual event handler firing — both a local per-NPC
script and the global companion trade handler process the same trade event, resulting in
items being both returned and equipped simultaneously.

## Existing System Analysis

### Current State

**Spell Targeting (`aggro.cpp:989-1121`):**
`IsBeneficialAllowed()` determines whether one mob can cast beneficial spells on another.
It uses type-checking macros (`_CLIENT`, `_NPC`, `_BECOMENPC`) to classify both caster and
target, then applies rules based on the pair. The function has a special early-return for
bots (`mob2->IsBot()` at line 1051) and an `AllowBeneficial` flag check at line 998.
Companions hit the NPC-to-Client path on the reverse pass (lines 1057-1060) which returns
false.

**Beneficial Spell Targeting (`spells.cpp:4167-4263`):**
`SpellOnTarget()` has a two-part check for beneficial spells cast by clients on others:
1. `IsBeneficialAllowed(target)` — must return true, or the spell is blocked
2. For group-only spells, the target must be in the same group — but the group resolution
   code at lines 4196-4217 only handles `IsClient()` and `IsPet()` targets, not NPC group
   members like companions.

**Trade System (`trading.cpp:510-698`):**
`FinishTrade()` calls `parse->EventNPC(EVENT_TRADE, ...)` which fires BOTH `EventNPCLocal()`
AND `EventNPCGlobal()` unconditionally (quest_parser_collection.cpp:488-490). This means
companions with per-NPC quest scripts (from PEQ content) have two trade handlers fire: the
local PEQ script (which returns items) and the global companion handler (which equips items).
A BUG-018 fix at line 647-658 prevents the C++ catch-all return from double-returning items,
but it doesn't prevent the local Lua/Perl script from returning them.

**Charm System (`spell_effects.cpp:776-862, 4422-4541`):**
Charm applies the pet relationship via `SetPet()`, `SetOwnerID()`, and sends `OP_Charm`.
Charm break reverses these and sends `OP_Charm` with command=0. Pet commands route through
`Handle_OP_PetCommands` which uses `GetPet()` — this should work for charmed pets since
`petCharmed` passes all the `petAnimation` guards.

### Gap Analysis

| Bug | Gap | Root Cause |
|-----|-----|------------|
| BUG-029 | `IsBeneficialAllowed()` has no companion awareness | Missing case in NPC type classification |
| BUG-029 | Group-only spell targeting doesn't resolve NPC group members | `SpellOnTarget()` only resolves Client/Pet targets |
| BUG-030 | Charm pet controls partially non-functional on Titanium | Likely general EQEmu issue; needs server-side logging investigation |
| BUG-031 | Dual event handler firing for companion trades | `EventNPC()` fires both local and global unconditionally |

## Technical Approach

### Architecture Decision

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| `zone/companion.cpp` constructor | C++ — add `SetAllowBeneficial(true)` | Enables the early-return path in `IsBeneficialAllowed()`, matching the pattern used for temp pets (`npc.cpp:2204`). Simplest fix — no changes to the complex beneficial-allowed logic. |
| `zone/spells.cpp` SpellOnTarget | C++ — add NPC group member resolution | Group-only spells (Alacrity, etc.) need the target's group resolved even when target is an NPC, not just Client/Pet. |
| `zone/trading.cpp` FinishTrade | C++ — skip local EVENT_TRADE for companions | Prevents dual-handler firing. For companions, only fire `EventNPCGlobal`. |
| Charm system | Investigation + C++ | BUG-030 needs deeper investigation with logging to determine if pet commands reach the handler and whether the Titanium client sends them correctly. |

### Data Model

No database changes required.

### Code Changes

#### C++ Changes

**BUG-029 Fix — File: `zone/companion.cpp`**

In the Companion constructor (around line 138), add:
```cpp
SetAllowBeneficial(true);
```
This enables beneficial spells from any caster to target this companion. Matches the
pattern at `npc.cpp:2204` for temp pets with client owners.

**BUG-029 Fix — File: `zone/spells.cpp`**

In `Mob::SpellOnTarget()` around line 4196-4217, add group resolution for non-Client,
non-Pet targets. Currently only Client and Pet targets get their group resolved. Add
an else clause:
```cpp
// After the IsClient() and IsPet() blocks, add:
if (!spelltar->IsClient() && !spelltar->IsPet()) {
    // Resolve group for NPC group members (companions, mercs, etc.)
    pBasicGroupTarget = entity_list.GetGroupByMob(spelltar);
}
```
This ensures group-only spells (like Alacrity — which is a group-target haste) recognize
that companions in the same group are valid targets.

**BUG-030 Fix — File: `zone/client_packet.cpp`**

Add diagnostic logging to `Handle_OP_PetCommands` to determine if commands are reaching
the server for charmed pets. This will help determine if the issue is:
(a) Client not sending commands, or
(b) Server receiving but not processing them.

If investigation reveals commands ARE reaching the server but not executing, the fix
would be in the pet command handler. If the client isn't sending commands for charmed
pets, this is a Titanium client limitation that may need a workaround (e.g., chat
commands like `/pet follow`).

For charm break persistence: verify that `OP_Charm` with command=0 is sent and received.
Add logging around charm break to confirm packet delivery.

**BUG-031 Fix — File: `zone/trading.cpp`**

In `FinishTrade()`, for companion trade targets, replace the `parse->EventNPC()` call
with `parse->EventNPCGlobal()` to skip local per-NPC scripts. The companion trade
handler lives entirely in `global_npc.lua` and must be the only handler that runs.

Change at approximately line 622-644:
```cpp
if (parse->HasQuestSub(tradingWith->GetNPCTypeID(), EVENT_TRADE) && !has_aggro) {
    // ... handin setup ...
    
    if (tradingWith->IsCompanion()) {
        // Companions: fire ONLY the global handler to prevent dual-handler duplication.
        // Local per-NPC scripts (from PEQ content) would return items because they
        // don't know this NPC is now a companion.
        parse->EventNPCGlobal(EVENT_TRADE, tradingWith->CastToNPC(), this, "", 0, &item_list);
    } else {
        parse->EventNPC(EVENT_TRADE, tradingWith->CastToNPC(), this, "", 0, &item_list);
    }
}
```

Note: `EventNPCGlobal` is currently a private method on `QuestParserCollection`. It may
need to be made public, or alternatively, a new public method `EventNPCGlobalOnly()` can
be added. The c-expert should evaluate the cleanest approach.

#### Lua/Script Changes

No Lua changes required. The global_npc.lua trade handler is correct — the issue is
purely in C++ firing both local and global handlers.

#### Database Changes

None.

#### Configuration Changes

None required. The fix uses existing patterns (AllowBeneficial flag) and code changes.

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | BUG-029: Add `SetAllowBeneficial(true)` to Companion constructor and add NPC group member resolution to `SpellOnTarget()` | c-expert | — | Small: 2 files, ~10 lines |
| 2 | BUG-031: In `FinishTrade()`, fire only global EVENT_TRADE handler for companions | c-expert | — | Small: 1-2 files, ~15 lines |
| 3 | BUG-030: Add diagnostic logging to `Handle_OP_PetCommands` for charmed pets; investigate Titanium charm packet behavior; fix if server-side issue found | c-expert | — | Medium: investigation + conditional fix |

Tasks 1 and 2 are independent and can be implemented in parallel or either order.
Task 3 is an investigation that may yield a fix or may document a Titanium limitation.

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `SetAllowBeneficial(true)` allows ANY mob to buff companion (not just owner) | Low | Low | This is desired behavior — companions should be buffable by anyone in the group, same as Bots/Mercs. The `SpellOnTarget()` group check still restricts group-only spells to group members. |
| Skipping local EVENT_TRADE for companions breaks a future per-NPC companion script | Low | Low | All companion trade logic is in global_npc.lua by design. Per-NPC companion scripts should not exist. If needed in the future, the global handler is the correct place. |
| Group-only spell resolution change affects non-companion NPC group members | Very Low | Low | The only NPC types that can be in player groups are companions, mercs, and bots. Bots already have their own `IsBot()` check. Mercs have `AllowBeneficial` set. Change is safe. |
| BUG-030 may be a Titanium client limitation with no server-side fix | Medium | Medium | If investigation confirms client limitation, document it as a known issue and consider chat-command workarounds. |

### Compatibility Risks

No backward compatibility concerns. All changes are additive — they extend existing
patterns (AllowBeneficial, group resolution) to cover companions. No existing behavior
is removed or altered for non-companion entities.

### Performance Risks

No performance concerns. The `SetAllowBeneficial` flag is a simple boolean check.
The group resolution adds one `GetGroupByMob()` call per beneficial spell cast on a
non-client, non-pet target — negligible overhead.

## Review Passes

### Pass 1: Feasibility

**BUG-029:** Fully feasible. The `AllowBeneficial` flag pattern is proven (used for temp
pets). The `GetGroupByMob()` function exists and works correctly for companions. Both
changes are minimal and surgical.

**BUG-030:** Feasibility depends on investigation. The server-side code appears correct
for charmed pets. The issue may be Titanium client behavior. A fix is feasible if the
problem is server-side; if it's client-side, a workaround via chat commands may be needed.

**BUG-031:** Fully feasible. `EventNPCGlobal` exists as a method. The only concern is
its visibility (may be private). Making it accessible or adding a wrapper is trivial.

### Pass 2: Simplicity

**BUG-029:** The `SetAllowBeneficial(true)` approach is the simplest possible fix —
one line in the constructor. The alternative (modifying `IsBeneficialAllowed()` with
companion-specific logic) would be more complex and fragile. The group resolution fix
is also minimal — one additional `else` clause.

**BUG-031:** Skipping local EVENT_TRADE for companions is simpler than alternatives
like: (a) modifying all PEQ local scripts to check `IsCompanion()`, (b) adding a
"companion trade in progress" flag, or (c) making event_trade return values prevent
global handler firing.

**BUG-030:** Investigation-first approach avoids premature optimization. We don't add
code until we understand the actual problem.

### Pass 3: Antagonistic

**Edge cases for BUG-029:**
- What if a hostile player tries to debuff a companion via a beneficial spell?
  → Debuffs are detrimental spells, not beneficial. `IsDetrimentalSpell()` check at
  line 3916 handles this separately.
- What about PVP scenarios with AllowBeneficial set?
  → This server is 1-3 players, PVP is not a concern. Even if it were,
  `AllowBeneficial` only allows beneficial spells, not detrimental.
- What if buff stacking conflicts occur on companions?
  → Same as any NPC — `CheckStackConflict()` handles this. Companions use
  `GetMaxTotalSlots()` from NPC which uses `RuleI(Spells, MaxTotalSlotsNPC)`.

**Edge cases for BUG-031:**
- What if a companion NPC has a local script that intentionally processes trades?
  → This should never happen. Companion trade logic is centralized in global_npc.lua.
  If a future feature needs per-companion trade handling, it should be added to the
  global handler with an NPC type check.
- What about task system hand-ins to companions?
  → Task system hand-ins at line 527-533 run BEFORE the EVENT_TRADE dispatch and are
  independent. They are unaffected by this change.

**Edge cases for BUG-030:**
- What if charm breaks during a zone transition?
  → Charm buffs are zone-local; they fade on zone. This is existing behavior.
- What if the charmed NPC dies while charmed?
  → Death clears the pet relationship via `Death()` handling. Not affected.

### Pass 4: Integration

The three fixes are independent — no dependencies between them. They can be implemented
in any order. All changes are in the C++ `zone/` directory, requiring a single rebuild.

**Implementation order recommendation:**
1. BUG-029 (buffs) — highest user impact, simplest fix
2. BUG-031 (duplication) — critical severity, small fix
3. BUG-030 (charm) — investigation required, may or may not yield a code fix

**Build/test cycle:** One build covers all three fixes. After build, test each bug
independently:
1. Cast Alacrity and other beneficial spells on a companion → should apply
2. Trade items to a companion that has a PEQ per-NPC script → should equip without duplication
3. Charm an NPC with an enchanter → test all pet commands

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| c-expert | Tasks 1, 2, 3 | All fixes are in C++ zone code (companion.cpp, spells.cpp, trading.cpp, client_packet.cpp) |

No Lua, SQL, or config changes needed. Only c-expert is required.

## Validation Plan

### BUG-029: Buffs
- [ ] Cast Alacrity (haste) on a companion → buff applies, no "did not take hold"
- [ ] Cast a single-target heal on a companion → heals correctly
- [ ] Cast a group-only buff on a companion in the same group → applies correctly
- [ ] Cast a group-only buff on a companion NOT in your group → should fail
- [ ] Cast multiple buffs on a companion → all apply, stacking works correctly
- [ ] Verify companion stat bonuses update after buffing (CalcBonuses)
- [ ] Verify buff icons appear on companion (client pet buff window)
- [ ] Cast beneficial spell on a regular NPC (non-companion) → should still fail

### BUG-030: Charm Pet Controls
- [ ] Charm an NPC as enchanter → pet window appears
- [ ] Issue /pet attack command → pet attacks target
- [ ] Issue /pet follow command → pet follows caster
- [ ] Issue /pet guard here command → pet guards position
- [ ] Issue /pet sit down command → pet sits
- [ ] Issue /pet back off command → pet stops attacking
- [ ] Let charm break → pet window disappears immediately
- [ ] After charm break, no lingering pet commands in UI
- [ ] Review server logs for diagnostic output from added logging

### BUG-031: Gear Duplication
- [ ] Trade equippable item to a companion → item equipped, not returned
- [ ] Trade non-equippable item to companion → item returned, not equipped
- [ ] Trade item to a companion whose NPC type has a per-NPC PEQ quest script → no duplication
- [ ] Verify companion says "Thank you" only once per successful equip
- [ ] Verify no "I have no use for this" message when item IS equipped
- [ ] Check player inventory after trade → no duplicate items
- [ ] Trade multiple items at once → all handled correctly

---

> **Next step:** Spawn the implementation team with ONLY the agents listed
> in "Required Implementation Agents" above. Do not spawn experts without
> assigned tasks.
