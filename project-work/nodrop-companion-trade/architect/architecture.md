# nodrop-companion-trade — Architecture & Implementation Plan

> **Feature branch:** `bugfix/nodrop-companion-trade`
> **PRD:** `game-designer/prd.md`
> **Author:** architect
> **Date:** 2026-04-20
> **Status:** Draft

---

## Executive Summary

BUG-001 is a **rule-application-timing bug**, not a missing enforcement-site bug. `Items:DisableNoDrop` is not a runtime rule; it is a **shared-memory-snapshot-time rule** that gets baked into `items.bin` by the `shared_memory` binary. Every runtime NO-TRADE check — whether in the trading path, the inventory path, or the Titanium client UI — reads the cached `item->NoDrop` byte from the memory-mapped `items.bin`. The rule is never re-read at runtime. If the rule is flipped in `rule_values` but `shared_memory` is not re-run with the new value **and** the zone processes are not restarted to mmap the fresh file, every NO-TRADE item still reports `NoDrop=0` everywhere — including in the item packets sent to the Titanium client, which enforces its own UI-side NO-TRADE block on that byte.

Two solutions are on the table:

1. **Operational fix (zero code):** Re-run `./bin/shared_memory` AFTER the rule is set, and only THEN start loginserver/world/zones, and have the player log in fresh. This is the intended deploy path and is documented in `MEMORY.md`.
2. **Code fix (if the operational path is judged insufficient or unreliable on this solo server):** Teach the runtime to consult `RuleB(Items, DisableNoDrop)` at the check time — specifically in `EQ::ItemInstance::IsDroppable()` at `common/item_instance.cpp:900` — so the rule takes effect on a rule flip + `#reloadworld` without the shared_memory rebuild. This widens scope to ALL trade paths (player↔player, player↔merchant, player↔NPC, bot, companion) — which aligns with the PRD's "on this solo server the rule is intentionally universal" guidance.

Recommendation: start with the operational fix (Path 1) as the validation step. If the player can confirm a re-run of `shared_memory` followed by a full zone restart resolves the block, no code change is needed. If it does not resolve it, fall back to Path 2 (a one-line runtime rule check in `IsDroppable()`). The architecture plan below assumes we will test Path 1 first in the Validation phase, with Path 2 pre-scoped and ready to pull the trigger on.

## Existing System Analysis

### Current State

#### The NO-TRADE / `DisableNoDrop` snapshot pipeline

1. **Rule definition** — `common/ruletypes.h:1151`:
   ```cpp
   RULE_BOOL(Items, DisableNoDrop, false, "Enable this to disable No Drop Items")
   ```
   Stored in `rule_values`. Loaded by `RuleManager::LoadRules("default", ...)` at startup.

2. **Rule application (snapshot time)** — `common/shareddb.cpp:932` and `:993`:
   ```cpp
   bool disable_no_drop = RuleB(Items, DisableNoDrop);
   // ...
   for (const auto& e : l) {
       // ...
       item.NoDrop = disable_no_drop ? std::numeric_limits<uint8>::max() : e.nodrop;
       // ...
   }
   ```
   This code path is **only executed by the `shared_memory` binary** (`shared_memory/items.cpp:27–48` → `SharedDatabase::LoadItems(void*, uint32, int32, uint32)`). The resulting `EQ::ItemData` array is written into a memory-mapped file at `server/shared/items`.

3. **Rule application — NOT** — in zone processes. Zone processes call a different overload, `SharedDatabase::LoadItems(const std::string& prefix)` at `common/shareddb.cpp:902`, which only memory-maps the existing file. No rule is ever re-consulted.

