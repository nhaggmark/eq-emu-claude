# Companion Audit Pass 2 — Dev Notes: Lua Expert

> **Feature branch:** `feature/companion-audit-pass2`
> **Agent:** lua-expert
> **Task(s):** Task #2 — Second-pass audit of companion system Lua code
> **Date started:** 2026-03-15
> **Current stage:** Complete

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 2 | Lua second-pass audit: verify fixes, test coverage gaps, C++ contract issues | Task #1 (architect audit) | Complete |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `claude/docs/topography/LUA-CODE.md` | full | API surface, event system, `Lua_Companion` not listed as standard bound class |
| `claude/project-work/companion-authenticity-audit/architect/architecture.md` | full | 14 gaps; GAP-12/13/14/17 are Lua-layer |
| `akk-stack/server/quests/lua_modules/companion.lua` | 1–600 (3 chunks) | Core module; recruitment tracks; command handlers; nil-guard patterns |
| `akk-stack/server/quests/lua_modules/companion_commentary.lua` | 1–177 | Commentary timer; GAP-12 channel routing fix |
| `akk-stack/server/quests/lua_modules/companion_culture.lua` | 1–622 | Pure Lua culture logic; no C++ contract issues |
| `akk-stack/server/quests/global/global_npc.lua` | 1–709 | Event handlers; GAP-13 level-up handler; timer routing |
| `akk-stack/server/quests/lua_modules/client_ext.lua` | 1–337 | `GetFaction()` luabind workaround; `CastToNPC()` unguarded |
| `akk-stack/server/quests/tests/test_companion_recruitment.lua` | 1–1001 | Recruitment test coverage |
| `akk-stack/server/quests/tests/test_companion_commands_regression.lua` | 1–721 | Command handler coverage |
| `akk-stack/server/quests/tests/test_buff_queue.lua` | 1–1126 | Buff queue coverage |
| `akk-stack/server/quests/tests/test_companion_cmd_assist.lua` | 1–517 | Assist command coverage |
| `akk-stack/server/quests/tests/test_companion_cmd_help.lua` | 1–527 | Help command coverage |
| `akk-stack/server/quests/tests/test_companion_cmd_hold.lua` | 1–454 | Hold command coverage |
| `akk-stack/server/quests/tests/test_companion_cmd_tome.lua` | 1–474 | Tome command coverage |

---

## Stage 2: Research (Audit Findings)

This task was a pure research/audit — no code changes. All three focus areas are documented below.

---

### Focus 1: Fix Verification

All 5 fixes verified against master source.

#### FIX-01: Recruitment Overhaul (two-track system)

**Status: VERIFIED**

`companion.lua` — `attempt_recruitment()`:

- Calls `check_existing_companion_record(npc, client)` FIRST, before any cooldown/level/faction check
- `check_existing_companion_record` queries: `WHERE owner_id=? AND npc_type_id=? AND (is_dismissed=1 OR is_suspended=1) LIMIT 1`
- If record found: routes to `is_re_recruitment_eligible()` which calls `_on_recruitment_success()` directly, bypassing all gating
- If no record: runs full first-time recruitment gating (cooldown, level, faction, persuasion)
- Re-recruitment track: `is_re_recruitment_eligible()` checks HP > 0 (not dead) and verifies owner match, then succeeds

**Observation:** The two-track detection is correct and robust. The `check_existing_companion_record` SQL correctly uses OR logic for both dismissed and suspended states. No issues found.

#### FIX-02: GAP-12 Commentary Channel Routing

**Status: VERIFIED**

`companion_commentary.lua` — `check_and_speak()`, lines 158–173:

```lua
local group = client:GetGroup()
if group and group.valid then
    group:GroupMessage(npc, response)
else
    npc:Say(response)
end
```

Routes through `group:GroupMessage(npc, response)` matching the same pattern used for all other companion dialogue. Falls back to `npc:Say()` only for ungrouped owners. Fix is correct and consistent with the pattern in `companion.lua`'s `companion_say()` helper.

**Observation:** Fix matches the `companion_say()` helper pattern exactly. Good consistency.

#### FIX-03: GAP-13 Level-Up Handler

**Status: VERIFIED**

