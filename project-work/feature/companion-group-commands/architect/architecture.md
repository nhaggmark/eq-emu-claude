# Companion Group Commands — Architecture & Implementation Plan

> **Feature branch:** `feature/companion-group-commands`
> **PRD:** `game-designer/prd.md`
> **Author:** architect
> **Date:** 2026-03-11
> **Status:** Approved

---

## Executive Summary

This feature adds 9 new group chat commands (!status, !buffme, !buffs, !tome, !flee, !assist, !help, !equipmentupgrade, !equipmentmissing) plus !follow via group chat to the NPC companion system. The implementation is **entirely in Lua** — all commands are new handler functions in `companion.lua`, dispatched through the existing `global_npc.lua` → `companion.dispatch_prefix_command()` pipeline. The group chat addressing system (`@name`/`@all` via `HandleGroupChatMentions` in `client.cpp`) already routes `!`-prefixed payloads to companion EVENT_SAY handlers. No C++ changes, database changes, protocol changes, or new rule values are needed.

## Existing System Analysis

### Current State

**Command dispatch pipeline:**
1. Player types `/gsay @name !command` in group chat
2. `client.cpp:HandleGroupChatMentions()` (line 1680) parses `@tokens`, resolves companion targets, extracts the `!command` payload
3. For `!`-prefixed payloads, dispatches directly via `parse->EventBotMercNPC(EVENT_SAY, companion, client, payload)` — no stagger delay (stagger is only for conversation/LLM responses)
4. `global_npc.lua:event_say()` intercepts: if `e.self:IsCompanion()` and message starts with `!`, calls `companion_lib.dispatch_prefix_command(e.self, e.other, e.message)`
5. `companion.lua:dispatch_prefix_command()` strips the `!` prefix, looks up the command in the `COMMANDS` table, runs ownership check, and calls the handler function

**Existing commands already in the COMMANDS table:**
- Stance: `!passive`, `!balanced`, `!aggressive`
- Movement: `!follow`, `!guard`, `!recall`
- Equipment: `!equipment`/`!gear`, `!equip`, `!unequip`, `!unequipall`
- Information: `!stats`, `!status`, `!help`
- Combat: `!target`, `!assist`
- Control: `!dismiss`

**Key observation:** `!status`, `!help`, `!assist`, and `!follow` already have entries in the COMMANDS table and handler functions. However, the current implementations are minimal:
- `cmd_status` shows Level, Class, HP, Mana, XP, Stance, Mode, Type — but NOT buffs, target, sit/stand, following state, or the rich format the PRD requires
- `cmd_help` shows a basic command list — needs updating with the new commands
- `cmd_assist` sets target and adds to hate list but does NOT auto-switch from passive to balanced
- `cmd_follow` calls `SetGuardMode(false)` — works but needs group chat feedback path

**Companion AI buff system (companion_ai.cpp):**
- `AI_BuffGroupMember()` iterates group members, checks `SpellType_Buff | SpellType_PreCombatBuff` spells, checks if targets already have the buff (`CanBuffStack`), and casts via `AIDoSpellCast()`
- This runs during `AI_IdleCastCheck()` for each class-specific AI method
- The 30% mana conservation threshold is **hardcoded** in `AI_BuffGroupMember()` (line 558: `if GetManaRatio() < 30.0f`)

**Companion equipment system:**
- Equipment stored in `m_equipment[EQ::invslot::EQUIPMENT_COUNT]` array (companion.h line 457)
- `GetEquipment(slot)` returns item_id for a slot (0 = empty)
- `ShowEquipment(client)` lists all equipped items
- `GiveSlot(client, slot_name)` returns an item from a slot
- Inventory profile initialized with `MobVersion::Bot` for item bonus calculation
- `COMPANION_SLOT_NAMES` table in `global_npc.lua` (line 128) maps slot IDs 0-22 to names

