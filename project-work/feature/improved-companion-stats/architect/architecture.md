# improved-companion-stats — Architecture & Implementation Plan

> **Feature branch:** `feature/improved-companion-stats`
> **PRD:** `game-designer/prd.md`
> **Author:** architect
> **Date:** 2026-03-10
> **Status:** Approved

---

## Executive Summary

This feature adds a new `!stats` companion command and enhances the existing
`!equipment` command to provide players with detailed combat stat visibility
and richer item information (AC, damage/delay, clickable item links) for their
companions. The implementation requires three new C++ Lua bindings on
`Lua_Companion` (`GetMinDMG`, `GetMaxDMG`, `GetCombatRole`), a modification
to the C++ `Companion::ShowEquipment()` method to include item links and stat
summaries, a new Lua `cmd_stats` handler in `companion.lua`, and an access
control change to allow any player to use read-only commands on any companion.
No database changes, no new rules, no packet modifications required.

## Existing System Analysis

### Current State

**Companion command system:** All `!`-prefixed companion commands are dispatched
through `companion.lua:dispatch_prefix_command()` (called from
`global_npc.lua:13`). The dispatch function performs a blanket ownership check
at line 120 before parsing and routing commands. Commands are defined in the
`COMMANDS` table (line 77-94) mapping command names to handler functions.

**Existing `!status` command** (`companion.lua:556-575`): Displays level, class,
HP/mana, XP progress, stance, mode, and companion type. This is the operational
overview. The new `!stats` command is complementary — it shows combat stats.

**Existing `!equipment` command** (`companion.lua:516-518`): Delegates entirely
to `companion:ShowEquipment(client)` which calls C++ `Companion::ShowEquipment()`.
The C++ method (`companion.cpp:1972-2014`) iterates 19 display slots, looks up
item names via `database.GetItem(item_id)`, and displays slot label + item name.
No item links, no AC/damage values.

**Lua_Companion binding** (`lua_companion.h/cpp`): Inherits from `Lua_Mob` (not
`Lua_NPC`) due to a luabind limitation where inherited methods are not resolved
at runtime. Currently exposes 24 methods focused on companion lifecycle,
equipment management, follow/guard, and XP. Stat accessors (STR, STA, AC, etc.)
are available via inherited `Lua_Mob` methods.

**C++ Companion class** (`companion.h`): Inherits from `NPC` which inherits from
`Mob`. Has `GetCombatRole()` returning `CompanionCombatRole` enum (0-4) and
`DetermineRoleFromClass()` static method. `GetMinDMG()`/`GetMaxDMG()` are
available on `NPC` (the C++ parent class) but not exposed through `Lua_Companion`.

### Gap Analysis

| Requirement | Current State | Gap |
|---|---|---|
| `!stats` command | Does not exist | New Lua handler + new bindings needed |
| Min/Max damage in Lua | Available on `Lua_NPC` but not `Lua_Companion` | Add `GetMinDMG()`/`GetMaxDMG()` to `Lua_Companion` |
| Combat role in Lua | Not exposed to Lua at all | Add `GetCombatRole()` to `Lua_Companion` |
| Equipment item links | `ShowEquipment()` shows plain text names | Modify C++ to use `quest_manager.varlink()` |
| Equipment AC/damage | Not shown | Modify C++ to read `ItemData->AC/Damage/Delay` |
| Open inspection | Blanket ownership check blocks all commands | Split ownership check into owner-required vs read-only |
| `!status` open access | Blocked by ownership check | Mark as `requires_owner = false` |

## Technical Approach

### Architecture Decision

This feature spans two layers: C++ (new Lua bindings + enhanced ShowEquipment)
and Lua (new command handler + access control change). No database, rule, or
configuration changes are needed.