4. **Runtime enforcement sites (all consume `item->NoDrop` directly):**

   | File:Line | Context | Check |
   |-----------|---------|-------|
   | `common/item_instance.cpp:900–932` | `EQ::ItemInstance::IsDroppable()` | `if (m_item->NoDrop == 0) return false;` — the canonical predicate |
   | `common/inventory_profile.cpp:438–443` | `CheckNoDrop()` | Delegates to `IsDroppable()` |
   | `zone/trading.cpp:342` | Player↔Player trade: FinishTrade container branch | `inst->GetItem()->NoDrop != 0 || CanTradeFVNoDropItem() || other == this` |
   | `zone/trading.cpp:480` | Player↔Player trade: FinishTrade item branch | same pattern |
   | `zone/trading.cpp:766` | `CheckTradeNonDroppable()` (hacking trip-wire at `Handle_OP_TradeAcceptClick`) | `!inst->IsDroppable() → return true` (cancels trade) |
   | `zone/trading.cpp:845, 1024, 2372` | Bazaar/trader paths | various direct reads |
   | `zone/client_packet.cpp:7850` | Guild bank deposit | direct read |
   | `zone/client_packet.cpp:14383` | Merchant recovery/recover slot | direct read |
   | `zone/inventory.cpp:685` | `Client::DropItem()` — drop-on-ground hack check | `CheckNoDrop(...) && !CanTradeFVNoDropItem()` |
   | `zone/inventory.cpp:1882, 3704` | inventory ops | direct read |
   | `zone/bot.cpp:4389` | Bot trade hack check | `!trade_instance->IsDroppable()` |
   | `zone/npc.cpp:1719, 1822, 4195` | Pickpocket, weapon equip, pet give-item | direct reads |
   | `zone/parcels.cpp:414` | Parcel/mail | `IsDroppable()` |
   | `zone/attack.cpp:2521` | Multiquest item handling | direct read |
   | `common/patches/titanium.cpp:3366` | Titanium item serializer | `ob << '|' << itoa(item->NoDrop);` — **ships the cached byte to the client** |
   | `zone/client_packet.cpp:9321` | Item view packet build | `outapp->WriteUInt8(item->NoDrop);` — same |

   **None of these sites consult the rule directly.** They all consume the cached byte.

5. **Firiona Vie exemption (separate, parallel lever):** `common/ruletypes.h:337` defines `RULE_INT(World, FVNoDropFlag, 0, …)`. When set to `1` (Enabled) or `2` (AdminOnly with `Character:MinStatusForNoDropExemptions`), `Client::CanTradeFVNoDropItem()` at `zone/client_packet.cpp:16706–16724` returns `true`, which:
   - Allows `IsDroppable()` at `common/item_instance.cpp:911` to return `true` for items whose `FVNoDrop==0` even when `NoDrop==0`.
   - Sends `enable_FV=1` to the client at login time (`world/client.cpp:161`), telling the Titanium UI to allow FV-flagged trades.

   **This is a runtime rule**, but it keys on the `FVNoDrop` byte (a separate field, the FV flag on individual items), not on the general `NoDrop` byte. It is not a solution to this bug unless we wanted to route trades through FV-flagged items, which we don't — the player's items aren't FV-flagged.

6. **`Pets:CanTakeNoDrop`** (`common/ruletypes.h:298`) — only affects Pet::CanPetTakeItem (`npc.cpp:4195`), not player→companion trades. Companions are NPCs, not pets in the `IsPetOwnerOfClientBot()` sense. Not relevant to this bug.

7. **`RULE_CATEGORY(Companions)`** (`common/ruletypes.h:1181–1200+`) — 20+ companion-specific rules, **none** of them NO-TRADE-related.

#### The Titanium client-side NO-TRADE enforcement

The Titanium client (Oct 2006) enforces NO TRADE in its own UI based on the `NoDrop` byte serialized to it by the server. Because the server sends `item->NoDrop` directly from the memory-mapped `items.bin`, the UI behavior is controlled entirely by whether the item's cached `NoDrop` byte is `0` (nodrop) or `255` (not-nodrop). If the server has not rebuilt `items.bin` with `DisableNoDrop=true`, every NO-TRADE item ships to the client as `NoDrop=0` and the client refuses to place it in the trade window.

There is no packet-level server-side override that can convince the Titanium UI to accept a drag-in of an item it already knows is `NoDrop=0`. The only lever is the serialized byte, and the only way to flip that byte is a fresh shared-memory snapshot with the rule in effect.

#### The companion trade path

Companion trades use the ordinary NPC trade flow. When a player accepts a trade with a companion:

1. `Client::Handle_OP_TradeAcceptClick` (`zone/client_packet.cpp:15379`) runs.
2. It calls `CheckTradeNonDroppable()` (`zone/trading.cpp:759`) as the **hacking trip-wire** — if any item in the trade slots is non-droppable (i.e. NO TRADE and not FV-exempt), the server cancels the trade and tags the player with the "Hacking activity detected in trade transaction" message.
3. If that trip-wire passes, the trade proceeds to `FinishTrade(NPC)` (`zone/trading.cpp:510–705`), which handles the companion-specific logic:
   - `parse->HasQuestSub(... EVENT_TRADE)` → true
   - Calls `parse->EventNPCGlobal(EVENT_TRADE, ...)` for companions (per BUG-031 fix — line 646) to avoid dual-handler item duplication
   - `tradingWith->IsCompanion()` path short-circuits the handin-return system (line 657) because the Lua handler (`global_npc.lua:event_trade`, lines 164+) handles all item consumption / equip / return.