**Lua API availability (verified on Lua_Mob, Lua_Companion, Lua_Buff, Lua_Item):**
- HP/Mana: `GetHP()`, `GetMaxHP()`, `GetMana()`, `GetMaxMana()`, `GetManaRatio()`
- Target: `GetTarget()`, `SetTarget()`, `GetCleanName()`
- Combat: `AddToHateList()`, `WipeHateList()`, `IsAttackAllowed()`
- Movement: `RunTo(x,y,z)`, `CalculateDistance(mob)`, `CalculateDistance(x,y,z)`
- Stance: `GetStance()`, `SetStance(int)` (on Lua_Companion)
- Follow: `SetGuardMode(bool)`, `SetFollowID(id)`, `SetFollowDistance(d)`
- Buffs: `GetBuffs(L)` returns table of Lua_Buff objects, `BuffCount()`, `GetMaxBuffSlots()`
- Buff details: `Lua_Buff:GetSpellID()`, `Lua_Buff:GetTicsRemaining()`
- Spell name: `eq.get_spell_name(spell_id)`
- Sitting: `IsSitting()` (on Lua_Companion, overridden)
- Equipment: `GetEquipment(slot)` returns item_id
- Item data: via `Lua_ItemInst:GetItem()` → Lua_Item with `GetAC()`, `GetAStr()`, etc.
- Item links: `eq.item_link(inst)` generates link text
- Distance: `CalculateDistance(mob)` returns float

### Gap Analysis

| PRD Requirement | Current State | Gap |
|----------------|---------------|-----|
| !status with buffs, target, sit/stand | cmd_status shows Level/HP/Mana/XP/Stance/Mode | Need to add buff listing, target, sit/stand, following state, % display |
| !buffme (queue buff on player only) | No buff queue mechanism | Need flag/entity variable to signal AI to prioritize player buffing |
| !buffs (queue buff on all party) | AI_BuffGroupMember() exists but runs on its own schedule | Need flag/entity variable to signal AI to run buff pass on next idle tick |
| !tome (move to player) | !recall exists but uses GMMove (teleport) with 200-unit min distance and cooldown | Need a new command that uses RunTo() (pathing) with 50-unit proximity check, no cooldown |
| !flee (passive + move + follow) | Each component exists separately | Need a macro command that chains them |
| !assist with auto-stance-switch | cmd_assist exists but doesn't switch from passive | Need to add passive→balanced auto-switch |
| !help with all commands | cmd_help exists but needs new commands added | Update help text |
| !equipmentupgrade | No item evaluation exists | New feature: parse item link, compare stats |
| !equipmentmissing | No empty-slot listing exists | New feature: iterate slots, report empty |
| !follow via group chat | cmd_follow exists, works via group chat already | Enhance feedback message |

## Technical Approach

### Architecture Decision

**All changes are in Lua.** This feature adds zero C++ code, zero database changes, zero new rules.

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| `companion.lua` | Modify | Add/update 9 command handlers. All game logic is already accessible via the Lua API. |
| `global_npc.lua` | No change | Existing dispatch pipeline handles everything. |
| C++ companion classes | No change | All needed methods already exposed to Lua via lua_companion.cpp / lua_mob.cpp |
| Database tables | No change | No new data storage needed; buff queue uses entity variables (in-memory) |
| Rule values | No change | Thresholds (10% mana OOM, 50-unit proximity) are game design constants, not tunables |

**Why pure Lua is correct:**
1. The command dispatch pipeline (`global_npc.lua` → `companion.lua:dispatch_prefix_command()`) already handles all `!` commands
2. Every piece of data the commands need is accessible via existing Lua API methods on Lua_Mob, Lua_Companion, Lua_Buff, Lua_Item
3. The buff queue mechanism only needs an entity variable flag that the existing C++ AI checks on its next idle tick — but even simpler, we can implement a Lua timer-based approach
4. Adding C++ would require a rebuild cycle for what is purely quest-script-level logic

### Data Model

No database changes. Buff queue state uses NPC entity variables (in-memory, transient):
- `"buff_request_target"` — `"owner"` for !buffme, `"party"` for !buffs, empty string for no request
- Entity variables are automatically cleared on companion depop/zone, which is correct behavior

### Code Changes

#### Lua/Script Changes

**File:** `akk-stack/server/quests/lua_modules/companion.lua`

**1. COMMANDS table updates (line ~91):**
Add new entries:
```lua
buffme           = { handler = "cmd_buffme",           category = "buffs" },
buffs            = { handler = "cmd_buffs",            category = "buffs" },
tome             = { handler = "cmd_tome",             category = "movement" },
flee             = { handler = "cmd_flee",             category = "movement" },
equipmentupgrade = { handler = "cmd_equipmentupgrade", category = "equipment", requires_owner = false },
equipmentmissing = { handler = "cmd_equipmentmissing", category = "equipment", requires_owner = false },
```