| Component | Change Type | Justification |
|---|---|---|
| `lua_companion.h/cpp` | C++ — Add 3 methods | `GetMinDMG()`, `GetMaxDMG()`, `GetCombatRole()` not accessible via `Lua_Mob` inheritance; must be explicitly added (same pattern as `SetFollowDistance` workaround) |
| `companion.cpp` | C++ — Modify `ShowEquipment()` | Already has `database.GetItem()` and `EQ::ItemData*` with AC/Damage/Delay fields; adding item links via `quest_manager.varlink()` is straightforward in C++ |
| `companion.lua` | Lua — New handler + access control | `cmd_stats` display logic is string formatting from existing stat accessors; access control change is a simple table field + conditional check |

**Why C++ for ShowEquipment enhancement (not pure Lua rewrite):**
The existing `ShowEquipment()` already iterates equipment slots and calls
`database.GetItem()` to get `EQ::ItemData*`. The `ItemData` struct has `AC`,
`Damage`, and `Delay` fields directly accessible. The `quest_manager.varlink()`
function generates Titanium-compatible item links. Rewriting this in Lua would
require either: (a) exposing a new `GetItemData()` binding returning AC/Damage/
Delay per item, or (b) making individual database queries per slot from Lua.
Both are more invasive than modifying the existing 40-line C++ method.

**Why Lua for !stats (not C++ ShowStats method):**
The stat accessors (STR, STA, AC, ATK, resists, HP, mana, level, class name)
are all already available on `Lua_Mob`, which `Lua_Companion` inherits. Only
`GetMinDMG()`, `GetMaxDMG()`, and `GetCombatRole()` need new bindings. Writing
the display logic in Lua means the output format can be tweaked without a C++
rebuild — important for a display-only feature where formatting will likely
be iterated on.

### Data Model

No new or modified tables, columns, or relationships.

### Code Changes

#### C++ Changes

**File: `eqemu/zone/lua_companion.h`**
Add 3 new method declarations:
- `uint32 GetMinDMG();` — wraps `Companion::GetMinDMG()` (inherited from NPC)
- `uint32 GetMaxDMG();` — wraps `Companion::GetMaxDMG()` (inherited from NPC)
- `uint8 GetCombatRole();` — wraps `Companion::GetCombatRole()`, returns enum as uint8

**File: `eqemu/zone/lua_companion.cpp`**
Add 3 new method implementations following the existing `Lua_Safe_Call_*` pattern.
Register all three in `lua_register_companion()` luabind scope.

**File: `eqemu/zone/companion.cpp`**
Modify `Companion::ShowEquipment(Client* client)` (lines 1972-2014):
- Replace `client->Message(Chat::White, "  %-12s %s", ...)` with enhanced output
- For each occupied slot:
  - Generate item link via `quest_manager.varlink(item_id)` 
  - Read `item->AC`, `item->Damage`, `item->Delay` from `EQ::ItemData*`
  - For weapon slots (Primary, Secondary, Range): append `(Dmg: X  Delay: Y)` if Damage > 0
  - For armor/accessory slots: append `(AC: X)` if AC > 0
  - For items with neither: show item link only
- Change header from `client->Message(Chat::Yellow, "%s's Equipment:", ...)` to
  `client->Message(Chat::Yellow, "=== %s - Equipment ===", ...)` for consistency
  with `!stats` header format

Note: `quest_manager.varlink(item_id)` requires the quest_manager to have a valid
initiator. In ShowEquipment, this is called from within a quest event context
(the `!equipment` command is dispatched from global_npc.lua event_say), so the
quest_manager should have the client as initiator. If not, an alternative is
to use the `Mob::MakeItemLink()` static method directly, or call the
serialization functions in `common/item_instance.h`. The c-expert should verify
quest_manager availability in this call path and fall back to direct item link
generation if needed.

#### Lua/Script Changes

**File: `akk-stack/server/quests/lua_modules/companion.lua`**