**Key finding:** the companion trade is NOT the bottleneck. The block is upstream of the server ever seeing it — either at the Titanium client UI or at `CheckTradeNonDroppable()` depending on whether the client lets the drag-in happen at all.

### Gap Analysis

There is no gap in the companion trade code. The gap is the rule-timing model: `Items:DisableNoDrop` requires a shared-memory snapshot rebuild. That is a documented deploy-time requirement, not an in-zone behavior.

Two possible gaps remain:

1. **Operational gap (most likely):** The user flipped the rule but the `shared_memory` binary was not re-run between the rule flip and the zone startup, OR shared_memory was run before the rule flip. The on-disk `items.bin` (`akk-stack/server/shared/items`, timestamp Apr 20 20:41) is from today but does not independently prove the rebuild happened after the rule was set.
2. **Mapping staleness edge case:** If `shared_memory` was re-run **after** the zone processes were already started, the processes still have the OLD file mmap'd. Replacing the on-disk file does not update existing mappings. Zones must be stopped before a fresh shared_memory run, and restarted afterward.

## Technical Approach

### Architecture Decision

Least-invasive-first analysis:

| Priority | Layer | Applies here? |
|----------|-------|----------------|
| 1 | Rule value | Rule already exists. Already set to `true`. No new rule needed. |
| 2 | Server config | No `eqemu_config.json` relevance. |
| 3 | Operational procedure | **Primary path.** Re-sequence the full-stack restart so shared_memory rebuilds `items.bin` WITH the rule active, then start zones, then relog client. |
| 4 | Lua scripts | Not applicable — the block is C++ / client-side, not Lua. |
| 5 | SQL | Not applicable — no schema change. |
| 6 | C++ source | **Fallback path.** Make `IsDroppable()` consult `RuleB(Items, DisableNoDrop)` at runtime, so the rule takes effect on a rule reload without a shared_memory rebuild. |

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| Operational procedure | Procedural / documentation | The rule is snapshot-time by current design; following the documented deploy path is the zero-risk fix. |
| `common/item_instance.cpp::IsDroppable()` | C++ (1-line conditional) | Fallback if Path 1 fails. Makes the rule runtime-reactive by wrapping the `m_item->NoDrop == 0` check in an `if (!RuleB(Items, DisableNoDrop))` guard. |

### Data Model

No database schema changes. `rule_values` already contains `Items:DisableNoDrop` in ruleset 1.

### Code Changes

#### C++ Changes

**Path 1 (operational):** No code changes.

**Path 2 (fallback, if Path 1 fails):**

Single file, single function: `common/item_instance.cpp`, `EQ::ItemInstance::IsDroppable()` at lines 900–932.

Current code at line 915:
```cpp
if (m_item->NoDrop == 0) {
    return false;
}
```

Proposed change:
```cpp
if (m_item->NoDrop == 0 && !RuleB(Items, DisableNoDrop)) {
    return false;
}
```

This makes `IsDroppable()` consult the rule at runtime. On a `#reloadrulesworld` after a rule flip, every trade / drop / bazaar / bot / companion path that gates on `IsDroppable()` or `CheckTradeNonDroppable()` picks up the new rule immediately. The Titanium client still enforces UI-side NO-TRADE on the `NoDrop=0` byte it received, but once the player reconnects or the server re-serializes items with `NoDrop=255`, the client UI block is lifted too.

**Important caveat:** Path 2 alone does NOT address the Titanium UI-side block. The client still refuses drag-in if the item it has is cached as `NoDrop=0`. To also lift the UI block without a shared_memory rebuild, we would additionally need to patch the serializer to send `NoDrop=255` when the rule is true — at `common/patches/titanium.cpp:3366` and `zone/client_packet.cpp:9321`. That is a wider patch and arguably shades into reimplementing what the shared_memory binary already does. **Given that analysis, Path 2 is not actually complete on its own; it would need the serialization patch as well.** This is why Path 1 (operational) remains the preferred fix.

If Path 2 is taken, the full change set is:

| File | Function | Change |
|------|----------|--------|
| `common/item_instance.cpp` | `EQ::ItemInstance::IsDroppable()` (line 915) | Wrap `NoDrop == 0` check in `!RuleB(Items, DisableNoDrop)` |
| `common/patches/titanium.cpp` | Item serializer (line 3366) | Emit `255` instead of `item->NoDrop` when `RuleB(Items, DisableNoDrop)` is true |
| `zone/client_packet.cpp` | item-view packet (line 9321) | Same guard |

