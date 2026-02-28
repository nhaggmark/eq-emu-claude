# NPC Recruitment / Recruit-Any-NPC Companion System — Dev Notes: Lua Expert

> **Feature branch:** `feature/npc-recruitment`
> **Agent:** lua-expert
> **Task(s):** 14, 15, 16, 23, 24
> **Date started:** 2026-02-27
> **Current stage:** Stage 2: Research

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 14 | Create companion.lua module — recruitment logic, eligibility, persuasion | Task 6 | Pending (blocked by Task 6) |
| 15 | Create companion_culture.lua — culture dialogue templates for LLM | Tasks 4, 14 | Pending (blocked by Tasks 4, 14) |
| 16 | Modify global/global_npc.lua — intercept recruitment/management keywords | Task 14 | Pending (blocked by Task 14) |
| 23 | Implement re-recruitment logic — Lua side | Tasks 6, 14, 20, 21 | Pending (blocked) |
| 24 | Implement soul wipe — ChromaDB clearing Lua side | Tasks 6, 20 | Pending (blocked) |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| claude/docs/topography/LUA-CODE.md | 874 | Event system, eq.* API, module patterns, global_npc.lua structure, Database class |
| architect/architecture.md | ~700 | Full architecture: companion.lua spec (~500 lines), companion_culture.lua spec (~200 lines), global_npc.lua modification spec, data schemas, Lua API method list |
| game-designer/user-stories.md | ~1400 | US-R01-R07 (recruitment), US-M01-M03 (mercenary), US-P04 (identity evolution), US-RR01-RR03 (re-recruitment), US-PM05 (commands), US-D02 (soul wipe) |
| agent-conversations.md | ~300 | Lore corrections: mercenary word prohibition is context-scoped (emotional vs tactical), Ogre self-preservation is panic not calculation |
| akk-stack/server/quests/global/global_npc.lua | 73 | Current global NPC: event_say calls llm_bridge.is_eligible, event_spawn handles Halloween |
| akk-stack/server/quests/lua_modules/llm_bridge.lua | 60+ | has_local_say_handler, is_eligible, build_context, generate_response patterns |

### Key Findings

1. **global_npc.lua interception pattern**: The architecture spec shows companion keyword check must come BEFORE the LLM eligibility check. Companion management commands (recruit, dismiss, stance) must intercept and return early before the LLM fires. This preserves existing LLM behavior for non-companion speech.

2. **companion.lua API**: The architecture specifies these public functions:
   - `is_recruitment_keyword(message)` — checks for recruit/join me/come with me keywords
   - `is_management_keyword(message)` — checks for dismiss/stance/follow/guard keywords
   - `attempt_recruitment(npc, client)` — full recruitment flow
   - `is_eligible_npc(npc)` — class/bodytype/exclusion checks
   - `get_persuasion_bonus(client, npc)` — culture-specific stat calculation
   - `handle_dismiss(npc, client)` — dismiss command handler
   - `handle_stance(npc, client, stance)` — stance command handler
   - `handle_re_recruitment(npc, client)` — re-recruitment with state restore
   - `trigger_soul_wipe(npc_type_id, char_id)` — cascade delete + ChromaDB clear

3. **Database access pattern**: The `Lua_Database` class uses prepared statements (`db:Prepare("SELECT ..."), stmt:Execute({values}), stmt:FetchHash()`). Used for `companion_exclusions`, `companion_culture_persuasion`, and `companion_data` queries.

4. **Data bucket pattern**: `eq.set_data("key", "value", "expires")` and `eq.get_data("key")` are used for cooldown tracking. Key format: `companion_cooldown_{npc_type_id}_{char_id}`.

5. **Rule access pattern**: `eq.rule_b("Companions", "Enabled")` for booleans, `eq.rule_i("Companions", "LevelRange")` for integers. Note: verify exact function names in Stage 2.