`global_npc.lua` — `event_level_up`, lines 600–648:

- Handler exists and is gated by `e.self:IsCompanion()` guard
- On trigger: fetches owner via `GetOwnerCharacterID()`, retrieves companion record from DB, recalculates scaled stats using `companion.calculate_stats()`, calls `companion.apply_stats()` to push updated values
- Uses pcall around DB call for safety
- Sends congratulatory message via `companion_say()` (group-aware)

**Observation:** `event_level_up` is an NPC event, not a player event. The handler fires when the companion NPC levels up, not when the player does. The guard `IsCompanion()` is critical — this event fires for any NPC level change, not just companions. Handler is correctly scoped.

#### FIX-04: GAP-14 REREC_BONUS Removal

**Status: VERIFIED**

Searched all of `companion.lua` — the constant `REREC_BONUS` and any xp bonus multiplier for re-recruitment are absent. The re-recruitment path calls `_on_recruitment_success()` which applies standard companion initialization without any XP modifier.

**Observation:** Clean removal. No residual references or dead code.

#### FIX-05: Nil-Guard Status (GAP-17 Workaround)

**Status: VERIFIED WITH EXCEPTIONS**

`companion.lua` applies nil-guards to all known Companion-specific methods:
- `npc.SetStance and npc:SetStance(v)` — guarded
- `npc.SetGuardMode and npc:SetGuardMode(v)` — guarded
- `npc.GetGuardMode and npc:GetGuardMode()` — guarded
- `npc.GetCompanionType and npc:GetCompanionType()` — guarded
- `npc.GetStance and npc:GetStance()` — guarded
- `npc.GetCompanionID and npc:GetCompanionID()` — guarded
- `npc.GetCombatRole and npc:GetCombatRole()` — guarded

**Exception:** `GetOwnerCharacterID()` in `companion_commentary.lua:133` is called WITHOUT a nil-guard. See CONTRACT-01 below.

**Exception:** `client_ext.lua` pcall-guards `GetPrimaryFaction()` (correctly) but `CastToNPC()` is not protected. See CONTRACT-03 below.

---

### Focus 2: Test Coverage Gaps

#### GAP-TC-01: Commentary system has zero test coverage

**Severity: High**

`companion_commentary.lua` (177 lines, non-trivial logic) has no test file. The module contains:
- `detect_context_change()` — zone change, named kill, idle detection logic
- `check_and_speak()` — multi-guard chain: alive, not in combat, grace period, hard cap, context change, probability roll, LLM call, channel routing

No tests for any of these paths. A crash in the commentary timer silently kills periodic behavior — hard to diagnose without coverage.

**Missing test scenarios:**
- Grace period blocks early commentary
- Hard cap blocks repeated commentary within the window
- `detect_context_change` returns correct trigger type for each of: zone_change, named_kill, idle
- `detect_context_change` returns false when no change
- Combat block suppresses commentary when `IsEngaged()` is true
- Probability roll (mock `math.random` to control)
- `comp_named_kill` flag cleared after successful comment
- `comp_last_zone` updated after zone-change comment

#### GAP-TC-02: Culture system has zero test coverage

**Severity: Medium**

`companion_culture.lua` (622 lines) has no test file. Contains 11 event types, race-specific framing for 14 races, and identity evolution tier logic. Pure Lua logic — highly testable without mocking.

**Missing test scenarios:**
- Each of the 11 culture event types returns non-nil context
- Race-specific framing for all 14 races
- Identity evolution tier transitions (tier 0 → 1 → 2 → 3 based on event count)
- Unknown race/event fallback paths

#### GAP-TC-03: Level-up handler not tested

**Severity: High**

`global_npc.lua:event_level_up` (lines 600–648) is untested. This is a non-trivial handler that:
- Guards on `IsCompanion()`
- Fetches owner via `GetOwnerCharacterID()`
- Queries DB for companion record
- Recalculates and applies scaled stats
- Sends level-up message

**Missing test scenarios:**
- Non-companion NPC fires `event_level_up` — handler exits cleanly (guard test)
- Companion NPC fires `event_level_up` — stats recalculated and applied
- DB query returns nil (no companion record) — handler exits cleanly
- `apply_stats()` called with correct calculated values