Note: `!status`, `!help`, `!assist`, `!follow` already have entries — their handlers will be updated in place.

**2. New/updated command handlers:**

**cmd_status (UPDATE existing, line ~578):**
- Add HP percentage display
- Show "Mana: N/A" for pure melee (check `GetMaxMana() == 0`)
- Add target name (`GetTarget()` → `GetCleanName()` or "None")
- Add sit/stand state via `IsSitting()`
- Add follow/guard mode from `companion_modes` table
- Add buff listing: iterate `npc:GetBuffs(L)`, for each buff with `GetSpellID() > 0`, show `eq.get_spell_name(spell_id)` and convert `GetTicsRemaining() * 6 / 60` to minutes
- Dead check: if `GetHP() <= 0`, show DEAD indicator and omit target/stance

**cmd_buffme (NEW):**
- Dead check: respond "is dead and cannot cast spells"
- Check if companion has buff spells: query `GetMaxMana() > 0` as proxy for caster check (pure melee have 0 max mana)
- Check mana threshold: if `GetManaRatio() < 10`, respond "too low on mana"
- Set entity variable: `npc:SetEntityVariable("buff_request_target", "owner")`
- Respond: "[Name] will refresh your buffs when able."

**cmd_buffs (NEW):**
- Same checks as cmd_buffme
- Set entity variable: `npc:SetEntityVariable("buff_request_target", "party")`
- Respond: "[Name] will refresh party buffs when able."

**cmd_tome (NEW):**
- Dead check: respond "is dead and cannot move"
- Proximity check: if `npc:CalculateDistance(client) < 50`, respond "is already nearby"
- Move to player: `npc:RunTo(client:GetX(), client:GetY(), client:GetZ())`
- Respond: "[Name] moves toward you."

**cmd_flee (NEW):**
- Dead check: respond "is dead and cannot flee"
- Check if already passive and not in combat: use lighter message
- Set passive: `npc:SetStance(0)`
- Wipe hate is NOT done (PRD requirement: hate retained)
- Move to player: `npc:RunTo(client:GetX(), client:GetY(), client:GetZ())`
- Set follow mode: `npc:SetGuardMode(false)` + update `companion_modes`
- If was in combat: respond "[Name] disengages and retreats to you!"
- If was not in combat: respond "[Name] moves to follow you."

**cmd_assist (UPDATE existing, line ~742):**
- Add dead check: respond "is dead and cannot fight"
- Add no-target check with improved message: "has no target to assist with. Target a mob first."
- Add friendly target check: `client:GetTarget():IsClient()` or checking `IsAttackAllowed()`
- Add self-target check: if target == npc, respond "will not attack themselves"
- Add corpse check: if target is a corpse type
- **Auto-stance-switch**: if `npc:GetStance() == 0` (passive), call `npc:SetStance(1)` before engaging, and include "switches to balanced stance and" in feedback
- Set target and add to hate list as currently done
- Respond with appropriate message including target name

**cmd_equipmentupgrade (NEW):**
- Dead check: no response (silent)
- Parse item link from message: extract item_id from the `\x12`-delimited link in the args string
- If no link found: respond "Please link an item for me to evaluate."
- Look up item data via database or content_db
- Check class/race equippability (reuse the NPC_RACE_TO_PLAYER_RACE mapping from global_npc.lua)
- If cannot equip: silent (no response per PRD)
- Determine target slot from item's Slots() bitmask
- If slot empty: respond "The [Item] is an upgrade! My [Slot] slot is empty."
- If slot occupied: compute stat scores for both items:
  - Armor: AC + AStr + ASta + AAgi + ADex + AWis + AInt + ACha + HP + Mana
  - Weapon: (Damage * 10 / Delay) + stat sum
- Compare and respond with upgrade/downgrade message and stat scores
- Link currently equipped item in response

**cmd_equipmentmissing (NEW):**
- Iterate all 22 equipment slots (skip slot 21 PowerSource)
- For each slot where `npc:GetEquipment(slot) == 0`, add slot name to empty list
- If no empty slots: respond "has all equipment slots filled."
- Otherwise: respond "[Name] has nothing equipped in: [slot list]"