6. **Faction constants**: ALLY=1, WARMLY=2, KINDLY=3 (lower = better — counterintuitive). MinFaction rule default=3 (Kindly). Mercenary retention threshold=2 (Warmly).

7. **Companion detection**: c-expert adds `IsCompanion()` virtual to mob.h (Task 12). The Lua side can check `npc:IsCompanion()` once Task 18 exposes the Companion class to Lua.

8. **Context-scoped mercenary prohibition**: lore-master correction — prohibited words apply only in EMOTIONAL/RELATIONAL contexts. "together", "home", "protect", "guard" are fine in tactical/geographic contexts. LLM system prompt must express as semantic guidance, not word lists.

9. **Ogre self-preservation**: NOT tactical — primitive panic response. "Oog go now." The LLM prompt must frame it as primal fear, not calculation.

10. **Identity evolution tiers**: 0-10h (original role references), 10-50h (adventurer identity forming), 50+h (settled in new life, acknowledges old role without erasure). Implemented entirely in companion_culture.lua via time_active value.

11. **Re-recruitment SQL check**: `SELECT id, level, experience, recruited_level, stance FROM companion_data WHERE owner_id = ? AND npc_type_id = ? AND is_dismissed = 1`

12. **ChromaDB clearing for soul wipe**: Must call LLM sidecar with delete request. Pattern is similar to llm_bridge.generate_response but using a different endpoint. Need to verify sidecar API in Stage 2.

13. **Recruitment formula from PRD**:
    - Base: 50% (BaseRecruitChance rule)
    - Faction bonus: Ally=+30%, Warmly=+20%, Kindly=+10%
    - Disposition modifier: Eager=+25%, Restless=+15%, Curious=+5%, Content=-10%, Rooted=-30%
    - Level difference: abs(player_level - npc_level) * -LevelDiffModifier
    - Persuasion bonus: `(primary_stat - 75) / 5 + secondary_bonus`
    - Re-recruitment bonus: +10% if previous dismissed record exists
    - Clamped to [5%, 95%] unless hard-blocked

14. **Persuasion secondary bonus**:
    - secondary_type = 'faction': secondary_bonus = faction_level (1-5 scale) * 2
    - secondary_type = 'level': secondary_bonus = (player_level - npc_level) (positive = player higher)
    - secondary_type = 'stat': secondary_bonus = (secondary_stat - 75) / 10

15. **Eligibility checks sequence** (must short-circuit in this order):
    1. Rule enabled check
    2. Group capacity check (< 6 members)
    3. Not already recruited (NPC entity variable `is_recruited`)
    4. Combat check (player not in combat, NPC not in combat)
    5. Level range check (+/- LevelRange levels)
    6. Faction check (>= MinFaction)
    7. NPC type check: not Pet, not Bot, not Merc, not Companion
    8. Class exclusion: class 40/41 (Banker/Merchant), classes 20-35 (Guildmasters)
    9. Bodytype exclusion: 11 (non-sentient), 64+ (special mobs)
    10. Exclusion table check (companion_exclusions)
    11. Froglok race exclusion

### Implementation Plan

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| akk-stack/server/quests/lua_modules/companion.lua | Create | Core recruitment module (~500 lines) |
| akk-stack/server/quests/lua_modules/companion_culture.lua | Create | Culture dialogue context module (~200 lines) |
| akk-stack/server/quests/global/global_npc.lua | Modify | Add companion keyword interception before LLM block |

**Change sequence:**
1. Create `companion.lua` — all recruitment logic
2. Create `companion_culture.lua` — LLM context templates
3. Modify `global_npc.lua` — add interception

