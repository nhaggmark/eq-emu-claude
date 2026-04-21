# nodrop-companion-trade — Product Requirements Document

> **Feature branch:** `bugfix/nodrop-companion-trade`
> **Author:** game-designer
> **Date:** 2026-04-20
> **Status:** Draft
> **Type:** Bug-fix PRD (lean scope)

---

## Problem Statement

A player cannot give a NO TRADE item to their NPC companion, even though the
server rule `Items:DisableNoDrop = true` has been enabled. On this solo /
small-group server, the companion system is the signature feature — players
recruit NPCs and want to outfit them with any gear they own, including
no-drop items that were bound to the player's character. The rule was turned
on precisely to remove the no-drop restriction server-wide, but the trade
path between a player and their own companion still rejects the item. The
result is that companions cannot be equipped with a meaningful portion of
the player's gear, which directly undermines the recruit-any-NPC fantasy
the server is built around.

## Goals

1. With `Items:DisableNoDrop = true` set on the active ruleset, a player
   can place any NO TRADE item into a trade window with their own NPC
   companion, and the trade completes successfully.
2. Items transferred this way land in the companion's inventory and can be
   equipped by the companion if they meet the normal slot, class, and level
   requirements.
3. Behavior is consistent with the already-established intent of the
   `Items:DisableNoDrop` rule on this server: NO TRADE is effectively
   disabled, and items move freely between the player and their companion.

## Non-Goals

- Not reworking the trade UI or any client-side trade behavior.
- Not adding new server rules. The existing `Items:DisableNoDrop` rule is
  the control; this fix brings companion trades under its umbrella.
- Not changing how companions accept, store, or equip items beyond honoring
  the trade itself.
- Not broadening the trade window for arbitrary hostile or neutral NPCs
  (merchants, quest mobs, wild NPCs). Scope is player-to-companion trades
  only. If the architect determines the relevant code path cannot be cleanly
  scoped to companions, the architect may propose a broader fix and flag
  the tradeoff in architecture.md for the user's decision.
- Not changing LORE item behavior. LORE restrictions are independent of
  NO TRADE and remain in force.
- Not changing behavior for `attuneable` items. Items with `attuneable=1`
  are explicitly out of scope for this fix.

## User Experience

### Player Flow

1. Player has `Items:DisableNoDrop = true` on the active ruleset and the
   server has been restarted since the rule was set.
2. Player has a NO TRADE item in their inventory (a weapon, armor piece,
   bag, or stackable).
3. Player targets their recruited NPC companion and opens a trade window
   (via the normal companion trade interaction).
4. Player places the NO TRADE item into a trade slot. The item is accepted
   into the trade window without being rejected or reverted to the player's
   inventory.
5. Player completes the trade. The item leaves the player's inventory and
   lands in the companion's inventory.
6. If the item is wearable and matches the companion's slot / class /
   level requirements, the companion equips it through its normal
   equip-best-item logic. Otherwise the item sits in the companion's
   inventory, available for later equip or future trade-back.

### Example Scenario

A level 40 warrior has spent hours acquiring a NO TRADE bracer as a quest
reward. They recruit a wandering warrior NPC as a companion and want to
hand the bracer to the companion so it can tank more effectively. They
open a trade window with the companion, drag the bracer into the trade
slot, and hit Trade. The bracer transfers to the companion, the companion
equips it, and the companion's AC increases accordingly. The player's
original intent — "my companion is an extension of my character, so my
gear should work for them" — is respected.

## Game Design Details

### Mechanics

- The server rule `Items:DisableNoDrop` already exists and is intended to
  disable NO TRADE restrictions server-wide. When this rule is `true`, no
  NO TRADE check anywhere in the player's normal gear flow should reject
  an item on the basis of its NO TRADE flag alone.
- This fix brings the player-to-companion trade path into compliance with
  that rule. When `Items:DisableNoDrop = true`, the companion trade window
  must accept NO TRADE items and transfer them on trade completion,
  identical to how an ordinary (non-NO TRADE) item is handled today.