All three need to land together for the runtime-rule model to actually lift the UI block.

#### Lua/Script Changes

None. `global_npc.lua:event_trade` (lines 164+) already handles companion equip and item return correctly; the PEQ companion trade flow is not the source of the bug.

#### Database Changes

None.

#### Configuration Changes

None. The rule is already set.

## Implementation Sequence

**If we go Path 1 (operational) — this is the primary recommendation:**

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | Validate shared_memory rebuild ordering. Take down all EQ server processes (loginserver, world, all 8 zones). Verify `Items:DisableNoDrop = true` in `rule_values` for ruleset `default`. Run `./bin/shared_memory` to completion. Start loginserver → world → 8 zones per `MEMORY.md` sequence. Confirm startup logs show rule was loaded. | infra-expert | — | 15 minutes, zero code |
| 2 | In-game validation: player fully relogs (disconnects to character-select or loginserver, then reconnects). Trades a NO-TRADE weapon, armor piece, bag+contents, full stack, partial stack to a companion. Verifies each acceptance criterion from the PRD. | game-tester | 1 | 20 minutes |

**If Path 1 fails (shared_memory was already run correctly and trades still fail), escalate to Path 2:**

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 3 | In `common/item_instance.cpp`, modify `EQ::ItemInstance::IsDroppable()` so the `m_item->NoDrop == 0` check is gated on `!RuleB(Items, DisableNoDrop)`. Include `common/rulesys.h` if not already included. | c-expert | 1, 2 (after Path 1 ruled out) | 1 file, ~3 lines |
| 4 | In `common/patches/titanium.cpp` (item serializer emitting `NoDrop`) and `zone/client_packet.cpp` (item view build), emit `255` when `RuleB(Items, DisableNoDrop)` is true. Include `common/rulesys.h`. | c-expert | 3 | 2 files, ~4 lines |
| 5 | Rebuild the server inside the container: `docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`. Full-stack restart per `MEMORY.md`: stop all processes, run `./bin/shared_memory`, start loginserver → world → 8 zones. Player relog. | infra-expert | 4 | 10 minutes build + 5 minutes restart |
| 6 | Re-run in-game validation scenarios 1–9 from the PRD. | game-tester | 5 | 20 minutes |

**Only Path 1 should execute first. Task 3 and beyond ONLY spawn if Path 1 demonstrably fails to resolve the block.**

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Path 1 alone does not fix the bug (perhaps the user already ran shared_memory correctly and something else is wrong) | Medium | Low — identifies the real problem | Game-tester captures a specific failure mode (client rejects drag-in vs. server returns "Hacking detected"). That diagnosis directs Path 2 scope. |
| Path 2 runtime rule consultation is insufficient — Titanium client still blocks drag-in because it has cached `NoDrop=0` for the item | High | Medium | Path 2 includes the serializer patches (titanium.cpp, client_packet.cpp) so new item packets ship `NoDrop=255`. Player relog forces re-serialization. |
| Runtime rule check adds a per-`IsDroppable()`-call overhead | Low | Low | `RuleB` is a simple bool lookup from an in-memory array. Measured cost ≈ 2 memory loads. Tens of thousands of `IsDroppable()` calls per player session are fine. |
| Rule change triggers the anti-hack message ("Hacking activity detected") at `client_packet.cpp:15409/15419` | Medium | Low | That path runs `CheckTradeNonDroppable()` which calls `IsDroppable()`. Path 2's fix flows through both without extra work — the guard is in one place. |

### Compatibility Risks

- **LORE items remain blocked.** `CheckTradeLoreConflict()` at `trading.cpp:708–757` is independent of `NoDrop`; it checks `LoreGroup` and `LoreFlag`. No regression. PRD acceptance criterion "LORE items remain blocked" is preserved.
- **Attuneable items remain blocked.** `IsDroppable()` at `item_instance.cpp:907–908` checks `m_attuned` BEFORE the `NoDrop` check; that path is untouched. Items with `attuneable=1` that have been attuned will still return `false` from `IsDroppable()`. PRD out-of-scope constraint preserved.
- **Merchants and quest NPC behavior.** Path 1 (operational) changes nothing about code. Path 2 changes behavior globally — NO-TRADE items can now be sold to merchants and traded to quest NPCs on this server when the rule is true. **This is a scope widening.** Per the PRD: "If the architect determines the relevant code path cannot be cleanly scoped to companions, the architect may propose the broader fix and flag the tradeoff in architecture.md for the user's decision." That is the situation here. Given this is a solo/small-group server where the rule is intended to be universal, I recommend the user accept the widening.