**cmd_help (UPDATE existing, line ~634):**
- Add new command categories and entries:
  - Buffs: !buffme, !buffs
  - Movement: add !tome, !flee to existing
  - Combat: enhance !assist description
  - Equipment: add !equipmentupgrade, !equipmentmissing
- Update format to match PRD reference card
- For `@all`: only first companion responds (add a guard using entity variable or return early after first)

**cmd_follow (UPDATE existing, line ~495):**
- No functional change needed — already works via group chat
- Optionally enhance feedback message

**3. Buff queue processing (integration with AI):**

The buff request entity variable (`buff_request_target`) needs to be checked during the companion's AI idle cycle. Two approaches:

**Approach A (chosen — simpler):** Use a Lua timer in `global_npc.lua`. When a buff request entity variable is set, start a short timer (2 seconds). On timer fire, check if companion is idle (not casting, not in combat), then directly call the buff casting logic via existing Lua API methods. This avoids any C++ changes.

**Implementation:** In `companion.lua`, after setting the entity variable, also start a timer:
```lua
eq.set_timer("buff_request_" .. npc:GetID(), 2000)
```
In `global_npc.lua:event_timer()`, add a handler for `buff_request_*` timers that:
1. Checks if the companion is idle (not casting: `npc:IsCasting()` is false, not engaged: `npc:IsEngaged()` is false)
2. If idle, iterates buff spells and casts on the appropriate targets
3. If not idle, restarts the timer for another 2-second check
4. Clears the entity variable after completion
5. Stops retrying after a reasonable timeout (e.g., 60 seconds / 30 attempts)

**Approach B (rejected — requires C++ change):** Add a check in `Companion::AI_IdleCastCheck()` that reads the entity variable and forces a buff pass. This would be more elegant but requires a C++ rebuild, which is unnecessary for this feature.

**4. Item link parsing helper function:**

Add a utility function to `companion.lua` to extract an item ID from an EQ item link in the message text. The Titanium client sends item links with `\x12` delimiters in a well-defined format.

**Titanium link body format (confirmed by protocol-agent):**
`\x12` + 45-char body + item name text + `\x12`

Body layout: `[1X][5X item_id][5X aug1][5X aug2][5X aug3][5X aug4][5X aug5][1X evolving][4X lore_group][1X evolve_level][8X hash]`

Item ID is at bytes 1-5 after the opening `\x12` (5 hex chars, max item_id = 0xFFFFF = 1,048,575).

**Lua parsing approach (chosen — preserves zero-C++ scope):**
1. Find `\x12` delimiters in the string using `string.find(msg, "\18")`
2. Extract bytes 2-6 from the link body (the 5-char hex item ID)
3. Convert with `tonumber(hex_str, 16)` to get the numeric item_id
4. Return the item_id or nil if no valid link found

**Note:** A C++ binding approach exists (using `EQ::saylink::DegenerateLinkBody` as in `summonitem.cpp:15-20`) and would be more robust. However, for the Titanium client (frozen, no format changes), the Lua hex parsing at fixed byte positions is stable and avoids a C++ rebuild. The C++ approach is documented as a future improvement option if item link format issues arise.

**5. @all !help deduplication:**

For `!help`, the PRD says only one companion should respond when sent to `@all`. Since HandleGroupChatMentions dispatches to each companion sequentially via EVENT_SAY, we can use an entity variable as a lock:
- First companion to receive `!help` sets a shared variable (e.g., data bucket with 1-second TTL)
- Subsequent companions in the same @all batch check and skip

#### C++ Changes

None required. All needed methods are already exposed to Lua.

#### Database Changes

None required.

#### Configuration Changes

None required. The PRD thresholds (10% mana OOM, 50-unit proximity) are intentional game design values, not server-configurable tunables. The 30% buff conservation threshold in C++ AI is separate — it controls when AI *voluntarily* buffs. The 10% threshold controls when the *player-requested* buff command reports OOM.

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | Implement !status (enhanced), !help (updated), !equipmentmissing, !follow (enhanced feedback) | lua-expert | — | ~150 lines: read-only information commands with no side effects |
| 2 | Implement !tome, !flee, !assist (enhanced with auto-stance), !follow confirmation | lua-expert | — | ~120 lines: movement and combat action commands |
| 3 | Implement !buffme, !buffs with timer-based buff queue | lua-expert | — | ~150 lines: buff request queue + timer handler in global_npc.lua |
| 4 | Implement !equipmentupgrade with item link parsing and stat comparison | lua-expert | — | ~180 lines: item link parser, stat scoring, slot resolution, equippability check |
| 5 | Update COMMANDS table and cmd_help reference card | lua-expert | 1, 2, 3, 4 | ~30 lines: register all new handlers and update help text with complete list |