1. **Access control change** (lines 118-142, `dispatch_prefix_command`):
   - Add `requires_owner` field to `COMMANDS` table entries. Default is `true`
     (owner-only). Read-only commands set `requires_owner = false`:
     ```
     stats      = { handler = "cmd_stats",     category = "information", requires_owner = false },
     status     = { handler = "cmd_status",    category = "information", requires_owner = false },
     equipment  = { handler = "cmd_equipment", category = "equipment",   requires_owner = false },
     gear       = { handler = "cmd_equipment", category = "equipment",   requires_owner = false },
     help       = { handler = "cmd_help",      category = "information", requires_owner = false },
     ```
   - Modify ownership check logic: parse command first, then check ownership
     only if `COMMANDS[cmd].requires_owner ~= false`

2. **New `cmd_stats` handler**:
   - Accepts `(npc, client, args)` like all command handlers
   - Calls stat accessors on `npc` (which is the Lua_Companion object):
     - Identity: `npc:GetCleanName()`, `npc:GetLevel()`, `npc:GetClassName()`
     - Role: `npc:GetCombatRole()` mapped to display string via local table
     - Vitals: `npc:GetHP()`, `npc:GetMaxHP()`, `npc:GetMana()`, `npc:GetMaxMana()`
     - Attributes: `npc:GetSTR()`, `npc:GetSTA()`, `npc:GetAGI()`, `npc:GetDEX()`,
       `npc:GetINT()`, `npc:GetWIS()`, `npc:GetCHA()`
     - Combat: `npc:GetAC()`, `npc:GetATK()`, `npc:GetMinDMG()`, `npc:GetMaxDMG()`
     - Resists: `npc:GetMR()`, `npc:GetFR()`, `npc:GetCR()`, `npc:GetPR()`, `npc:GetDR()`
   - Output format per PRD example (using `client:Message()` with Chat color 15)

3. **Add `!stats` to COMMANDS table**:
   ```
   stats = { handler = "cmd_stats", category = "information", requires_owner = false },
   ```

4. **Update `cmd_help`** to include `!stats` in the information section.

#### Database Changes

None.

#### Configuration Changes

None.

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | Add `GetMinDMG()`, `GetMaxDMG()`, `GetCombatRole()` to `Lua_Companion` (header + cpp + registration) | c-expert | — | Small: ~30 lines across 2 files |
| 2 | Enhance `Companion::ShowEquipment()` to include item links, AC, and Damage/Delay | c-expert | — | Small: modify ~20 lines in 1 file |
| 3 | Add `cmd_stats` handler, modify access control in `dispatch_prefix_command()`, add `!stats` to COMMANDS, update help text | lua-expert | 1 | Medium: ~80 lines in 1 file |

Tasks 1 and 2 are independent C++ changes that can be done in parallel by c-expert.
Task 3 depends on Task 1 (the new Lua bindings must exist before `cmd_stats` can call them).
Task 3 does NOT depend on Task 2 (the equipment enhancement is independent of stats).

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `quest_manager.varlink()` not available in `ShowEquipment` call context | Low | Medium — item links would show as empty strings | c-expert verifies call path; falls back to `Mob::MakeItemLink()` or `EQ::saylink::Create()` if quest_manager is not initialized |
| Luabind runtime resolution for new methods | Low | High — methods return nil at runtime | Pattern is identical to existing workarounds (`SetFollowDistance`, `SetFollowID`); well-established |
| `GetCombatRole()` returns uninitialized value if called before `AI_Start()` | Very Low | Low — displays wrong role text | `m_combat_role` is set in constructor via `DetermineRoleFromClass()` (companion.cpp:129), not deferred to AI_Start |

### Compatibility Risks

No existing behavior is changed except:
- `!equipment` output format changes (adds item links and stat info). This is
  strictly additive — all existing information (slot names, item names) is
  preserved. The clickable links are a superset.
- `dispatch_prefix_command()` ownership check is relaxed for read-only commands.
  Owner-only commands are unaffected. The `requires_owner` field defaults to
  `true` implicitly (any entry without the field triggers ownership check).

### Performance Risks