#### GAP-TC-04: `client_ext.lua:GetFaction()` workaround untested

**Severity: Medium**

`client_ext.lua:GetFaction()` (lines 64–75) contains the luabind GAP-17 workaround for `GetPrimaryFaction()`. The pcall + `CastToNPC()` logic is untested.

**Missing test scenarios:**
- Standard NPC: `GetPrimaryFaction()` returns value directly
- Companion NPC: `GetPrimaryFaction()` returns nil, falls through to `CastToNPC()` path
- `CastToNPC()` returns nil — function returns default faction
- Faction bypass flag set: returns max faction regardless

#### GAP-TC-05: `event_trade` (equipment slot handling) not tested

**Severity: Medium**

`global_npc.lua:event_trade` contains full slot matching, class/race restriction checks, and item rejection logic for companion equipment. No test file covers this path.

**Missing test scenarios:**
- Valid item for valid slot accepted
- Invalid slot rejects item and returns it
- Class restriction violation rejects item
- Race restriction violation rejects item
- Trade to non-companion NPC passes through (guard test)

#### GAP-TC-06: `event_death_zone` kill tracking not tested

**Severity: Low**

`global_npc.lua:event_death_zone` sets `comp_named_kill` and updates `comp_recent_kills`. The entity variable serialization and named NPC detection logic is untested.

**Missing test scenarios:**
- Named NPC killed: `comp_named_kill` set to "1" on companion
- Non-named NPC killed: `comp_named_kill` not set
- `comp_recent_kills` maintained as comma-separated list of last 5 kills
- 6th kill pushes oldest off the list

#### GAP-TC-07: Re-recruitment SQL query edge cases

**Severity: Medium**

`check_existing_companion_record` is tested for the happy path (both flags set, one flag set) but missing edge cases.

**Missing test scenarios:**
- Companion record exists but `is_dismissed=0` AND `is_suspended=0` — should NOT be found (this NPC is currently active, not re-recruitable)
- Multiple companion records for same owner+npc_type — LIMIT 1 behavior tested?
- `owner_id` mismatch — returns nil

#### GAP-TC-08: Buff queue Phase 1 ordering

**Severity: Low**

`test_buff_queue.lua` tests Phase 1 queue building but does not verify the priority ordering of entries (owner first, then party members, then NPC companions, then solo fallback).

**Missing test scenarios:**
- Party of 3 + owner: verify owner is slot 0, party members follow in order
- Party with 2 NPC companions: verify NPC companions queued after player party members

#### GAP-TC-09: Commentary hard cap timer not integration-tested

**Severity: Low**

`test_companion_commands_regression.lua` does not cover the commentary timer entry in `event_timer`. While commentary has no unit tests (GAP-TC-01), it also has no integration test via `event_timer` dispatch.

**Missing test scenarios:**
- `event_timer` with timer name `comp_commentary_<id>` dispatches to `companion_commentary.check_and_speak()`
- Timer cleanup after companion dismissal

#### GAP-TC-10: `dispatch_prefix_command` with unknown command

**Severity: Low**

`test_companion_commands_regression.lua` tests all 23 known commands but does not test the fallback for an unknown `!` prefix command.

**Missing test scenarios:**
- `!unknowncmd` dispatched to a companion: returns friendly "unknown command" response
- `!` with empty string: handled gracefully

---

### Focus 3: Lua → C++ Contract Issues

#### CONTRACT-01: `GetOwnerCharacterID()` unguarded in commentary

**Severity: High**
**File:** `akk-stack/server/quests/lua_modules/companion_commentary.lua:133`

```lua
local owner_char_id = npc:GetOwnerCharacterID()
```

`GetOwnerCharacterID()` is a Companion-specific method. Due to GAP-17 (luabind inheritance), if this method is not present on the bound `Lua_Companion` class, this call returns nil rather than throwing — the nil check `if owner_char_id == 0 then return end` will not catch a nil return (nil ~= 0 in Lua, so `nil == 0` is false, the guard is bypassed).

**Risk:** Commentary timer proceeds past owner check with a nil `owner_char_id`, then passes nil to `GetClientByCharID(nil)` — undefined C++ behavior.

**Fix needed:** Nil-guard before the zero check:
```lua
if not owner_char_id or owner_char_id == 0 then return end
```

