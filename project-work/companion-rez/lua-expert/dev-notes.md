# Companion Rez — Dev Notes: lua-expert

> **Feature branch:** `bugfix/companion-rez`
> **Agent:** lua-expert
> **Task(s):** Architecture triage (Lua side)
> **Date started:** 2026-04-27
> **Current stage:** Stage 1 (Plan / Triage)

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| T-Lua-1 | Triage Lua side of rez/post-combat | — | In Progress |

---

## Stage 1: Plan

### Files Examined

| File | Lines (approx) | What You Found |
|------|-------|----------------|
| `akk-stack/server/quests/lua_modules/companion.lua` | ~1512 | Core companion module. No rez/post-combat logic. No event_combat handler. No CastSpell for rez. Has `trigger_soul_wipe`, death-path docs, buff queue (via `buff_request_` timer). |
| `akk-stack/server/quests/global/global_npc.lua` | ~712 | Has event_say, event_trade, event_spawn, event_timer, event_level_up, event_death_zone. **No event_combat handler**. No post-combat rez trigger. Death-zone tracking for commentary context only (not rez). |
| `akk-stack/server/quests/lua_modules/companion_culture.lua` | ~500+ | Has a "resurrection" event_type stub (lines 484-495) for LLM commentary when a companion is rezzed. **This is presentation/flavor only** — it fires when a rez has already succeeded, not a trigger for rez logic. |
| `akk-stack/server/quests/global/CompanionOfNecessity*.lua` | ~18 each | Four old scripts — generic combat NPC pattern. Unrelated to companion system. No rez logic. |
| `akk-stack/server/quests/global/WARDClericPet*.lua` | ~13 each | Scripts for generic cleric-pet NPC. Event_spawn + event_timer: cast `Aura of Restoration` (spell 4795) on self. Not companion-system scripts. No rez logic. |
| `akk-stack/server/quests/global/script_init.lua` | 11 | Standard module bootstrapping (string_ext, command, client_ext, mob_ext, npc_ext, entity_list_ext, general_ext, bit, directional, constants). No rez or encounter registrations. |
| `akk-stack/server/quests/lua_modules/companion_commentary.lua` | — | Unprompted LLM commentary. No rez logic. |

### Key Findings

1. **There is NO Lua-side post-combat rez trigger anywhere.** No `event_combat` handler exists in global_npc.lua or any companion-specific module. No timer-based post-combat scan exists. No CastSpell call for rez spells in the companion system.

2. **There is NO Lua-side `event_death` handler for companions.** global_npc.lua has `event_death_zone` (fires when *any* NPC in the zone dies — used only to update recent-kill tracking for LLM commentary context). It does not trigger rez logic.

3. **The "resurrection" event type in companion_culture.lua (lines 484-495) is presentation-only.** It generates LLM dialogue for *after* a rez has succeeded. Nothing currently calls this path. It assumes the rez already happened via some external mechanism.

4. **companion.lua has NO rez-related command handlers.** The COMMANDS table (lines 90-113) has: passive, balanced, aggressive, follow, guard, recall, tome, flee, equipment, equip, unequip, unequipall, equipmentupgrade, equipmentmissing, stats, status, help, hold, target, assist, buffme, buffs, dismiss. No `!rez` command. This is in scope for the PRD's "player-commanded rez" future feature — not this fix.

5. **The buff queue pattern in global_npc.lua's event_timer (lines 441-600) is the closest analogue.** It: (a) waits for out-of-combat + idle state before acting (`IsEngaged()` + `IsCasting()` checks), (b) queries `companion_spell_sets` DB table for eligible spells by class/level, (c) dispatches `CastSpell()` one at a time via re-arming timer. **This pattern is directly reusable for a rez queue.**

6. **Cleric AI lives in C++, not Lua.** The NPC AI that makes a Cleric cast heals or rez spells during/after combat is C++ (`npc.cpp`, `spells.cpp`). Lua does NOT currently override or extend Cleric post-combat behavior. The fix needs to be: either (a) a Lua post-combat hook that fires after `event_combat(e)` with `e.joined == false`, or (b) a C++ hook that calls back to Lua, or (c) pure C++ in companion.cpp.

7. **`event_combat` with `e.joined == false` IS the post-combat trigger.** The EQEmu event system fires `event_combat` on the NPC when it enters combat (`e.joined == true`) and when it leaves combat (`e.joined == false`). This is the natural post-combat hook a Lua implementation would use. Currently no companion code uses this event.

8. **`companion_spell_sets` DB table already exists** (used by buff queue at line 523). It stores spell_id, class_id, min_level, max_level, spell_type, priority. Rez spells would need to be added as a new spell_type constant (e.g., `SpellType_Rez`).

9. **The buff queue's DB query and CastSpell retry pattern can serve as the implementation model** if the architect chooses Lua for the post-combat rez trigger. The key differences for rez: target is a corpse (not a live entity), combat-state gate is inverted (act only when NOT in combat), and target resolution requires finding corpse entities for party members.