None. Both commands are player-initiated, produce a fixed number of `Message()`
calls (stats: ~8 messages, equipment: ~20 messages), and involve no database
queries beyond the existing `database.GetItem()` calls in ShowEquipment (which
uses the in-memory item cache, not live DB queries).

## Review Passes

### Pass 1: Feasibility

**Can we build this?** Yes, with high confidence.

- All stat accessors needed for `!stats` are already on `Lua_Mob` and will
  be inherited by `Lua_Companion`. Verified by reading `lua_mob.h` lines 144-158.
- `GetMinDMG()`/`GetMaxDMG()` exist on the C++ `NPC` class (npc.h:304-305) and
  just need to be wrapped in `Lua_Companion` — identical pattern to
  `SetFollowDistance` (lua_companion.cpp:194-198).
- `GetCombatRole()` is a simple getter returning a cached enum (companion.h:133,
  companion.cpp:614-617).
- `quest_manager.varlink(item_id)` is confirmed available in C++ (used by
  `lua_general.cpp:4013-4014` for the Lua `eq.item_link()` binding).
- `EQ::ItemData` has `AC` (line 410), `Damage` (line 431), and `Delay` (line 425)
  fields, confirmed in `common/item_data.h`.

**Hardest part:** The access control change in `dispatch_prefix_command()`.
The current code does ownership check before parsing the command name. The new
logic must parse the command name first, look it up in COMMANDS, then decide
whether to check ownership. This is a control flow reorder — straightforward
but must be done carefully to avoid accidentally opening owner-only commands.

### Pass 2: Simplicity

**Is this the simplest approach?** Yes.

- **Alternative considered: Implement both !stats AND !equipment entirely in C++.**
  Rejected because the !stats display is pure formatting of already-accessible
  values — Lua is the right layer for display logic that may be iterated on.
  The equipment enhancement stays in C++ because it already lives there and
  has direct access to ItemData.

- **Alternative considered: Implement !equipment entirely in Lua.**
  Rejected because it would require either: (a) a new `GetItemAC(slot)`-type
  binding per slot, or (b) database queries from Lua per slot. Both are more
  invasive than the 20-line C++ modification.

- **Alternative considered: Add a single `ShowStats(Client*)` C++ method.**
  Rejected because it would require a C++ rebuild for any formatting change.
  The stat values are already accessible in Lua — only 3 new bindings are
  needed, not a new method.

- **YAGNI applied:** No new rules, no configuration toggles, no database
  tables. This is a display feature.

### Pass 3: Antagonistic

**Edge cases that could break the design:**

1. **Companion targeted by non-owner:** The PRD explicitly requires this to work.
   The access control change handles it. The Lua code accesses companion methods
   on the target NPC — these are read-only methods that do not modify state.
   No exploit vector.

2. **Non-companion targeted:** The `dispatch_prefix_command` is only called from
   `global_npc.lua` when `e.self:IsCompanion()` is true (line 11). A non-companion
   NPC will never reach this code path. However, the new access control flow
   parses the command before checking ownership. If somehow a non-companion NPC
   had `IsCompanion()` return true falsely, the stat methods would still work
   (they call Mob base class methods). No crash risk.

3. **Companion with no equipment:** Handled by existing `ShowEquipment()` —
   empty slots show "(empty)". No change needed.

4. **Companion with items not in item cache:** `database.GetItem(item_id)` returns
   nullptr for unknown items. The existing code handles this with
   `item ? item->Name : "(unknown item)"`. The enhanced version must also
   nil-check before accessing AC/Damage/Delay. c-expert must maintain this guard.

5. **Combat role display for unexpected class IDs:** `DetermineRoleFromClass()`
   has a default case returning `COMBAT_ROLE_MELEE_DPS`. The Lua role table should
   include all 5 enum values (0-4) with a fallback for unknown values.

6. **Access control bypass:** Could a player exploit the read-only command opening
   to somehow modify a companion they don't own? No — the handlers for !stats,
   !equipment, and !status only call getter methods and `Message()`. They do not
   call `SetStance`, `Dismiss`, or any state-modifying method. The
   `requires_owner` field is checked per-command, not globally.

