# Companion Group Commands — Dev Notes: Lua Expert

> **Feature branch:** `feature/companion-group-commands`
> **Agent:** lua-expert
> **Task(s):** Tasks 1-5
> **Date started:** 2026-03-11
> **Current stage:** Build

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 1 | Implement !status (enhanced), !help (updated), !equipmentmissing, !follow (enhanced feedback) | — | Complete |
| 2 | Implement !tome, !flee, !assist (enhanced with auto-stance) | — | Complete |
| 3 | Implement !buffme, !buffs with timer-based buff queue | — | Complete |
| 4 | Implement !equipmentupgrade with item link parsing and stat comparison | — | Complete |
| 5 | Update COMMANDS table and cmd_help reference card | 1, 2, 3, 4 | Complete |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `akk-stack/server/quests/lua_modules/companion.lua` | 1-798 | Full companion module — COMMANDS table at line 91, existing handlers for status/help/assist/follow/recall |
| `akk-stack/server/quests/global/global_npc.lua` | 1-461 | event_say, event_timer (gsay_deliver_ and comp_commentary_ timers), event_death_zone |
| `claude/project-work/feature/companion-group-commands/architect/architecture.md` | all | Full architecture spec — pure Lua, entity variables for buff queue, timer-based processing |
| `claude/project-work/feature/companion-group-commands/protocol-agent/dev-notes.md` | all | CompanionGroupSay() required (not client:Message()), no \n in group chat, item link 56-char internal format |

### Key Findings

1. **All responses must use CompanionGroupSay()** — existing cmd_status() and cmd_help() use `client:Message()` which must be changed
2. **Multi-line = multiple CompanionGroupSay() calls** — Titanium doesn't render \n in group chat
3. **companion.lua is at** `/mnt/d/Dev/eq/akk-stack/server/quests/lua_modules/companion.lua`
4. **global_npc.lua event_timer** already handles `gsay_deliver_` and `comp_commentary_` patterns — we add `buff_request_` pattern here
5. **Buff queue** uses entity variable `buff_request_target` ("owner" or "party") + timer `buff_request_<npc_id>`
6. **Item link parsing**: `\x12` = byte 18 in Lua `string.find(msg, "\18")`. Body is 45 chars after opener. Item ID = bytes 2-6 of body (5 hex chars), `tonumber(hex, 16)`
7. **IsSitting()** is overridden on Companion class (companion.h line 443)
8. **GetBuffs()** returns table of Lua_Buff objects
9. **@all !help deduplication**: data bucket with 1-second TTL, key = "help_lock_<zone_id>"
10. **NPC_RACE_TO_PLAYER_RACE** table already exists in global_npc.lua — NOT accessible from companion.lua; equipment restriction logic lives in event_trade. For equipmentupgrade, we use the same companion_find_slot pattern and build a local race table.

### Implementation Plan

**Files to modify:**
| File | Action | What Changes |
|------|--------|-------------|
| `akk-stack/server/quests/lua_modules/companion.lua` | Modify | Add 9 new handler functions, update COMMANDS table, update cmd_help, convert cmd_status and cmd_help to CompanionGroupSay |
| `akk-stack/server/quests/global/global_npc.lua` | Modify | Add buff_request_ timer handler to event_timer() |

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `npc:GetBuffs(L)` → Lua_Buff table | architecture.md + LUA-CODE.md | Yes | Returns table with entries iterable |
| `buff:GetSpellID()`, `buff:GetTicsRemaining()` | architecture.md | Yes | Available on Lua_Buff |
| `eq.get_spell_name(spell_id)` | architecture.md | Yes | Returns spell name string |
| `npc:IsSitting()` | architecture.md (companion.h:443) | Yes | Overridden on Companion |
| `npc:GetStance()`, `npc:SetStance(int)` | architecture.md, existing code | Yes | 0=passive,1=balanced,2=aggressive |
| `npc:SetGuardMode(bool)` | existing cmd_follow | Yes | false=follow, true=guard |
| `npc:RunTo(x,y,z)` | architecture.md | Yes | Pathed movement |
| `npc:CalculateDistance(mob)` | architecture.md | Yes | Returns float |
| `npc:WipeHateList()` | existing cmd_passive | Yes | Available |
| `npc:GetTarget()` | architecture.md | Yes | Returns mob or nil |
| `npc:GetEquipment(slot)` | architecture.md | Yes | Returns item_id (0=empty) |
| `eq.get_data()`, `eq.set_data()` | existing cmd_recall | Yes | Data bucket API |
| `npc:SetEntityVariable()`, `npc:GetEntityVariable()` | global_npc.lua | Yes | In-memory per-entity |
| `eq.set_timer()`, `eq.stop_timer()` | global_npc.lua | Yes | Timer API |
| `string.find(msg, "\18")` | architecture.md (Lua \x12=18) | Yes | Find item link delimiter |
| `tonumber(hex_str, 16)` | Lua standard | Yes | Hex conversion |
| `npc:GetManaRatio()` | architecture.md | Yes | Returns float 0-100 |
| `npc:IsEngaged()` | architecture.md (existing checks) | Yes | Combat state |
| `npc:IsAttackAllowed(target)` | architecture.md | Yes | Friendly/hostile check |
| `client:GetTarget()` | existing cmd_assist | Yes | Returns mob or nil |
| `group:GroupMessage(speaker, msg)` | global_npc.lua:90 | Yes | Group chat delivery |
| `client:GetGroup()` | global_npc.lua:88 | Yes | Returns group or nil |
| `npc:CompanionGroupSay(msg)` | protocol-agent notes (companion.cpp:2263) | Yes | C++ bound method |