### Performance Risks

None. Path 1 is zero code. Path 2 adds a constant-time rule lookup to each `IsDroppable()` call — negligible.

## Review Passes

### Pass 1: Feasibility

Path 1 is fully feasible. The EQEmu shared_memory binary is specifically designed to be re-run between rule changes and process startup. `shared_memory/main.cpp:151` explicitly loads rules from the database before writing `items.bin`. The `akk-stack` install target (`init-shared-memory` at line 82 of `assets/scripts/Makefile`) is documented to run this. MEMORY.md documents the full-stack startup sequence including the shared_memory step.

Path 2 is also feasible. Every enforcement site eventually reads the `NoDrop` byte, but they do so via `IsDroppable()` (most of them), `CheckTradeNonDroppable()` (which delegates to `IsDroppable()`), or direct reads. The direct-read sites (`trading.cpp:342, 480, 845, 1024`, `client_packet.cpp:7850, 14383`, `bot.cpp:4389`, etc.) would ALSO need to consult the rule for full coverage, but most of them already allow trade if `NoDrop != 0 || CanTradeFVNoDropItem() || other == this` — in other words, they already have OR-guards, so adding `|| RuleB(Items, DisableNoDrop)` to each is mechanical. However, a cleaner centralization is to funnel them through `IsDroppable()`. **That is follow-on work, not part of this bug fix.**

The hardest part is the Titanium client serialization. The client receives the `NoDrop` byte, caches it, and enforces it UI-side. Without re-serialization (which happens on relog, zone change, or item-inspect), the client's cached state remains wrong. The Titanium protocol offers no way to retroactively un-mark an item as NO TRADE. Path 2 therefore mandates a player relog (or zone change) to make the UI state consistent with the serialized byte — this is acceptable but must be called out to the game-tester.

### Pass 2: Simplicity

Path 1 is literally zero code and maps directly to the existing deploy protocol documented in MEMORY.md. It is the simplest possible fix.

Path 2 changes 3 files and ~7 lines total, all one-liner conditional guards. Still simple.

I deliberately rejected the more complex approaches:
- Adding a `Companions:DisableNoDropOnCompanionTrade` rule and a companion-specific branch in `trading.cpp` — this is more code, more state, and does not fix the upstream client UI block.
- A new server-injected packet to override client UI state — not supported by the Titanium protocol.
- Modifying every direct-read enforcement site individually — correct but noisier than routing through `IsDroppable()`.

### Pass 3: Antagonistic

**What if the user already re-ran shared_memory correctly and Path 1 still fails?**
Then we're looking at the "zone processes mmap'd the old items.bin before the rebuild" edge case. Path 1's task #1 explicitly sequences the stop-processes → rebuild → start-processes order to avoid this.

**What if the Titanium client has a persistent local cache that survives a relog?**
Unlikely — Titanium reloads item data on zone-in via `OP_ItemPacket`. A full disconnect-to-loginserver-and-reconnect forces re-serialization of inventory.

**What if the player traded an item out and back in before the rebuild?**
Irrelevant — the item is regenerated from the `items` table via `items.bin`. Any trade post-rebuild sees the fresh `NoDrop=255` byte.

**What if a quest rewards a NO-TRADE item after the rule is set but before shared_memory rebuilds?**
The item instance is created via `SharedDatabase::CreateItem(...)` which pulls the item template from the memory-mapped file. So the instance inherits `NoDrop=255` only if the file was rebuilt. This is the same case as any other item — no new exploit surface.

**LORE enforcement regression?** No — LORE is checked separately in `CheckTradeLoreConflict()` and in `Client::CheckLoreConflict()` which tests `LoreGroup`/`LoreFlag`, not `NoDrop`. Path 2 doesn't touch those sites.

**Attuneable regression?** No — `IsDroppable()` checks `m_attuned` BEFORE the `NoDrop` branch. Attuned items still return `false`. Path 2's change does not reach the attuneable path.

**Trade-back (companion → player)?** `zone/companion.cpp` and `global_npc.lua:event_trade` handle `!unequip` / dismiss-return via `SummonItem(...)` to the player. `SummonItem` does not go through `IsDroppable()`; it writes to the player's inventory directly. So trade-back from companion to player already works regardless of the NO-TRADE block — the block is only on the player-initiated trade window.