### Lua-Side Architecture Options

**Option A: Lua event_combat hook (Lua-primary)**
- Add `event_combat` handler in global_npc.lua (or an encounter) that fires on `e.joined == false` for Cleric companions.
- On combat-end, start a short timer (`rez_scan_<entity_id>`, N seconds per AC-1).
- Timer fires: scan group for downed party members (corpses), build a rez queue similar to buff queue.
- Cast rez spells via CastSpell(), gated on `not IsEngaged()`.
- **Pro:** All logic is in Lua, hot-reloadable (`#reloadquests`). Pattern already exists in buff queue code.
- **Con:** Lua has no direct access to the zone's corpse list or a guaranteed way to target NPC corpses. Needs C++ support for "auto-accept rez for NPC targets" (the crux of BUG-001 — see PRD appendix).

**Option B: C++ primary, Lua callback optional**
- C++ companion.cpp implements post-combat scan and rez dispatch.
- Lua is NOT the trigger — it's just the presentation layer (e.g., fire `resurrection` LLM event after C++ confirms rez succeeded).
- **Pro:** C++ has direct access to corpse list, rez request flow, entity state.
- **Con:** Requires C++ build cycle; not hot-reloadable.

**Recommendation to architect:** Option A for the trigger (Lua event_combat hook) is cleanest if C++ can expose: (a) a method to list party-member corpses in zone, and (b) auto-accept rez for NPC companion targets. If those C++ APIs don't exist or are hard to add, Option B is more reliable. The architect should decide after reviewing what's available in lua_general.cpp and companion.cpp.

### What Lua Cannot Do Without C++ Help

- **Find NPC companion corpses:** `eq.get_entity_list()` returns live entities. Whether corpses (Lua_Corpse objects) are accessible and filterable by group membership is unconfirmed — needs c-expert to verify what `Lua_Corpse` exposes and whether EntityList has a corpse-search method.
- **Auto-accept rez for NPC targets:** The NPC corpse has no UI to accept a rez request. This gap must be closed in C++. Lua cannot solve this at all — it's a server-side rez-accept bypass.
- **Confirm rez "took":** After `CastSpell()`, Lua cannot directly observe whether the rez completed and the corpse was removed. A post-cast timer that checks if the target corpse is gone would be an indirect signal.

### Existing Infrastructure Reusable for Rez

| Existing pattern | File:line | Reusability for rez |
|---|---|---|
| Buff queue timer + CastSpell | global_npc.lua:441-600 | High — same one-cast-per-tick pattern |
| IsEngaged() combat gate | global_npc.lua:471 | Direct reuse — gate rez on `not IsEngaged()` |
| companion_spell_sets DB query | global_npc.lua:523-548 | Reuse after adding rez spell_type |
| "resurrection" LLM event | companion_culture.lua:484 | Ready — fire after rez succeeds |
| `event_death_zone` zone tracking | global_npc.lua:656-711 | Possibly reuse to detect companion death events |

### Test Infrastructure

The existing `make test-companion` pattern (from companion-rerecruit) runs unit tests against companion.lua logic. For rez scenarios:

- **Unit-testable in Lua:** spell tier preference logic (highest affordable), queue ordering, combat-state guard (`IsEngaged()` mock).
- **Integration-testable:** CastSpell → corpse resolution → companion return. Needs a live zone.
- **Game-tester only:** Player rez window, multi-target sequence, NPC corpse auto-accept in practice.

Extending `make test-companion` for rez would require: mock `Lua_Corpse` objects, mock group with dead members, mock `IsEngaged()` state transitions.

---

## Stage 2: Research

_Pending architect dispatch and plan socialization._

---

## Stage 3: Socialize

_Pending._

---

## Stage 4: Build

_Not started — planning phase only._

---

## Open Items

- [ ] Confirm with c-expert: does `eq.get_entity_list()` expose a corpse-search method? What does `Lua_Corpse` expose?
- [ ] Confirm with c-expert: what C++ method will handle auto-accept for NPC rez targets?
- [ ] Confirm with data-expert: companion_spell_sets schema — what spell_type values exist? What's the right constant for rez spells?
- [ ] Architect to decide: Option A (Lua-primary) vs Option B (C++ primary) for the rez trigger.

---

## Context for Next Agent

The Lua side has **zero existing rez or post-combat logic**. No `event_combat` handler exists in any companion-related Lua file. The fix requires adding new Lua infrastructure (or C++ alone handles it). The buff queue pattern in global_npc.lua:441-600 is the closest analogue and should be studied before writing any rez queue code. The `companion_culture.lua` "resurrection" event type at line 484 is a ready-made LLM hook for post-rez flavor, but it requires C++ to first close the NPC auto-accept gap that is the root cause in BUG-001.
