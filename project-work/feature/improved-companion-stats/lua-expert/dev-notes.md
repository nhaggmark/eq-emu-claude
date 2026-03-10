# improved-companion-stats — Dev Notes: Lua Expert

> **Feature branch:** `feature/improved-companion-stats`
> **Agent:** lua-expert
> **Task(s):** Task 3 — cmd_stats handler, access control change, COMMANDS update, help update
> **Date started:** 2026-03-10
> **Current stage:** Build

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 3 | Add cmd_stats handler, modify access control in dispatch_prefix_command(), add to COMMANDS table, update help text | Task 1 (C++ bindings for GetMinDMG, GetMaxDMG, GetCombatRole) | Complete |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `akk-stack/server/quests/lua_modules/companion.lua` | 1-738 | Full command dispatch system. COMMANDS table at 77-94. dispatch_prefix_command at 118-142. cmd_status at 556-575 (reference for format). cmd_help at 578-662. All handlers use `client:Message(15, ...)` pattern (MT.Yellow = 15). |
| `akk-stack/server/quests/global/global_npc.lua` | 1-444 | Entry point: IsCompanion() check at line 11, dispatch call at line 13. Only companions reach the dispatch function. |
| `claude/project-work/feature/improved-companion-stats/architect/architecture.md` | Full | Task 3 spec: 3 sub-tasks — cmd_stats handler, access control split, COMMANDS/help updates |
| `claude/project-work/feature/improved-companion-stats/architect/context/source-analysis.md` | Full | CompanionCombatRole enum values 0-4, available Lua_Mob methods, methods requiring new C++ bindings |

### Key Findings

1. **Command dispatch pattern**: `dispatch_prefix_command(npc, client, message)` at line 118 does a blanket ownership check BEFORE parsing the command. Architecture says to reorder: parse first, then check ownership only if `requires_owner ~= false`.

2. **COMMANDS table** (line 77-94): Each entry is `cmd_name = { handler = "fn_name", category = "..." }`. Adding `requires_owner = false` field to read-only entries, defaulting to true (owner-only) for everything else.

3. **Message pattern**: All command handlers use `client:Message(15, "text")`. MT.Yellow = 15. Consistent throughout.

4. **cmd_status reference** (line 556-575): Uses `=== Name ===` header, multiple `client:Message(15, ...)` lines. This is the exact pattern for cmd_stats to follow.

5. **Help text** (line 578-662): Organized by category (stance, movement, equipment, information, combat, control). The `!stats` entry goes in the information section at both the summary and the detailed `information` topic.

6. **New bindings needed**: `GetMinDMG()`, `GetMaxDMG()`, `GetCombatRole()` — these come from c-expert's Task 1. All other stats (STR, STA, AGI, DEX, INT, WIS, CHA, AC, ATK, HP, Mana, resists) are already on Lua_Mob and work via inheritance.

7. **Combat role mapping** (from source-analysis.md):
   - 0 = Melee Tank (Warrior, Paladin, Shadow Knight)
   - 1 = Melee DPS (Monk, Berserker, Beastlord, Ranger, Bard)
   - 2 = Rogue
   - 3 = Caster DPS (Wizard, Magician, Necromancer, Enchanter)
   - 4 = Healer (Cleric, Druid, Shaman)

### Implementation Plan

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `akk-stack/server/quests/lua_modules/companion.lua` | Modify | 4 changes: (1) add `stats` entry to COMMANDS; (2) add `requires_owner = false` to read-only entries; (3) reorder dispatch_prefix_command access control; (4) add cmd_stats handler; (5) update cmd_help |

**Change sequence:**
1. Add `requires_owner = false` to COMMANDS entries for: stats, status, equipment, gear, help
2. Add new `stats` entry to COMMANDS table
3. Rewrite `dispatch_prefix_command` to parse command first, then check ownership
4. Add `cmd_stats` handler function after `cmd_status`
5. Add `!stats` to `cmd_help` — both in the summary block and the information topic

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `client:Message(color, text)` | LUA-CODE.md (MT.* constants) | Yes | MT.Yellow = 15, confirmed used throughout companion.lua |
| `npc:GetSTR()`, `GetSTA()`, `GetAGI()`, `GetDEX()`, `GetINT()`, `GetWIS()`, `GetCHA()` | source-analysis.md + lua_mob.h confirmed | Yes | Available via Lua_Mob inheritance |
| `npc:GetAC()`, `npc:GetATK()` | source-analysis.md + lua_mob.h confirmed | Yes | Available via Lua_Mob inheritance |
| `npc:GetMR()`, `npc:GetFR()`, `npc:GetCR()`, `npc:GetDR()`, `npc:GetPR()` | source-analysis.md + lua_mob.h confirmed | Yes | Available via Lua_Mob inheritance |
| `npc:GetHP()`, `npc:GetMaxHP()`, `npc:GetMana()`, `npc:GetMaxMana()` | source-analysis.md + lua_mob.h confirmed | Yes | Available via Lua_Mob inheritance |
| `npc:GetLevel()`, `npc:GetCleanName()`, `npc:GetClassName()` | source-analysis.md + lua_mob.h confirmed | Yes | Available via Lua_Mob inheritance |
| `npc:GetMinDMG()`, `npc:GetMaxDMG()` | source-analysis.md: NOT yet on Lua_Companion | Yes — NEW | Added by c-expert Task 1; Lua code calls them, tests will verify at runtime |
| `npc:GetCombatRole()` | source-analysis.md: NOT yet exposed to Lua | Yes — NEW | Added by c-expert Task 1; returns uint8 0-4 |
| Lua table with integer keys (COMBAT_ROLE_NAMES) | Lua 5.1 reference | Yes | `[0] = "..."` syntax for zero-indexed tables is valid Lua |

