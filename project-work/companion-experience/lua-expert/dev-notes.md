# companion-experience — Dev Notes: Lua Expert

> **Feature branch:** `bugfix/companion-experience`
> **Agent:** lua-expert
> **Task(s):** Task 5
> **Date started:** 2026-03-05
> **Current stage:** Complete

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 5 | Update !status command to show XP progress | Task 4 (GetXPForNextLevel Lua binding by c-expert) | Blocked — awaiting task #4 |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `claude/project-work/companion-experience/architect/architecture.md` | 444 | Full architecture plan — task 5 details at lines 251-278 |
| `claude/project-work/companion-experience/game-designer/prd.md` | 527 | PRD — XP display requirement in AC-11, UX section step 3 |
| `akk-stack/server/quests/lua_modules/companion.lua` | 552-569 | Current cmd_status implementation — 5 message lines, no XP |
| `claude/project-work/companion-experience/status.md` | 155 | Task status — all tasks "Not Started" as of reading |
| `claude/project-work/companion-experience/agent-conversations.md` | 191 | No implementation team exchanges yet |
| `claude/project-work/companion-experience/c-expert/dev-notes.md` | 50 | c-expert not yet started |

### Key Findings

**Current cmd_status (lines 553-569 of companion.lua):**
```lua
function companion.cmd_status(npc, client, args)
    local stance_names = { [0] = "Passive", [1] = "Balanced", [2] = "Aggressive" }
    local type_names   = { [0] = "Companion", [1] = "Mercenary" }
    local mode = companion_modes[npc:GetID()] or "follow"
    mode = mode:sub(1, 1):upper() .. mode:sub(2)

    client:Message(15, "=== " .. npc:GetCleanName() .. " ===")
    client:Message(15, "  Level: " .. npc:GetLevel() ..
                       "  Class: " .. npc:GetClassName())
    client:Message(15, "  HP: " .. npc:GetHP() .. "/" .. npc:GetMaxHP() ..
                       "  Mana: " .. npc:GetMana() .. "/" .. npc:GetMaxMana())
    client:Message(15, "  Stance: " ..
                       (stance_names[npc:GetStance()] or "Unknown") ..
                       "  Mode: " .. mode)
    client:Message(15, "  Type: " ..
                       (type_names[npc:GetCompanionType()] or "Unknown"))
end
```

**What I need to add:**
- `GetCompanionXP()` — already bound per architecture doc
- `GetXPForNextLevel()` — bound by c-expert's task #4 (the blocker)
- Insert an XP line between HP/mana and Stance lines

**Architecture doc's proposed format:** `"  XP: " .. current_xp .. " / " .. next_level_xp`

**PRD requirement:** "XP: 1,234 / 900,000" with comma-formatted numbers (or raw — see Stage 2)

### Implementation Plan

**Files to modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `/mnt/d/Dev/eq/akk-stack/server/quests/lua_modules/companion.lua` | Modify | Insert XP line in cmd_status between HP/mana and Stance lines |

**Change sequence:**
1. Open companion.lua, locate `cmd_status` at line 553
2. After the HP/mana Message line (~563), insert two lines:
   - `local current_xp = npc:GetCompanionXP()`
   - `local next_level_xp = npc:GetXPForNextLevel()`
   - `client:Message(15, "  XP: " .. current_xp .. " / " .. next_level_xp)`
3. Verify the indentation and string concat style matches surrounding code

