# BUG-001: NO TRADE items still cannot be traded to NPC companions after Items:DisableNoDrop = true

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-04-20
> **Feature:** nodrop-companion-trade
> **Status:** Open

---

## Observed Behavior

- Rule `Items:DisableNoDrop` was set to `true` in `rule_values` (ruleset 1, the active set).
- Server was fully restarted: loginserver, world, and 8 dynamic zones relaunched. Zone log confirms "Loaded 1,048 rules in rule_set [default] id [1]".
- User logged back in and additionally ran `#reloadquest` (quest reload).
- Attempted to trade a NO TRADE flagged item to their NPC companion — the trade was still blocked.

## Expected Behavior

With `Items:DisableNoDrop = true`, no-drop items should be tradeable server-wide, including to NPC companions.

## Reproduction Steps

1. Verify `Items:DisableNoDrop = true` in ruleset 1 (already confirmed).
2. Verify the server was restarted after the rule change (already confirmed).
3. Open trade window with an NPC companion.
4. Attempt to place a NO TRADE item into the trade slot.
5. Trade is rejected / item is not accepted.

## Evidence

- Zone log line confirming rule load: "Loaded 1,048 rules in rule_set [default] id [1]"
- Rule confirmed active in `rule_values` table for ruleset 1.
- Full server restart performed (loginserver + world + 8 dynamic zones).
- `#reloadquest` run post-login.

## Affected Systems

_Check all that apply. These determine which expert agents are assigned
during triage._

- [ ] C++ server source -> c-expert
- [ ] Lua quest scripts -> lua-expert
- [ ] Perl quest scripts -> perl-expert
- [ ] Database / SQL -> data-expert
- [ ] Rules / Configuration -> config-expert
- [ ] Client protocol -> protocol-agent
- [ ] Infrastructure / Docker -> infra-expert

_Note: Architect to check off applicable systems during triage._

---

## Hypotheses (FOR ARCHITECT TRIAGE only)

Known candidates the architect should investigate:

- A secondary rule specific to NPC-to-NPC or player-to-NPC trade that is independent of `Items:DisableNoDrop`.
- A hardcoded nodrop check in the C++ companion trade path that bypasses the `DisableNoDrop` rule entirely.
- A Lua or Perl quest-script-level check in the companion trade handler that rejects no-drop items before the C++ rule is consulted.

_The architect owns triage. This section is a starting-point reference only._

---

## Context

- Solo/small-group server (1-3 players). The player wants to freely hand off gear to companions — the no-drop restriction is intentionally disabled server-wide.
- Companion Lua binding: `eqemu/zone/lua_companion.cpp`
- Related modules: `akk-stack/server/quests/lua_modules/llm_bridge.lua`, `client_ext.lua`, `akk-stack/server/quests/global/global_npc.lua`