**Contract status:** Broken. The `GetOwnerCharacterID()` call should also be wrapped in a nil-guard like all other Companion-specific calls in `companion.lua`.

#### CONTRACT-02: `check_and_speak()` not pcall-wrapped at call site

**Severity: Medium**
**File:** `akk-stack/server/quests/global/global_npc.lua` (commentary timer dispatch)

```lua
companion_commentary.check_and_speak(e.self)
```

The commentary check is invoked directly without pcall. An unhandled error inside `check_and_speak()` (including the CONTRACT-01 nil propagation) will unwind the timer event handler and potentially crash the zone process.

All other Lua→LLM calls in this codebase are pcall-wrapped. Commentary is the exception.

**Fix needed:** Wrap the call:
```lua
local ok, err = pcall(function() companion_commentary.check_and_speak(e.self) end)
if not ok then eq.log("companion commentary error: " .. tostring(err)) end
```

**Contract status:** Inconsistent with project pcall discipline. Should be wrapped.

#### CONTRACT-03: `CastToNPC()` unguarded in `client_ext.lua:GetFaction()`

**Severity: Medium**
**File:** `akk-stack/server/quests/lua_modules/client_ext.lua:64–75`

```lua
local ok, faction = pcall(function() return npc:GetPrimaryFaction() end)
if not ok or faction == nil then
    -- fallback: try cast
    local as_npc = npc:CastToNPC()   -- NOT pcall-wrapped
    if as_npc then
        faction = as_npc:GetPrimaryFaction()
    end
end
```

`CastToNPC()` is a Companion-specific method (or may not exist on all NPC subclasses). If it returns nil, the inner `GetPrimaryFaction()` call is protected by the nil check. However, if `CastToNPC()` itself throws rather than returning nil, the error propagates uncaught.

**Risk:** Faction check during recruitment or commentary LLM context building throws, breaking the calling path.

**Fix needed:** Wrap `CastToNPC()` call in pcall or add `.valid` check on the result.

**Contract status:** Partially protected. The outer pcall guards `GetPrimaryFaction()` failure, but not `CastToNPC()` failure.

#### CONTRACT-04: `Database()` prepared statement not checked for nil

**Severity: Low**
**File:** `akk-stack/server/quests/lua_modules/companion.lua` (multiple DB call sites)

EQEmu's `Database()` constructor returns a `Lua_Database` object. If the database connection is unavailable (e.g., MariaDB down), the constructor may return nil. Several call sites in `companion.lua` call methods on the returned object without a nil check:

```lua
local db = Database()
local results = db:QueryDatabase(sql, params)  -- crashes if db is nil
```

**Risk:** Database outage crashes zone instead of failing gracefully.

**Fix needed:** `if not db then return end` guard after `Database()` construction.

**Contract status:** Low-risk in practice (DB down = zone down anyway), but inconsistent with the codebase's defensive pcall discipline.

#### CONTRACT-05: `eq.get_entity_list():GetClientByCharID()` chain unguarded

**Severity: Low**
**File:** `akk-stack/server/quests/lua_modules/companion_commentary.lua:136`

```lua
local client = eq.get_entity_list():GetClientByCharID(owner_char_id)
```

`eq.get_entity_list()` is documented to always return a valid entity list object. However, `GetClientByCharID()` returns nil if the client is not in the current zone (e.g., zoning, disconnected). The subsequent `if not client or not client.valid then return end` guard is correct and handles this case.

**Status:** This is correctly handled. Listed for completeness — no fix needed.

---

### Contract Issue Summary Table

| ID | Severity | File | Line | Issue | Fix Needed |
|----|----------|------|------|-------|------------|
| CONTRACT-01 | High | `companion_commentary.lua` | 133 | `GetOwnerCharacterID()` missing nil-guard; `nil ~= 0` bypasses owner check | Add `if not owner_char_id or owner_char_id == 0` |
| CONTRACT-02 | Medium | `global_npc.lua` | commentary timer | `check_and_speak()` not pcall-wrapped | Wrap in pcall with error logging |
| CONTRACT-03 | Medium | `client_ext.lua` | 64–75 | `CastToNPC()` not pcall-protected | Wrap `CastToNPC()` call in pcall |
| CONTRACT-04 | Low | `companion.lua` | multiple | `Database()` result not nil-checked before method calls | Add nil guard after `Database()` |
| CONTRACT-05 | None | `companion_commentary.lua` | 136 | `GetClientByCharID()` — correctly guarded | No fix needed |