### Plan Amendments

One key question: does `npc:CompanionGroupSay(msg)` exist as a Lua binding, or must we call `group:GroupMessage(npc, msg)` directly?

Looking at the protocol-agent notes: "CompanionGroupSay: char buf[4096], calls GroupMessage". And global_npc.lua uses `group:GroupMessage(e.self, response)` directly. The architecture says to use `CompanionGroupSay()` but global_npc.lua uses the direct `group:GroupMessage` call. I'll use a local helper function `companion_say(npc, client, msg)` that mirrors what global_npc.lua does — gets the owner's group and calls `group:GroupMessage(npc, msg)`, falling back to `npc:Say(msg)` if no group.

---

## Stage 3: Socialize

All design decisions are from the architecture doc (approved). Protocol-agent findings are incorporated. No blocking questions remain.

### Consensus Plan

**Implementation approach:**

1. Add `local function companion_say(npc, client, msg)` helper at top of companion.lua's handler section — wraps group:GroupMessage call with fallback to npc:Say()
2. Update `cmd_status` — convert to CompanionGroupSay, add buffs/target/sit/follow
3. Update `cmd_follow` — add CompanionGroupSay feedback
4. Add `cmd_equipmentmissing` — iterate slots 0-22 (skip 21), report empty ones
5. Update `cmd_help` — convert to CompanionGroupSay, add @all deduplication, add new commands
6. Add `cmd_tome` — RunTo with proximity check
7. Add `cmd_flee` — passive + RunTo + follow mode
8. Update `cmd_assist` — add dead check, auto-stance-switch, better error messages, CompanionGroupSay
9. Add `cmd_buffme` — entity variable + timer
10. Add `cmd_buffs` — entity variable + timer
11. Add `parse_item_link(msg)` helper
12. Add `cmd_equipmentupgrade` — parse link, compare stats
13. Update COMMANDS table — add new entries
14. Update cmd_help topic handlers
15. Add buff_request_ timer handler to global_npc.lua event_timer()

---

## Stage 4: Build

### Implementation Log

#### 2026-03-11 — Full implementation of all 9 new/updated commands

**What:** Rewrote companion.lua with all new command handlers, updated COMMANDS table, and added buff timer handler to global_npc.lua

**Where:**
- `/mnt/d/Dev/eq/akk-stack/server/quests/lua_modules/companion.lua` — main file
- `/mnt/d/Dev/eq/akk-stack/server/quests/global/global_npc.lua` — buff timer

**Why:** Feature implementation per architecture.md

**Key decisions:**
- `companion_say(npc, client, msg)` helper resolves the CompanionGroupSay vs group:GroupMessage question by reusing the same pattern as global_npc.lua's stagger-free path
- Buff timer: entity variable `buff_request_target` + `buff_request_<npc_id>` timer. Timer handler in global_npc.lua checks IsEngaged/IsCasting, iterates group members, casts buffs on appropriate targets
- Item link parsing: `\x12` = `\18` in Lua. Body is 45 chars. item_id at chars 2-6 of body (1-indexed). Use `string.byte` approach via `string.find` to locate delimiters.
- @all !help deduplication: data bucket key `"help_lock_" .. eq.get_zone_id()` with 1s TTL
- !flee: does NOT wipe hate list (intentional per PRD)
- !assist: auto-switches passive→balanced before engaging

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `akk-stack/server/quests/lua_modules/companion.lua` | Modified | All 9 commands implemented |
| `akk-stack/server/quests/global/global_npc.lua` | Modified | Buff timer handler added to event_timer() |