**Merchants (PRD test scenario 8):** Selling to merchants goes through `Client::SellItem` / `Handle_OP_ShopPlayerSell` which check `NoDrop` directly. Path 1 doesn't change this. Path 2 does — merchants would accept NO-TRADE items for sale once the rule is true. This is the scope widening called out in the PRD.

**Exploit vector:** The solo/small-group server has no multi-player economy. Giving no-drop items to merchants (who give coin) is not a meaningful exploit — the player already has the item. Giving no-drop items to a companion then dismissing the companion could in theory lose the item, but the companion system handles dismissal by returning inventory to the owner (per `companion.lua:cmd_dismiss` and `Companion::Dismiss(true)`). So the item is not lost.

### Pass 4: Integration

Path 1 dependency chain: infra-expert performs the rebuild → game-tester validates. Two agents, sequential.

Path 2 dependency chain: c-expert modifies 3 files → infra-expert rebuilds and restarts → game-tester validates. Three agents, sequential.

There is no concurrent work; each phase gates on the previous. No circular dependencies.

The `infra-expert` is critical in both paths because the full-stack restart sequence (shared_memory → loginserver → world → 8 zone processes) is non-trivial and has foot-guns that are specifically called out in MEMORY.md (never use `eqlaunch zone` alongside manually-started zones, 8 zone pool minimum, etc.).

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| infra-expert | 1 (primary path); 5 if fallback needed | Owns full-stack restart: shared_memory → loginserver → world → 8 zones. Documented in MEMORY.md. Do not spawn other experts until Path 1 result is in. |
| c-expert | 3, 4 (only if Path 1 fails) | Owns C++ source changes in `common/item_instance.cpp`, `common/patches/titanium.cpp`, `zone/client_packet.cpp`. |

**Start by spawning ONLY `infra-expert`** for Path 1. After task #2 (game-tester validation) result is in, the orchestrator decides whether to escalate to Path 2 and spawn `c-expert`.

## Validation Plan

The game-tester runs the 9 scenarios from the PRD, plus one diagnostic scenario specific to Path 1's success criterion:

0. **Diagnostic (Path 1 only):** Before running any trade test, in the container shell, confirm the on-disk `server/shared/items` file's modification timestamp is **newer** than the last `rule_values` update for `Items:DisableNoDrop`. If the file is older, Path 1 clearly did not rebuild properly. (`ls -l ~/server/shared/items`; compare to `SELECT * FROM rule_values WHERE rule_name='Items:DisableNoDrop';` updated_at if the table has one, else rely on the rebuild log from infra-expert.)

- [ ] **Scenario 1** — Weapon trade: trade a NO-TRADE weapon to a companion, verify inventory transfer and equip behavior.
- [ ] **Scenario 2** — Armor trade: trade a NO-TRADE armor piece to a companion, verify transfer and equip.
- [ ] **Scenario 3** — Bag trade: trade a NO-TRADE bag with contents, verify bag + contents transfer intact.
- [ ] **Scenario 4** — Stackable full: full stack of NO-TRADE consumables, verify.
- [ ] **Scenario 5** — Stackable partial: partial split, verify.
- [ ] **Scenario 6** — LORE negative: companion has a LORE item of the same type — trade is still blocked for LORE reason (not NO-TRADE).
- [ ] **Scenario 7** — Rule-off regression: set `Items:DisableNoDrop = false`, re-run shared_memory, full restart; verify NO-TRADE items are blocked again.
- [ ] **Scenario 8** — Merchant regression: if Path 1 — merchants still refuse NO-TRADE items (no change from pre-fix). If Path 2 — merchants will accept (scope widened, user-acknowledged).
- [ ] **Scenario 9** — Trade-back: companion → player trade of the same item completes (consistency check).
- [ ] **Attuneable preservation:** An attuneable (and attuned) item still cannot be traded. Behavior preserved.

**Acceptance:** All checkboxes pass before the bug is marked Resolved. If Path 1 partially works (e.g. new NO-TRADE items trade but old ones don't), escalate to Path 2 to close the gap.

---

> **Next step:** Orchestrator to spawn **only `infra-expert`** for Path 1 (task #1). Game-tester is a solo agent for the Validation phase per the standard pipeline; they run after infra-expert reports completion. Only if Path 1 fails to resolve the block does `c-expert` join the implementation team for tasks #3–4.