**Note:** Tasks 1-4 are independent of each other (they add separate handlers to companion.lua). Task 5 depends on all of them because it needs to know the final command list for the help text. A single lua-expert can work through them sequentially.

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Item link parsing fails for edge-case link formats | Medium | Low | Lua pattern matching handles standard EQ links; test with various item types. Fallback: "Please link an item" message if parsing fails. |
| Buff timer retries pile up if companion never becomes idle | Low | Low | Hard cap at 30 retries (60 seconds). Entity variable cleared on timeout with "unable to buff right now" message. |
| @all !status floods chat with 5 companions reporting | Low | Low | By design (PRD explicitly says "reports are delivered sequentially"). Each report is ~8 lines. Client handles rapid Message() calls fine. |
| GetBuffs() returns stale data for recently-cast buffs | Low | Low | Buff data is updated immediately in C++ when buff is applied. Lua reads current state. |
| IsSitting() may not work correctly on companions | Low | Medium | Verified: Companion class overrides IsSitting() (companion.h line 443). |

### Compatibility Risks

The existing commands (`!status`, `!help`, `!assist`, `!follow`) are being enhanced, not replaced. All existing behavior is preserved:
- `!status` still shows Level/Class/HP/Mana/XP/Stance/Mode — the new fields are additions
- `!assist` still targets and engages — the auto-stance-switch is additive
- `!help` still shows all existing commands — new commands are appended
- `!follow` still calls SetGuardMode(false) — feedback message may change slightly

All existing `/say` command paths continue to work. The group chat path uses the same dispatch_prefix_command() entry point.

### Performance Risks

None. All operations are O(1) or O(n) where n is small (6 group members, 42 buff slots, 22 equipment slots). No database queries. No network calls. No blocking operations.

## Review Passes

### Pass 1: Feasibility

**Can we build this?** Yes, entirely in Lua.

Every data point the commands need is accessible through existing Lua API:
- HP/Mana/Stance/Target: Lua_Mob methods
- Buffs: `GetBuffs()` → Lua_Buff table with `GetSpellID()` and `GetTicsRemaining()`
- Equipment: `GetEquipment(slot)` on Lua_Companion
- Item data: accessible via item link parsing + database lookup or in-memory item data
- Movement: `RunTo()` for pathed movement
- Stance: `SetStance()` on Lua_Companion
- Follow mode: `SetGuardMode()` on Lua_Companion

**Hardest part:** `!equipmentupgrade` item link parsing. Protocol-agent confirmed the exact Titanium link body format: item ID is 5 hex chars at bytes 1-5 after the `\x12` delimiter. The Lua parser needs to find delimiters, extract these bytes, and convert with `tonumber(hex, 16)`. The format is frozen (Titanium client never changes), so fixed-position parsing is stable.

**Protocol-agent consultation:** Confirmed no Titanium client constraints. Key findings:
- All command responses must use `CompanionGroupSay()` (group chat), not `client:Message()` (private system message), per PRD requirements
- Item links survive the group chat round trip intact — `TitaniumToServerSayLink()` converts the 45-char Titanium link body to 56-char internal format before reaching Lua's `e.message`
- Item ID is at bytes 1-5 (5 hex chars) after the `\x12` delimiter in the link body — parseable in Lua without C++ bindings
- No packet flooding concerns for @all dispatches — Titanium queues and renders all packets in order
- `!` prefix commands are dispatched simultaneously (no stagger) by `HandleGroupChatMentions` — stagger only applies to LLM conversation responses
- `\n` does NOT render as a newline in Titanium group chat — each line must be a separate `CompanionGroupSay()` call (existing codebase already follows this pattern)