---

### Fix Verification Summary Table

| Fix | Gap | Status | Notes |
|-----|-----|--------|-------|
| FIX-01 | Recruitment overhaul | VERIFIED | Two-track detection correct; SQL query correct |
| FIX-02 | GAP-12 commentary channel | VERIFIED | `group:GroupMessage()` routing matches `companion_say()` pattern |
| FIX-03 | GAP-13 level-up handler | VERIFIED | Handler exists; guarded by `IsCompanion()` |
| FIX-04 | GAP-14 REREC_BONUS removal | VERIFIED | No residual references found |
| FIX-05 | Nil-guards (GAP-17) | VERIFIED WITH EXCEPTIONS | All Companion-specific methods guarded EXCEPT `GetOwnerCharacterID()` in commentary |

---

## Stage 3: Socialize

This was a research-only task. No code changes were made, so no socialization of implementation plans was required. Findings have been written to this file for team-lead to review and assign to implementation experts as appropriate.

---

## Stage 4: Build

No code was written. This task was audit-only.

---

## Open Items / Recommended Next Steps

The following issues are prioritized by severity for implementation team:

### High Priority (should fix before ship)

- [ ] **CONTRACT-01** — Fix nil-guard on `GetOwnerCharacterID()` in `companion_commentary.lua:133`
- [ ] **CONTRACT-02** — Wrap `check_and_speak()` call in pcall in `global_npc.lua`
- [ ] **GAP-TC-01** — Add test file for `companion_commentary.lua`
- [ ] **GAP-TC-03** — Add tests for `event_level_up` handler in `global_npc.lua`

### Medium Priority (should fix before ship)

- [ ] **CONTRACT-03** — Pcall-protect `CastToNPC()` in `client_ext.lua:GetFaction()`
- [ ] **GAP-TC-02** — Add test file for `companion_culture.lua`
- [ ] **GAP-TC-04** — Add tests for `client_ext.lua:GetFaction()` luabind workaround
- [ ] **GAP-TC-05** — Add tests for `event_trade` equipment slot handling
- [ ] **GAP-TC-07** — Add edge case tests for `check_existing_companion_record` SQL

### Low Priority (nice to have)

- [ ] **CONTRACT-04** — Nil-guard `Database()` return value
- [ ] **GAP-TC-06** — Add tests for `event_death_zone` kill tracking
- [ ] **GAP-TC-08** — Verify buff queue Phase 1 priority ordering in tests
- [ ] **GAP-TC-09** — Integration test commentary timer dispatch via `event_timer`
- [ ] **GAP-TC-10** — Test `dispatch_prefix_command` with unknown command

---

## Context for Next Agent

The companion system Lua code is in good shape for the 5 verified fixes. The two highest-risk issues are:

1. **CONTRACT-01**: `GetOwnerCharacterID()` in `companion_commentary.lua:133` — nil return from this Companion-specific method bypasses the `== 0` guard because `nil ~= 0`. This can cause `GetClientByCharID(nil)` to be called. Fix: `if not owner_char_id or owner_char_id == 0 then return end`

2. **CONTRACT-02**: The commentary dispatch in `global_npc.lua` is the only timer handler NOT wrapped in pcall. An error in `check_and_speak()` (including CONTRACT-01) propagates uncaught.

These two issues are in adjacent lines of the same call chain: commentary timer fires → `check_and_speak()` called unprotected → `GetOwnerCharacterID()` nil return bypasses guard → nil passed to C++ API.

Key files for any follow-up implementation work:
- `akk-stack/server/quests/lua_modules/companion_commentary.lua` — lines 130–140 (CONTRACT-01, CONTRACT-02)
- `akk-stack/server/quests/global/global_npc.lua` — commentary timer dispatch (CONTRACT-02)
- `akk-stack/server/quests/lua_modules/client_ext.lua` — lines 64–75 (CONTRACT-03)