- When `Items:DisableNoDrop = false` (the default), behavior must be
  unchanged from today: NO TRADE items are rejected from the companion
  trade window as they are now. This fix is gated on the rule, not a
  blanket removal of the check.
- LORE remains independent and is enforced separately. If a companion
  already has a LORE item of the same type, a trade of that same LORE
  item is still rejected for the LORE reason (not the NO TRADE reason).
- Items with `attuneable=1` are out of scope. If the same code path
  happens to cover attuneable behavior, the architect should preserve
  current attuneable behavior and call that out explicitly.

### Balance Considerations

- On a 1-3 player server, no-drop restrictions exist mainly to stop gear
  from leaking across characters on multi-player economies. That economy
  does not exist here. Handing a no-drop item to a companion does not
  create tradeable value; the companion can only hand the item back to
  the recruiting player.
- There is no balance risk from letting players equip their companions
  with no-drop items. If anything, it closes a gap where companions were
  strictly weaker than equivalent gear would predict, simply because the
  player couldn't transfer their best items.
- The fix does not change item drop rates, faction-restricted loot, or
  class/level restrictions on wearing an item. A companion that can't
  wear an item for class reasons still can't wear it.

### Era Compliance

- No new content, no new NPCs, no references to post-Luclin mechanics or
  zones. This is a pure behavior fix on an existing server rule that
  already exists in the Classic-Luclin era codebase.

## Affected Systems

_Architect to confirm/refine during triage._

- [ ] C++ server source (`eqemu/`) — likely, given the companion trade
      path and the NO TRADE check are typically enforced server-side.
- [ ] Lua quest scripts (`akk-stack/server/quests/`) — possible, if the
      companion trade handler has a Lua-side check.
- [ ] Perl quest scripts — possible but unlikely (Lua preferred on this
      server).
- [ ] Database tables (`peq`) — no schema changes expected.
- [ ] Rule values — rule already exists; no new rule needed.
- [ ] Server configuration — no config change expected.
- [ ] Infrastructure / Docker — no infra change expected.

## Dependencies

- Depends on the existing `Items:DisableNoDrop` rule being available and
  functional in the active ruleset (already confirmed in the bug report).
- Depends on the companion recruitment and trade-window system already in
  place on this server.

## Open Questions

1. **Where is the NO TRADE check applied in the companion trade path?**
   The architect should determine whether this is:
   - A hardcoded C++ check in the companion trade code that bypasses the
     `Items:DisableNoDrop` rule entirely,
   - A secondary rule independent of `Items:DisableNoDrop` that must also
     be flipped (or unified),
   - A Lua or Perl script-level check in the companion trade handler that
     runs before the C++ rule is consulted,
   - Some combination of the above.
   Document the finding in architecture.md.

2. **Can the fix be scoped cleanly to companions only, or does the
   relevant code path also serve merchants, stock NPC trades, and quest
   NPCs?** If it can be scoped to companions, do so. If not, the architect
   should document the tradeoff in architecture.md and flag it for the
   user before widening scope.

3. **Does the same code path also affect attuneable items?** If yes, the
   architect should preserve current attuneable behavior and call that
   out; attuneable is explicitly out of scope for this fix.

## Acceptance Criteria

_All criteria below are gated on `Items:DisableNoDrop = true` being set on
the active ruleset and the server having been restarted after the rule
was set. With the rule set to `false` (default), behavior must be
unchanged from today._