**Config-expert consultation:** Confirmed no existing rules cover the specific thresholds in this feature. The 30% AI buff conservation threshold in companion_ai.cpp is hardcoded, not a rule. The PRD's 10% OOM threshold for !buffme/!buffs is a separate concern (player-visible feedback vs. AI decision-making). No new rules needed — these are game design constants.

### Pass 2: Simplicity

**Is this the simplest approach?** Yes.

- Pure Lua, no C++ rebuild needed
- Reuses existing command dispatch pipeline (COMMANDS table + dispatch_prefix_command)
- No new database tables or columns
- No new rule values
- Buff queue uses entity variables (in-memory, transient) instead of database persistence
- Timer-based buff processing avoids modifying C++ AI code

**Can anything be removed or deferred?**
- All 9 commands are PRD requirements; none can be removed
- The buff timer mechanism could be simplified to a single-shot approach (try once on next idle tick, report failure if busy) but the retry approach is more user-friendly
- The `!equipmentupgrade` multi-slot logic (rings, wrists) adds complexity but is a PRD requirement

### Pass 3: Antagonistic

**What could go wrong?**

1. **Item link parsing edge cases:** Items with special characters in names, augmented items, or items from different client versions could produce unexpected link formats. **Mitigation:** Fail gracefully with "Please link an item" message. Test with augmented items, no-drop items, and stackable items.

2. **Buff timer race condition:** What if the player issues `!buffme` and then immediately issues `!buffs`? The second command overwrites the entity variable, which is correct (PRD says "new request replaces the previous one"). The timer is already running from the first request and will process the updated variable.

3. **!flee during root/mez:** Companion goes passive (stops attacking) but RunTo() fails because the companion is rooted. The companion is now passive and stuck. **Mitigation:** This is acceptable per the PRD ("the movement system handles this"). When root breaks, the companion will continue to follow.

4. **!assist on a mob that dies before the companion reaches it:** The companion will path to the mob's last position, find no target, and resume idle behavior. This is normal EQ behavior and requires no special handling.

5. **@all !help spam:** If all 5 companions respond with identical help text, that's 100+ lines of chat. **Mitigation:** PRD explicitly requires only one companion to respond. Implemented via data bucket lock with 1-second TTL.

6. **!equipmentupgrade stat formula gaming:** Players could abuse the simple stat sum to equip sub-optimal gear. **Mitigation:** By design — the PRD acknowledges the formula is intentionally simplistic and the player has final say.

7. **Chat message truncation for !status with many buffs:** A companion with 42 active buffs would produce ~45 lines of !status output. **Mitigation:** The Titanium client has no practical limit on client:Message() calls. Each is a separate packet. The concern is readability, not technical failure.

8. **!flee does not clear npc hate:** Mobs continue chasing. Player uses !flee thinking it's safe, companions die while running. **Mitigation:** By design (PRD explicitly states this). The feedback message says "disengages and retreats" which correctly implies the mob will pursue.

### Pass 4: Integration

**How do the pieces fit together?**

The implementation has clean dependency ordering:
1. Tasks 1-4 are independent — they each add new handler functions to companion.lua
2. Task 5 (COMMANDS table + help text update) depends on all of 1-4

**Implementation sequence within companion.lua:**
1. Add new handler functions at the end of the file (before `return companion`)
2. Add new entries to the COMMANDS table
3. Update cmd_help with the complete reference card

**Integration with global_npc.lua:**
- Only the buff timer handler needs to be added to `event_timer()` in global_npc.lua
- The timer naming convention (`buff_request_<entity_id>`) matches the existing pattern (`comp_commentary_<entity_id>`)

**Validation dependencies:**
- All commands can be tested independently
- !buffme/!buffs require a caster companion in the group
- !equipmentupgrade requires an item to link (can use any item link)
- !flee requires engagement with a mob to verify hate retention

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| lua-expert | Tasks 1-5 | All changes are in Lua quest scripts (companion.lua, global_npc.lua). Single agent can work through all tasks sequentially. |

## Validation Plan

### !status
- [ ] `/gsay @companionname !status` shows HP (current/max/%), Mana (current/max/% or N/A), Stance, Target, State (Standing/Sitting), Following (Yes/No), and active buff list with time remaining
- [ ] Buff durations shown in minutes (rounded down), "<1 min" for buffs under 60 seconds
- [ ] Pure melee companions show "Mana: N/A"
- [ ] Dead companions show DEAD indicator
- [ ] `@all !status` produces reports from all companions
- [ ] Command never interrupts companion activity