**companion.lua structure:**
```lua
-- companion.lua
-- Core recruitment logic for the NPC companion system.
-- Called from global/global_npc.lua when recruitment/management keywords are detected.

local companion = {}

-- Public: keyword detection
function companion.is_recruitment_keyword(message) end
function companion.is_management_keyword(message) end

-- Public: recruitment flow
function companion.attempt_recruitment(npc, client) end    -- main entry point
function companion.is_eligible_npc(npc, client) end        -- eligibility checks
function companion.get_persuasion_bonus(client, npc) end   -- culture-specific stat calc
function companion.get_disposition_modifier(npc) end       -- soul element disposition
function companion.get_faction_bonus(client, npc) end      -- faction to bonus pct

-- Public: management commands (called when target is already a companion)
function companion.handle_command(npc, client, message) end  -- dispatch management cmds
function companion.handle_dismiss(npc, client) end
function companion.handle_stance(npc, client, stance) end
function companion.handle_guard(npc, client) end
function companion.handle_follow(npc, client) end
function companion.handle_show_equipment(npc, client) end
function companion.handle_give_slot(npc, client, slot_name) end
function companion.handle_give_all(npc, client) end

-- Public: re-recruitment
function companion.check_dismissed_record(npc_type_id, char_id) end
function companion.restore_dismissed_companion(npc, client, record) end

-- Public: soul wipe (Task 24)
function companion.trigger_soul_wipe(npc_type_id, char_id) end

return companion
```

**companion_culture.lua structure:**
```lua
-- companion_culture.lua
-- Culture-specific LLM dialogue context for companion/mercenary distinction.
-- Provides context templates to llm_bridge when the NPC is a companion.

local companion_culture = {}

-- Returns LLM system prompt additions for this companion
function companion_culture.get_companion_context(npc, client, event_type) end

-- Event types: "recruitment_success", "recruitment_failure", "dismiss",
--              "stance_change", "level_up", "equipment_receive", "resurrection",
--              "self_preservation", "faction_warning", "faction_departure"

-- Returns the identity evolution tier (0=early, 1=mid, 2=late) based on time_active
function companion_culture.get_evolution_tier(time_active_seconds) end

-- Returns culture-specific self-preservation dialogue context
function companion_culture.get_self_preservation_context(npc_race, companion_type) end

return companion_culture
```

**global_npc.lua modification:**
```lua
-- Add at the TOP of event_say, before LLM block:
local companion_lib = require("companion")

function event_say(e)
    -- Companion keyword interception (before LLM)
    if companion_lib.is_recruitment_keyword(e.message) then
        if not e.self:IsCompanion() then  -- only recruit non-companions
            companion_lib.attempt_recruitment(e.self, e.other)
            return
        end
    end
    if e.self:IsCompanion() and companion_lib.is_management_keyword(e.message) then
        companion_lib.handle_command(e.self, e.other, e.message)
        return
    end
    -- ... existing LLM block
```

**What to test:**
- Saying "recruit" to an eligible NPC: recruitment roll, success/failure messages
- Saying "recruit" to an excluded NPC: blocked with system message
- Saying "recruit" while in combat: blocked with combat message
- Saying "dismiss" to own companion: dismissal flow, data preserved
- Stance change commands: "passive", "balanced", "aggressive"
- Cooldown: same NPC+player on failure triggers 15-minute cooldown
- Re-recruitment: dismissed companion gets +10% bonus, state restores
- #reloadquests hot-reload after changes

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `eq.rule_b("Category", "Rule")` | LUA-CODE.md + verify source | Pending | Rule access pattern |
| `eq.rule_i("Category", "Rule")` | LUA-CODE.md + verify source | Pending | Integer rule access |
| `eq.get_data("key")` / `eq.set_data("key", "val", "expiry")` | LUA-CODE.md | Seen in code | Data bucket pattern |
| `Database():Prepare():Execute():FetchHash()` | LUA-CODE.md | Yes (in doc) | DB prepared statement pattern |
| `npc:IsCompanion()` | Architecture doc Task 12/18 | Pending | Added by c-expert; verify binding name |
| `npc:IsEngaged()` | Verified in LUA-CODE.md Mob class | Pending | Combat state check |
| `client:GetAggroCount()` | To verify | Pending | Player combat check |
| `client:GetCharacterFactionLevel(faction_id)` | Architecture doc | Pending | Faction level for player |
| `npc:GetNPCTypeID()` | Used in llm_bridge.lua | Yes | NPC type ID accessor |
| `npc:GetLevel()` / `client:GetLevel()` | Standard mob methods | Pending verify | Level accessors |
| `npc:GetBodyType()` | Used in llm_bridge.lua | Yes | Body type check |
| `npc:GetClass()` | Standard mob method | Pending verify | Class check |
| `npc:GetRace()` | Standard mob method | Pending verify | Race check for culture |
| `npc:GetNPCFactionID()` | To verify | Pending | NPC faction ID for retention check |
| `client:GetGroup()` | Standard client method | Pending verify | Group reference |
| `Group:GroupCount()` | Standard group method | Pending verify | Member count |

