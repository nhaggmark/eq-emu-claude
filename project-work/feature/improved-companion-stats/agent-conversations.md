# Agent Conversations — improved-companion-stats

---

## Architecture Team Conversations

### Architect Self-Consultation Notes (No Team Agents Available)

**Date:** 2026-03-10

The architect was spawned as a solo agent without protocol-agent or config-expert
teammates in this session. The following documents the analysis that would
normally be delegated to those advisors, performed by the architect directly
from codebase investigation.

#### Protocol/Client Feasibility Assessment (protocol-agent scope)

**Question:** Does the Titanium client support clickable item links in chat messages?

**Finding:** YES. `eq.item_link(item_id)` is available in Lua (registered in
`lua_general.cpp:6058-6067`) and generates Titanium-compatible clickable links
via `quest_manager.varlink()`. In C++, `quest_manager.varlink(item_id)` provides
the same functionality. The Titanium client handles `OP_ItemLinkClick` natively
(documented in PROTOCOL-CODE.md). No new opcodes or packet structures required.

**Question:** Do item links in `client->Message()` work correctly in the
Titanium client?

**Finding:** YES. Item links embedded in chat messages are rendered as clickable
text in the Titanium client's message window. This is the standard mechanism
used by the existing item link system. No client-side constraints.

**Question:** Are there any packet-level edge cases for the stats display?

**Finding:** NO. The `!stats` and `!equipment` commands use only
`client->Message()` / `client:Message()` which sends standard
`OP_ChannelMessage` packets. No new packet types, no struct modifications.
The Titanium client's message window handles arbitrary text length within
the `ChannelMessage_Struct` constraints (variable-length message field).

---

## Implementation Team Conversations

### lua-expert → c-expert (2026-03-10)

**Context:** lua-expert is implementing Task 3 (cmd_stats handler, access control, COMMANDS update, help update) in `companion.lua`. The three new methods needed by cmd_stats — `GetMinDMG()`, `GetMaxDMG()`, and `GetCombatRole()` — are c-expert Task 1.

**Message sent to c-expert:**

> Task 3 (Lua) is complete and committed to `akk-stack`. The `cmd_stats` handler in `companion.lua` calls `npc:GetMinDMG()`, `npc:GetMaxDMG()`, and `npc:GetCombatRole()` directly. These need your Task 1 bindings to function at runtime.
>
> Please confirm when Task 1 is built and the server is restarted. After that, `#reloadquests` in-game will pick up the Lua changes and `!stats` can be validated.
>
> Binding signatures I coded to (per source-analysis.md):
> - `GetMinDMG()` → uint32
> - `GetMaxDMG()` → uint32
> - `GetCombatRole()` → uint8 (0-4)
>
> No other dependencies from my side.

**Status:** Message logged. Awaiting c-expert Task 1 completion + build.

---

#### Configuration Assessment (config-expert scope)

**Question:** Are there existing rules that could achieve this feature's goals
without code changes?

**Finding:** NO. This feature requires new command handlers and new Lua bindings.
There are no existing rules for companion stat display or equipment detail
formatting. The Companions rule category (`common/ruletypes.h`) contains rules
for recruitment, cooldowns, XP, HP regen, etc. — none related to information
display commands.

**Question:** Does this feature need new rules?

**Finding:** NO. This is purely a display feature. No tunable values are needed.
The stat values displayed are already computed by the engine. The command names
are fixed by design. No configurable thresholds or toggles are appropriate.

**Question:** Are there rule value boundary conditions to worry about?

**Finding:** NO. No rules are being added or modified. The displayed values come
directly from existing C++ methods (GetSTR, GetAC, etc.) which are already
bounds-checked by the engine.