7. **Long companion names overflowing message lines:** EQ's message window wraps
   text. `GetCleanName()` returns the display name without special characters.
   No risk of buffer overflow — `client->Message()` uses `fmt::format` internally.

**Server crash scenario:** The original `#npcstats` crash occurred because
`ShowStats/SendStatsWindow` called `CastToClient()` on a non-client entity.
The `!stats` command avoids this entirely — it never calls `CastToClient()`,
`ShowStats()`, or `SendStatsWindow()`. It calls only getter methods on the
companion (which is a valid NPC subclass).

### Pass 4: Integration

**Implementation order walkthrough:**

1. c-expert implements Tasks 1 and 2 (C++ changes). These are independent and
   can be done in a single commit. The server must be rebuilt after this step.

2. lua-expert implements Task 3 (Lua changes). This requires the new bindings
   from Task 1 to exist, so it must come after the C++ build. However, the
   access control change and help text updates are independent of the C++ changes
   and could be drafted in parallel (just not tested until the build is done).

3. Validation: game-tester tests all acceptance criteria from the PRD.

**Dependency chain:** C++ build (Tasks 1+2) -> Lua changes (Task 3) -> Validation.

**Each expert has sufficient context:**
- c-expert needs: `lua_companion.h/cpp` (existing patterns), `companion.cpp`
  (ShowEquipment method), `npc.h` (GetMinDMG/GetMaxDMG signatures),
  `companion.h` (GetCombatRole signature), `item_data.h` (AC/Damage/Delay fields),
  `quest_manager` varlink method.
- lua-expert needs: `companion.lua` (existing command system), PRD example
  output format, the 3 new binding names and their return types.

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| c-expert | Tasks 1, 2 | New Lua bindings + ShowEquipment C++ modification |
| lua-expert | Task 3 | New cmd_stats handler + access control change in companion.lua |

## Validation Plan

- [ ] Target any companion and type `!stats`. Verify output shows: name, level, class, combat role, HP/MaxHP, Mana/MaxMana, STR, STA, AGI, DEX, INT, WIS, CHA, AC, ATK, min-max damage, MR, FR, CR, PR, DR.
- [ ] Target a companion owned by a different player (or with a second client) and type `!stats`. Verify it works without "That is not your companion" error.
- [ ] Target a companion and type `!equipment`. Verify each occupied slot shows a clickable item link plus AC (for armor) or Dmg/Delay (for weapons).
- [ ] Click an item link in the `!equipment` output. Verify the standard EQ item inspection window opens.
- [ ] Target a companion with empty equipment slots. Verify "(empty)" is displayed for those slots.
- [ ] Target a non-companion NPC and type `!stats`. Verify no output (command is only dispatched for companions).
- [ ] Type `!stats` with no target. Verify no crash and appropriate error or no response.
- [ ] Target a companion owned by another player and type `!dismiss`. Verify ownership check rejects with "That is not your companion."
- [ ] Target own companion and type `!dismiss`, `!passive`, `!aggressive`, `!balanced`, `!follow`, `!guard`. Verify owner-only commands still work for the owner.
- [ ] Type `!status` targeting any companion (own or other). Verify it works without ownership check (read-only).
- [ ] Type `!help`. Verify `!stats` appears in the information section.
- [ ] Verify combat role display is correct for different companion classes: Warrior shows "Melee Tank", Cleric shows "Healer", Wizard shows "Caster DPS", Rogue shows "Rogue", Monk shows "Melee DPS".
- [ ] Verify no zone crash occurs when using `!stats` on a companion (contrast with `#npcstats` which crashes).
- [ ] Verify `!equipment` still works for the companion owner (regression test).
- [ ] Verify `!gear` alias works identically to `!equipment` (both read-only, both show enhanced output).

---

> **Next step:** Spawn the implementation team with ONLY the agents listed
> in "Required Implementation Agents" above. Do not spawn experts without
> assigned tasks.