### !buffme
- [ ] `/gsay @companionname !buffme` queues a buff refresh targeting the player
- [ ] Companion buffs the player during next idle window (within ~30 seconds)
- [ ] Non-caster companions respond "has no buff spells available"
- [ ] OOM companions (below 10% mana) respond "too low on mana to buff right now"
- [ ] Dead companions respond "is dead and cannot cast spells"
- [ ] Multiple !buffme commands replace (not stack) the pending request
- [ ] !buffme does not interrupt active combat or casting

### !buffs
- [ ] `/gsay @companionname !buffs` queues a buff refresh for all party members
- [ ] Same queuing and idle-window behavior as !buffme
- [ ] Companion buffs all group members, not just the player
- [ ] Same edge case handling as !buffme (non-caster, OOM, dead)

### !tome
- [ ] `/gsay @companionname !tome` causes companion to path to player's location
- [ ] Companion uses RunTo (pathed movement), not teleport
- [ ] Companion already near player (within 50 units) responds "is already nearby"
- [ ] Dead companions respond "is dead and cannot move"
- [ ] After arriving, companion resumes previous movement mode
- [ ] No cooldown (unlike !recall)

### !flee
- [ ] `/gsay @companionname !flee` sets passive + moves to player + sets follow mode
- [ ] Companion's hate list is NOT cleared (mobs continue to chase)
- [ ] Companion stops attacking immediately
- [ ] `@all !flee` causes all companions to disengage and retreat
- [ ] Dead companions respond "is dead and cannot flee"
- [ ] Already-passive companions still move to player with lighter feedback message

### !assist
- [ ] `/gsay @companionname !assist` causes companion to attack player's target
- [ ] If companion was passive, auto-switches to balanced stance first
- [ ] No target: responds "has no target to assist with. Target a mob first."
- [ ] Friendly target: responds "will not attack a friendly target"
- [ ] Self-target: responds "will not attack themselves"
- [ ] Dead companions respond "is dead and cannot fight"
- [ ] `@all !assist` causes all companions to attack player's target

### !equipmentupgrade
- [ ] `/gsay @companionname !equipmentupgrade [Item Link]` evaluates the linked item
- [ ] Items companion cannot equip (class/race): no response (silent)
- [ ] Empty target slot: always responds YES with "slot is empty" message
- [ ] Occupied slot: compares stat sums and reports upgrade/downgrade with scores
- [ ] Stat formula: AC + STR + STA + AGI + DEX + WIS + INT + CHA + HP + Mana for armor
- [ ] Weapon formula: (Damage * 10 / Delay) + stat sum
- [ ] Companion links their currently equipped item in the response
- [ ] Missing item link: responds "Please link an item for me to evaluate."

### !equipmentmissing
- [ ] `/gsay @companionname !equipmentmissing` lists all empty equipment slots
- [ ] All 19+ slots checked and empty ones reported
- [ ] Fully equipped companion responds "has all equipment slots filled"
- [ ] `@all !equipmentmissing` produces reports from all companions
- [ ] Dead companions still report (death doesn't change equipment)

### !help
- [ ] `/gsay @companionname !help` displays complete command reference card
- [ ] Reference includes ALL commands (existing + new) organized by category
- [ ] When sent to `@all`, only one companion responds
- [ ] Categories: Recruitment, Stances, Movement, Combat, Buffs, Equipment, Information, Addressing

### !follow
- [ ] `/gsay @companionname !follow` sets companion to follow mode
- [ ] Works correctly when companion was in guard mode
- [ ] `@all !follow` sets all companions to follow
- [ ] Dead companions respond "is dead and cannot follow"

### General
- [ ] All commands work through both `/gsay @name` addressing AND existing `/say` targeting
- [ ] All commands work in EQ macro hotbuttons
- [ ] No command changes the player's target
- [ ] Error/feedback messages include the companion's name
- [ ] Dead companion checks produce appropriate messages
- [ ] No server crashes or unhandled exceptions

---

> **Next step:** Spawn the **implementation team** — only **lua-expert** as a teammate. They will work through Tasks 1-5 sequentially. Only one expert needed since all changes are Lua scripts.