- [ ] Given `Items:DisableNoDrop = true` is set and the server has been
      restarted, when a player opens a trade window with their recruited
      NPC companion and places a NO TRADE flagged item into a trade slot,
      the item is accepted in the trade window (not rejected, not
      reverted to the player's inventory).
- [ ] Given the same preconditions, when the player completes the trade,
      the NO TRADE item transfers out of the player's inventory and into
      the companion's inventory.
- [ ] If the transferred NO TRADE item matches the companion's slot,
      class, and level requirements, the companion equips it through
      normal equip logic (same behavior as a non-NO TRADE item).
- [ ] NO TRADE stackable items (e.g. no-drop consumables) trade in
      stacks correctly — full stack and partial stack both work.
- [ ] NO TRADE bags trade correctly, including any items inside the bag
      (existing bag-trade behavior must not regress).
- [ ] LORE items remain blocked when the companion already has a LORE
      item of the same type — LORE enforcement is unchanged by this fix.
- [ ] Items with `attuneable=1` are unchanged by this fix (attuneable
      behavior is preserved).
- [ ] With `Items:DisableNoDrop = false` (default), NO TRADE items are
      still rejected from the companion trade window — i.e. the fix is
      gated on the rule.
- [ ] Merchant and general NPC (non-companion) NO TRADE behavior is
      unchanged — players cannot sell NO TRADE items to merchants and
      cannot trade them to arbitrary non-companion NPCs. _(Architect may
      revise this criterion if the relevant code path cannot be cleanly
      scoped to companions; in that case, the user decides whether the
      broader fix is acceptable.)_

### Game-Tester Scenarios

These scenarios the game-tester will run to validate the fix end-to-end:

1. **Weapon trade:** Trade a NO TRADE weapon to a companion. Verify the
   weapon appears in the companion's inventory and the companion equips
   it (if class/level permit). Verify the companion's stats update to
   reflect the equipped weapon.
2. **Armor trade:** Trade a NO TRADE armor piece to a companion. Verify
   inventory transfer and equip behavior.
3. **Bag trade:** Trade a NO TRADE bag (with contents) to a companion.
   Verify the bag and its contents transfer intact.
4. **Stackable trade — full stack:** Trade a full stack of NO TRADE
   consumables to a companion. Verify the full stack arrives.
5. **Stackable trade — partial stack:** Trade a partial split of a NO
   TRADE stack. Verify the split behaves correctly.
6. **LORE negative case:** Attempt to trade a NO TRADE + LORE item to a
   companion that already has a LORE item of the same type. Verify the
   LORE restriction still blocks the trade, independent of the NO TRADE
   fix.
7. **Rule-off regression:** Temporarily set `Items:DisableNoDrop = false`,
   restart, and verify NO TRADE items are still rejected from the
   companion trade window (i.e. the rule still gates the behavior).
8. **Merchant regression:** Verify selling a NO TRADE item to a
   merchant behaves as it does today (architect defines expected
   behavior; tester verifies no change from pre-fix baseline).
9. **Trade-back:** Trade a NO TRADE item to a companion, then trade the
   same item back from the companion to the player. Verify the return
   trade also completes (consistency check — no asymmetry where the
   player can give but not take back).

---

## Appendix: Technical Notes for Architect

_Advisory only. The architect owns all implementation decisions._

- The bug report already flagged three candidate locations for the NO
  TRADE check (hardcoded C++, a secondary rule, a script-level check in
  companion trade handlers). These are a starting point for triage, not a
  prescription.
- Relevant files called out in the bug report context (for orientation
  only — architect to decide what is actually in the code path):
  - `eqemu/zone/lua_companion.cpp` — companion Lua binding surface.
  - `akk-stack/server/quests/lua_modules/llm_bridge.lua`,
    `client_ext.lua`, and `akk-stack/server/quests/global/global_npc.lua`
    — existing companion-related Lua modules.
- Topography references the architect may find useful: the existing
  `Items:DisableNoDrop` rule is already live, so the architect can grep
  for its usage to find every enforcement site and confirm the companion
  trade path is missing from that list (or has its own check that
  shortcircuits).
- Preference: keep the fix scoped to companions if cleanly possible. If
  scoping is messy, surface the tradeoff to the user via architecture.md
  before widening scope.

---

> **Next step:** Pass this PRD to the **architect** for technical feasibility
> assessment and implementation planning.