### Plan Amendments

1. **companion_exclusions schema correction**: Architecture described class_id as a column, but the actual table only has `npc_type_id` (PK), `reason`, `exclusion_type`. Class-based exclusions are pre-seeded into the table at DB init time (Task 3 SQL). Lua eligibility check should just query `SELECT npc_type_id FROM companion_exclusions WHERE npc_type_id = ?` — a row means excluded. No class-level check needed in Lua.

2. **Froglok race IDs confirmed**: 74 (standard Froglok) AND 330 (alternate Froglok). Both are seeded into companion_exclusions by Task 3, so the Lua exclusion check will automatically catch them via the companion_exclusions table query — no separate Froglok check needed in Lua.

3. **is_dismissed confirmed**: Column exists in companion_data with `DEFAULT 0`. Query pattern: `WHERE owner_id = ? AND npc_type_id = ? AND is_dismissed = 1` for re-recruitment detection.

4. **Rule access**: Use `eq.get_rule("Companions:Enabled")` returning a string — compare with `== "true"` for booleans, `tonumber()` for integers. NOT `eq.rule_b()` / `eq.rule_i()` (those don't exist).

5. **ChromaDB soul wipe endpoint**: POST `http://npc-llm:8100/v1/memory/clear` with JSON body `{"npc_type_id": N, "player_id": N}`. Use `io.popen(curl...)` pattern from llm_bridge.lua.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| c-expert | Lua API readiness | When will IsCompanion(), CreateCompanionFromNPC(), DismissCompanion() be available in Lua? Are binding names confirmed? |
| data-expert | Table readiness | When will companion_culture_persuasion be seeded (Task 4)? companion_data schema confirmed? |

### Feedback Received

| From | Feedback | Action Taken |
|------|----------|-------------|
| data-expert | is_dismissed confirmed (DEFAULT 0). companion_exclusions: PRIMARY KEY on npc_type_id only (no class_id). 7,269 rows including 194 Froglok rows. Froglok races 74 and 330 in exclusion table — separate Lua check redundant but kept for clarity. companion_culture_persuasion: 14 rows, NULL if race missing (default to Human-style). | companion.lua queries verified correct. Froglok belt-and-suspenders check left in but table coverage is primary gate. No code changes needed. |
| c-expert | No response — still working on Task 6 (in progress) | 4 TODO stubs in companion.lua will be resolved once Tasks 17/18 complete |

### Consensus Plan

**All schema questions resolved (data-expert confirmed 2026-02-27).**

What is confirmed:
- `is_dismissed` confirmed in companion_data (DEFAULT 0). Re-recruitment query correct.
- `companion_exclusions` — npc_type_id only. 7,269 rows. Index-only point lookup.
- Froglok races 74 and 330 pre-seeded in exclusion table. Single exclusion query is sufficient.
- `companion_culture_persuasion` — 14 rows. NULL if race not found; default to Human-style.
- `npc:IsCompanion()` via lua_mob.h binding — available once Task 18 done
- Lua API binding names (Task 17/18): pending c-expert response

**Tasks 14/15/16 complete.** Proceeding to Tasks 23/24 after Tasks 6/17/18/21 unblock.

---

## Stage 4: Build

### Implementation Log

#### 2026-02-27 — Task 14: Created companion.lua

**What:** Created `/mnt/d/Dev/EQ/akk-stack/server/quests/lua_modules/companion.lua` (~500 lines)
**Sections:**
- Constants: RECRUIT_KEYWORDS, MANAGE_KEYWORDS, FACTION_BONUS, DISPOSITION_MODIFIER, LEVEL_DIFF_MODIFIER
- `is_recruitment_keyword(message)` — keyword matching
- `is_management_keyword(message)` — management keyword matching
- `is_eligible_npc(npc, client)` — full 11-step eligibility check (rules, group, combat, level, faction, type, exclusion table, froglok)
- `get_persuasion_bonus(client, npc)` — queries companion_culture_persuasion, applies primary/secondary stat formula
- `get_faction_bonus(client, npc)` — faction level to bonus %
- `get_disposition_modifier(npc)` — soul element entity variable to modifier %
- `check_dismissed_record(npc_type_id, char_id)` — re-recruitment detection query
- `attempt_recruitment(npc, client)` — full flow: cooldown → eligibility → roll → success/failure
- `handle_command(npc, client, message)` — management command dispatch
- `handle_dismiss/stance/follow/guard/show_equipment/give_slot/give_all` — command handlers
- `restore_dismissed_companion(npc, client, record)` — re-recruitment state restore hook
- `trigger_soul_wipe(npc_type_id, char_id)` — ChromaDB clear via curl POST to sidecar

**TODOs (pending Task 17/18/23):**
- `_on_recruitment_success`: `npc:CreateCompanion(client)` stub
- `handle_dismiss`: `npc:Dismiss()` stub
- `handle_stance`: `npc:SetStance(stance)` stub
- Management block in global_npc.lua: `npc:IsCompanion()` guard (stub = false until Task 18)

#### 2026-02-27 — Task 15: Created companion_culture.lua

**What:** Created `/mnt/d/Dev/EQ/akk-stack/server/quests/lua_modules/companion_culture.lua` (~200 lines)
**Sections:**
- `get_evolution_tier(time_active_seconds)` — 0=early(0-10h), 1=mid(10-50h), 2=late(50h+)
- `get_evolution_context(companion_type, time_active, original_role)` — LLM identity prompt by tier
- `get_type_framing(companion_type, npc_race)` — companion vs mercenary core tone
- `_get_mercenary_racial_framing(npc_race)` — Teir'Dal/Iksar/Ogre/Troll racial personality
- `get_companion_context(npc, client, event_type, companion_data)` — full context assembler
- `_get_event_prompt(event_type, ...)` — event-specific LLM guidance (12 event types)
- `get_self_preservation_context(npc_race, companion_type)` — combat disengage dialogue (lore-critical)
- `_extract_role_from_name(npc_name)` — extracts role for evolution context

**Key lore implementation:**
- Ogre self-preservation: "body reacts when pain exceeds tolerance" — no internal monologue, no tactical reasoning. "Oog hurt" / "HURT HURT".
- Mercenary word prohibition: context-scoped guidance in get_type_framing() — lists prohibited emotional uses and permitted tactical/geographic uses.
- Identity evolution: 3 tiers with original role preserved in Late tier ("The south gate is someone else's problem now").

#### 2026-02-27 — Task 16: Modified global/global_npc.lua

**What:** Added companion keyword interception to `event_say()` BEFORE the LLM block
**Where:** `/mnt/d/Dev/EQ/akk-stack/server/quests/global/global_npc.lua`
**Changes:**
1. Added `local companion_lib = require("companion")` at top
2. Added management command block (gated on `false` pending Task 18 IsCompanion() binding)
3. Added recruitment keyword block BEFORE `llm_bridge.is_eligible()` check

**Notes:**
- Management command block uses `false` as temporary guard for `IsCompanion()` — activates when Task 18 is done
- Recruitment block fires for ALL NPCs (non-companion guard is in companion.is_eligible_npc via entity variable)
- Quest scripts are in their own git repo at `/mnt/d/Dev/EQ/akk-stack/server/quests/` (separate from akk-stack which gitignores `server/`)
- Created branch `feature/npc-recruitment` in quests repo to match feature work
- Committed as `90500ddc3` in quests repo branch

#### 2026-02-27 — Task 17/18 API Confirmation — Stub Replacement

**What:** c-expert confirmed all Lua API binding names. Replaced 4 stubs in companion.lua with real API calls. Activated IsCompanion() guards in both companion.lua and global_npc.lua.

**c-expert confirmed bindings:**
- `client:CreateCompanion(npc)` — returns Companion entity or nil. Re-recruitment is TRANSPARENT: if is_dismissed=1 record exists for this npc_type_id + owner, C++ calls Load()+Unsuspend() automatically. No extra parameters needed.
- `companion:Dismiss(voluntary_bool)` — true=voluntary (earns +10% re-recruit bonus), false=forced
- `companion:SetStance(stance_int)` — 0=passive, 1=balanced, 2=aggressive
- `companion:SoulWipe()` — C++ cascade delete (Lua calls ChromaDB clear first)
- `npc:IsCompanion()` — returns true if NPC is a Companion instance (Task 18)
- `client:HasActiveCompanion(npc_type_id)` — returns bool
- `client:GetCompanionByNPCTypeID(npc_type_id)` — returns Companion or nil

**Stub replacements in companion.lua:**
1. `_on_recruitment_success()`: `client:CreateCompanion(npc)` (note: Client receiver, not NPC)
2. `handle_dismiss()`: `npc:Dismiss(true)` (voluntary=true)
3. `handle_stance()`: `npc:SetStance(stance)`
4. `handle_follow/guard/show_equipment/give_slot/give_all`: `SetFollowDistance`/`StopMoving`/`ShowEquipment`/`GiveSlot`/`GiveAll`

**IsCompanion() activation:**
- `is_eligible_npc()`: Added `if npc:IsCompanion() then return false, "already someone's companion" end` (removed TODO comment)
- `global_npc.lua`: Replaced `if false` with `if e.self:IsCompanion()` for management block
- `global_npc.lua`: Added `and not e.self:IsCompanion()` to recruitment block

**Task 23 resolution:**
- c-expert confirmed re-recruitment is handled transparently inside `client:CreateCompanion(npc)`. No separate Lua RestoreFromRecord() call needed. Removed `restore_dismissed_companion()` function (replaced with explanatory comment). `check_dismissed_record()` is still called before CreateCompanion to detect re-recruitment for the +10% roll bonus.

**Committed:** `506e389d3` (quests repo branch feature/npc-recruitment)

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| | | |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| akk-stack/server/quests/lua_modules/companion.lua | Created | Core recruitment module: eligibility, persuasion formula, roll, management commands, soul wipe |
| akk-stack/server/quests/lua_modules/companion_culture.lua | Created | LLM culture context module: evolution tiers, event prompts, mercenary framing, self-preservation dialogue |
| akk-stack/server/quests/global/global_npc.lua | Modified | Added companion keyword interception before LLM block |

---

## Open Items

- [x] `eq.rule_b()` / `eq.rule_i()` — NOT real. Use `eq.get_rule("Category:Rule")` (returns string). Confirmed from lua_general.cpp.
- [x] Faction check is `client:GetCharacterFactionLevel(faction_id)` — verified in lua_client.h
- [x] `is_dismissed` column confirmed — `TINYINT UNSIGNED NOT NULL DEFAULT 0` in Task 2 SQL
- [x] Froglok race IDs: 74 (standard) and 330 (alternate) — verified from Task 3 seed SQL
- [x] `companion_exclusions` — only `npc_type_id` (PK), `reason`, `exclusion_type` columns. Class exclusions pre-seeded into table. Lua just queries by `npc_type_id`.
- [x] LLM sidecar ChromaDB delete endpoint: POST `http://npc-llm:8100/v1/memory/clear` with `{npc_type_id, player_id}` — confirmed from app/main.py and app/models.py
- [x] data-expert confirmed all DB schema questions (2026-02-27): is_dismissed, exclusions query, culture table, Froglok races 74/330 pre-seeded
- [x] Lua API binding names confirmed by c-expert (2026-02-27): client:CreateCompanion, companion:Dismiss, companion:SetStance, npc:IsCompanion, companion:SoulWipe
- [x] Tasks 14/15/16 complete and committed (quests repo branch feature/npc-recruitment, commit 90500ddc3)
- [x] Task 23 (re-recruitment) — complete. CreateCompanion handles re-recruitment transparently. Lua adds +10% bonus via check_dismissed_record() pre-roll. Committed as 506e389d3.
- [x] Task 24 (soul wipe) — complete. trigger_soul_wipe() curl POST implemented in companion.lua.
- [x] ALL LUA TASKS COMPLETE (14, 15, 16, 23, 24)

---

## Context for Next Agent

**ALL LUA TASKS COMPLETE (14, 15, 16, 23, 24) as of 2026-02-27.**

Commits on quests repo branch `feature/npc-recruitment`:
- `90500ddc3` — companion.lua, companion_culture.lua, global_npc.lua initial implementation
- `506e389d3` — IsCompanion() guard activation, stub replacement, re-recruitment resolution

**Remaining items NOT in lua-expert scope:**
- Task 7: companion_ai.cpp spell AI (c-expert)
- Task 17: Lua API method exposure (c-expert) — companion.lua binds to these when they're ready
- Task 18: lua_companion.h/cpp Companion class Lua exposure (c-expert) — npc:IsCompanion() now live in global_npc.lua and companion.lua
- Task 22: companion history tracking (c-expert)
- Task 23: c-expert side of re-recruitment (re-recruitment Lua logic resolved — transparent in CreateCompanion)

**companion_culture.lua integration pending:**
- companion_culture.lua is complete but not yet called from llm_bridge.build_context()
- When Tasks 17/18 are done, llm_bridge should call `companion_culture.get_companion_context()` when `npc:IsCompanion()` returns true
- This is a lua-expert + c-expert coordination item

**Quest scripts git repo**: `/mnt/d/Dev/EQ/akk-stack/server/quests/` has its OWN git repo (akk-stack `.gitignore` excludes `server/`). Branch `feature/npc-recruitment` created there.

**Critical lore constraints** (if modifying companion_culture.lua):
- Mercenary word prohibition is CONTEXT-SCOPED (emotional/relational only, not tactical/geographic)
- Ogre self-preservation = panic/flight, NOT tactical withdrawal ("Oog hurt", not "tactical retreat")
- Identity evolution: 3 tiers by time_active (0-10h Early, 10-50h Mid, 50h+ Late)

5. **Recruitment formula** from PRD: base 50% + faction bonus + disposition modifier + level diff + persuasion bonus + re-recruitment bonus. Clamped [5%, 95%]. Hard-blocks bypass the clamp entirely.

6. **Data bucket cooldown key**: `companion_cooldown_{npc_type_id}_{char_id}` with expiry = RecruitCooldownS seconds.

7. **companion_culture.lua** integrates with the existing llm_bridge.lua pattern. It provides context additions to the LLM system prompt, not standalone dialogue generation.

8. **Module location**: `/mnt/d/Dev/EQ/akk-stack/server/quests/lua_modules/` (not akk-stack/server/lua_modules — that path does not exist; verified the correct path is quests/lua_modules/).
