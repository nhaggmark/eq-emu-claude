# Companion Commands Reference

> **Last updated:** 2026-03-13
> **System:** Recruit-Any-NPC Companion System

---

## Overview

Companion commands use a `!` prefix and are spoken via `/say` when targeting
a companion. Most commands require you to own the companion (owner-only). A
few informational commands can be used by any player on any companion
(read-only).

**Group dispatch:** Type `@CompanionName !command` in group chat (`/gsay`) to
send a command to a specific companion by name. Use `@all !command` to
dispatch to all companions in your group simultaneously.

**!help without a target:** Type `/say !help` at any time, even without
targeting a companion. The command list appears in your chat window.

---

## Recruitment Keywords

Recruitment commands are spoken as free-text `/say` to a non-companion NPC.

| Phrase | Effect |
|--------|--------|
| `recruit` | Attempt to recruit the targeted NPC as a companion |
| `join me` | " |
| `come with me` | " |
| `travel with me` | " |
| `adventure with me` | " |
| `will you join` | " |
| `join my party` | " |
| `join my group` | " |
| `come along` | " |
| `follow me` | " |

**Handler:** `companion.lua:attempt_recruitment()` called from
`global_npc.lua:event_say()`

---

## Companion Commands (! Prefix)

All commands below require targeting your active companion and typing
`/say !command`. Owner-only commands are marked; all others are available
to any player targeting any companion.

---

### Stance Commands (owner-only)

| Command | Behavior |
|---------|----------|
| `!passive` | Set stance to Passive (0). Wipes hate list. Companion disengages from combat and stops attacking. |
| `!balanced` | Set stance to Balanced (1). Default combat mode — fights when attacked or owner is attacked. |
| `!aggressive` | Set stance to Aggressive (2). Actively seeks and attacks enemies in range. |

**Handler:** `companion.lua:cmd_passive()`, `cmd_balanced()`, `cmd_aggressive()`

---

### Movement Commands (owner-only)

| Command | Behavior |
|---------|----------|
| `!follow` | Resume following owner. Clears guard mode. |
| `!guard` | Hold current position. Stop following. Companion still fights if engaged. |
| `!hold` | Hold current position AND stop fighting (guard mode + passive stance + wipes hate list). Breaking out: `!follow` resumes movement; `!assist` resumes combat and movement; `!balanced`/`!aggressive` re-enables combat at current position. |
| `!recall` | Teleport companion to owner's location. Requires >200 unit distance. 30-second cooldown. Resets to follow mode. |
| `!tome` | Move companion to owner's location instantly (GMMove). No cooldown. Skips if within 50 units. Wipes hate list (stops active combat). Breaks guard mode, resets to follow. Stance unchanged. |
| `!flee` | Set companion passive, move to owner (GMMove), set follow mode. Hate list intentionally retained — mobs that were fighting the companion continue pursuit. |

**Handler:** `companion.lua:cmd_follow()`, `cmd_guard()`, `cmd_hold()`,
`cmd_recall()`, `cmd_tome()`, `cmd_flee()`

---

### Combat Commands (owner-only)

| Command | Behavior |
|---------|----------|
| `!target` | Set companion's target to player's current target. In balanced/aggressive stance: engages target (adds to hate list). In passive stance: companion faces target but does not attack. |
| `!assist` | Attack player's target. Auto-switches passive to balanced before engaging. Validates target is hostile. Breaks guard mode so companion can move to engage. |

**Handler:** `companion.lua:cmd_target()`, `cmd_assist()`

---

### Buff Commands (owner-only)

| Command | Behavior |
|---------|----------|
| `!buffme` | Queue buff refresh targeting the owner only. Companion casts on next idle window. Casters only; requires >10% mana. Replaces any pending buff request. |
| `!buffs` | Queue buff refresh targeting all party members. Casters only; requires >10% mana. Replaces any pending buff request. |

**Handler:** `companion.lua:cmd_buffme()`, `cmd_buffs()`

---

### Equipment Commands

| Command | Owner-Only | Behavior |
|---------|------------|----------|
| `!equipment` | No | Display all equipped items with slot names. |
| `!gear` | No | Alias for `!equipment`. |
| `!equip` | Yes | Display instructions to use the trade window for giving items to the companion. |
| `!unequip <slot>` | Yes | Return the item from the named slot to the player. |
| `!unequip all` | Yes | Return all equipped items to the player. |
| `!unequipall` | Yes | Alias for `!unequip all`. |
| `!equipmentupgrade [link]` | No | Evaluate a linked item vs. the companion's currently equipped item in that slot. Uses stat score comparison. |
| `!equipmentmissing` | No | List all empty equipment slots. |