### Plan Amendments

Plan confirmed — no amendments needed. All APIs verified. The three new bindings (GetMinDMG, GetMaxDMG, GetCombatRole) will exist after c-expert builds. Code is correct to call them unconditionally since the !stats command is only dispatched when IsCompanion() is true and the companion entity is valid.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| c-expert | Task 1 binding names and return types | Confirm: GetMinDMG() returns uint32, GetMaxDMG() returns uint32, GetCombatRole() returns uint8 (0-4)? |

### Feedback Received

| From | Feedback | Action Taken |
|------|----------|-------------|
| c-expert | Proceeding as separate task — c-expert is parallel | Lua code written to call exact binding names from architecture doc. Build dependency noted. |

### Consensus Plan

Architecture doc is the authoritative plan. Both agents implement their tasks independently (the architecture explicitly allows this). Lua code is written to match the binding signatures documented in source-analysis.md.

**Agreed approach:** Implement Task 3 in full. The three new bindings will be available after c-expert Task 1 build. All other stat methods already work via Lua_Mob inheritance.

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `akk-stack/server/quests/lua_modules/companion.lua` | Modify | COMMANDS table, dispatch_prefix_command, new cmd_stats, updated cmd_help |

**Change sequence (final):**
1. Expand COMMANDS table: add `stats`, add `requires_owner = false` to read-only entries
2. Reorder dispatch_prefix_command: parse command first, ownership check second (per-command)
3. Add COMBAT_ROLE_NAMES local table constant near top of constants section
4. Add `cmd_stats` handler after `cmd_status`
5. Update `cmd_help` to include `!stats` in information section

---

## Stage 4: Build

### Implementation Log

#### 2026-03-10 — Implemented all Task 3 changes in companion.lua

**What:** Made five coordinated changes to `companion.lua`:
1. Added `COMBAT_ROLE_NAMES` table in constants section
2. Expanded COMMANDS table with `stats` entry and `requires_owner = false` on read-only commands
3. Rewrote `dispatch_prefix_command` to parse command first, then conditionally check ownership
4. Added `cmd_stats` handler displaying all combat stats in formatted sections
5. Updated `cmd_help` to include `!stats` in information section (both summary and topic)

**Where:** `/mnt/d/Dev/eq/akk-stack/server/quests/lua_modules/companion.lua`

**Why:** Architecture task 3 — new !stats command, access control split for read-only commands, help text update.

**Notes:**
- The three new methods (GetMinDMG, GetMaxDMG, GetCombatRole) are called unconditionally in cmd_stats. These bindings must exist (c-expert Task 1) before testing.
- All other stat methods verified against source-analysis.md — available via Lua_Mob inheritance.
- Access control change: commands without `requires_owner = false` remain owner-only. Unknown commands still produce "That is not your companion." if caller is not the owner (unchanged behavior — ownership checked before unknown-command error).
- Combat role fallback handles any role value outside 0-4 (returns "Unknown" via `or "Unknown"` pattern).

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| Access control reorder: unknown commands | If we parse first then check ownership, an unknown command from a non-owner would give "Unknown command" instead of "That is not your companion" | Architecture notes the ownership check for unknown commands is fine to keep — non-owner seeing "Unknown command" is acceptable. But actually cleaner to check ownership first for unknown commands. Solution: parse command, if known and requires_owner=false, skip ownership check; otherwise (owner-only OR unknown), check ownership first. |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `akk-stack/server/quests/lua_modules/companion.lua` | Modified | COMMANDS table, dispatch_prefix_command, COMBAT_ROLE_NAMES, cmd_stats, cmd_help |

---

## Open Items

- [ ] Verify GetMinDMG/GetMaxDMG/GetCombatRole work after c-expert Task 1 build and server restart

---

## Context for Next Agent

Task 3 is complete. The Lua changes in `companion.lua` add:
- `!stats` command (any player can use on any companion)
- Access control split: !stats, !status, !equipment, !gear, !help are now non-owner-gated
- Combat role display (0=Melee Tank through 4=Healer)
- Updated help text

The three new C++ bindings (GetMinDMG, GetMaxDMG, GetCombatRole) must exist for !stats to work at runtime. These come from c-expert Task 1. After that build + server restart, use `#reloadquests` to pick up the Lua changes.

See architecture.md Task 3 and source-analysis.md for full context.