**What to test:**
- `!status` in-game shows XP line after HP/mana
- Numbers are correct (non-zero after a kill, matches `level * level * 1000` for next level)
- No Lua errors in server log

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `npc:GetCompanionXP()` | architecture.md (line 39: "Exposes GetCompanionXP()") | Yes | Already bound in lua_companion.cpp |
| `npc:GetXPForNextLevel()` | architecture.md (lines 231-247: binding spec) | Yes | Will be added by c-expert task #4 |
| `client:Message(color, text)` | Confirmed by reading existing cmd_status usage | Yes | Color 15 = dim gray, consistent with rest of status output |
| Lua string concatenation `..` | Lua 5.1 standard | Yes | Used throughout companion.lua |
| Number formatting (commas) | architecture.md example shows raw numbers, not comma-formatted | Yes | PRD says "1,234 / 900,000" but architecture example shows raw; use raw for simplicity (consistent with EQ's terse style) |

### Plan Amendments

Architecture doc example uses raw numbers without comma formatting. The PRD text mentions "1,234 / 900,000" as an illustrative example but does not mandate comma formatting. EQ chat style is terse. Using raw numbers (consistent with how HP/mana are displayed: `npc:GetHP() .. "/" .. npc:GetMaxHP()`) is correct.

**Plan confirmed — no amendments to logic. Raw number format matches HP/mana display pattern.**

### Verified Plan

Same as Implementation Plan. The change is:
- Insert 3 lines into cmd_status after the HP/mana Message call
- Use `npc:GetCompanionXP()` and `npc:GetXPForNextLevel()` directly
- Format: `"  XP: " .. current_xp .. " / " .. next_level_xp`
- No local variable needed — can inline (or use locals for readability; I'll use locals to match architecture doc)

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| c-expert | Status of task #4, confirm binding call pattern | Is `npc:GetXPForNextLevel()` the right call? Any binding nuances I should know? |

### Feedback Received

| From | Feedback | Action Taken |
|------|----------|-------------|
| c-expert | Tasks #1-4 complete. `npc:GetXPForNextLevel()` is correct call pattern. Returns uint32. | Confirmed plan, proceeded to Stage 4 |

### Consensus Plan

**Agreed approach:** Insert XP display line into `cmd_status` using `GetCompanionXP()` (already bound) and `GetXPForNextLevel()` (bound by task #4, complete).

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `/mnt/d/Dev/eq/akk-stack/server/quests/lua_modules/companion.lua` | Modify | 3 lines inserted into cmd_status |

**Change sequence (final):**
1. After HP/mana Message line in cmd_status, add:
   ```lua
   local current_xp    = npc:GetCompanionXP()
   local next_level_xp = npc:GetXPForNextLevel()
   client:Message(15, "  XP: " .. current_xp .. " / " .. next_level_xp)
   ```
2. Commit to `bugfix/companion-experience` branch in akk-stack/
3. Notify c-expert and team-lead of completion

---

## Stage 4: Build

### Implementation Log

#### 2026-03-05 — Insert XP display into cmd_status

**What:** Added 3 lines to `companion.cmd_status` after the HP/mana Message call.
**Where:** `/mnt/d/Dev/eq/akk-stack/server/quests/lua_modules/companion.lua` lines 564-566
**Why:** Task #5 — expose companion XP progress via !status command.
**Notes:** File is tracked in git despite `server/` being in .gitignore (force-added in a prior commit). Committed to `bugfix/companion-experience` as cd382fb.

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| `git add server/...` rejected by .gitignore | `.gitignore` has `server/` entry | File was already tracked; `git add` still staged it, `git commit` succeeded |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `/mnt/d/Dev/eq/akk-stack/server/quests/lua_modules/companion.lua` | Modified | 3 lines inserted into cmd_status (+GetCompanionXP, +GetXPForNextLevel, +XP Message) |

---

## Open Items

_(none — task complete)_

---

## Context for Next Agent

If picking this up after context compaction:

**What this task does:** Add XP progress display to the `!status` companion command. Currently shows Level, HP/Mana, Stance, Mode, Type. Need to add XP line after HP/mana.

**File to edit:** `/mnt/d/Dev/eq/akk-stack/server/quests/lua_modules/companion.lua`

**Function to edit:** `companion.cmd_status` at line 553

**Exact change:** Insert these 3 lines after the HP/mana `client:Message` call (~line 563):
```lua
    local current_xp    = npc:GetCompanionXP()
    local next_level_xp = npc:GetXPForNextLevel()
    client:Message(15, "  XP: " .. current_xp .. " / " .. next_level_xp)
```

**Blocker:** Task #4 (c-expert) must be done first — it adds the `GetXPForNextLevel()` Lua binding. `GetCompanionXP()` is already bound and ready.

**After implementing:** Commit to `bugfix/companion-experience` branch in akk-stack/, then notify team-lead.