**Valid slot names:** charm, ear1, head, face, ear2, neck, shoulder, arms,
back, wrist1, wrist2, range, hands, primary, secondary, finger1, finger2,
chest, legs, feet, waist, ammo

**Handler:** `companion.lua:cmd_equipment()`, `cmd_equip()`, `cmd_unequip()`,
`cmd_unequipall()`, `cmd_equipmentupgrade()`, `cmd_equipmentmissing()`

---

### Information Commands (read-only — any player, any companion)

| Command | Behavior |
|---------|----------|
| `!help` | Display the full command list. Works without targeting a companion (player-level intercept in `global_player.lua`). |
| `!help <topic>` | Display detailed help for a category. Topics: `stance`, `movement`, `combat`, `buffs`, `equipment`, `information`, `control`. |
| `!stats` | Display detailed combat stats (attributes, AC, damage, resists, combat role). |
| `!status` | Display overview: HP, mana, XP, stance, mode, target, active buffs. |

**Handler:** `companion.lua:cmd_help()` (NPC-level, when companion targeted),
`cmd_help_standalone()` (player-level, via `global_player.lua:event_say()`),
`cmd_stats()`, `cmd_status()`

---

### Control Commands (owner-only)

| Command | Behavior |
|---------|----------|
| `!dismiss` | Dismiss companion voluntarily. Companion record is preserved (suspended state). Re-recruitable with +10% roll bonus. |

**Handler:** `companion.lua:cmd_dismiss()` → `Companion::Dismiss(true)`

---

## Command Dispatch

**NPC-level dispatch** (requires targeting a companion):
- `global_npc.lua:event_say()` checks `e.self:IsCompanion()` and message
  starts with `!`
- Calls `companion.dispatch_prefix_command(npc, client, message)`
- Routes to handler via `COMMANDS` table in `companion.lua`

**Player-level dispatch** (no target required, `!help` only):
- `global_player.lua:event_say()` intercepts `!help` before NPC dispatch
- Fires at `client.cpp:1609` regardless of target state
- Calls `companion.cmd_help_standalone(client, args)`

**@all group dispatch:**
- Type `@all !command` in group chat (`/gsay`)
- C++ (`Client::HandleGroupChatMentions`) parses @tokens, resolves companion
  names, dispatches payload as `EVENT_SAY` to each matched companion
- `!` commands dispatch immediately (no stagger delay)
- `@all !help` deduplication: data bucket lock (`help_lock_<zone_id>` with
  1-second TTL) ensures only one response per dispatch

---

## Implementation Files

| File | Role |
|------|------|
| `akk-stack/server/quests/lua_modules/companion.lua` | All command handlers, recruitment logic, dispatch table |
| `akk-stack/server/quests/global/global_npc.lua` | NPC event hook — intercepts `!` commands when companion targeted |
| `akk-stack/server/quests/global/global_player.lua` | Player event hook — intercepts `!help` without target |
| `akk-stack/server/quests/lua_modules/companion_commentary.lua` | LLM-integrated personality dialogue |
| `akk-stack/server/quests/lua_modules/companion_culture.lua` | Culture dialogue templates |
| `eqemu/zone/companion.cpp` | Core companion C++ class |
| `eqemu/zone/companion.h` | Companion class definition |
| `eqemu/zone/companion_ai.cpp` | Class-specific spell AI (16 classes) |
| `eqemu/zone/lua_companion.cpp` | Lua API bindings for Companion-specific methods |

---

## Constants

| Constant | Value | Meaning |
|----------|-------|---------|
| COMPANION_STANCE_PASSIVE | 0 | No combat, disengages |
| COMPANION_STANCE_BALANCED | 1 | Default combat mode |
| COMPANION_STANCE_AGGRESSIVE | 2 | Aggressive combat |
| COMPANION_TYPE_COMPANION | 0 | Loyal companion |
| COMPANION_TYPE_MERCENARY | 1 | Faction-dependent hire |

---

## Nil-Guard Pattern

Many Companion-specific methods (`SetStance`, `GetStance`, `SetGuardMode`,
`GetCompanionType`, `GetCompanionID`, `GetCombatRole`) are nil-guarded
throughout `companion.lua` because luabind doesn't resolve inherited methods
at runtime (known `Lua_Companion`/`Lua_NPC` inheritance issue). All code
using these methods follows the pattern:

```lua
if npc.SetStance then npc:SetStance(0) end
local stance = npc.GetStance and npc:GetStance() or 1  -- default 1 (balanced)
```
