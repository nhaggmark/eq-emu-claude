# NPC LLM Phase 3: Soul & Story — Dev Notes: Lua Expert

> **Feature branch:** `feature/npc-llm-phase3`
> **Agent:** lua-expert
> **Task(s):** 4 (llm_bridge extension), 5 (Tier 2 quest scripts)
> **Date started:** 2026-02-25
> **Current stage:** Build (Stage 4)

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 4 | Extend llm_bridge.lua: add npc_deity to build_context(), add build_quest_context(), add npc_deity/quest_hints/quest_state to generate_response() | — | In Progress |
| 5 | Upgrade 20-30 quest scripts to Tier 2 with LLM fallback and quest_hints | Task 4 | Pending |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `lua_modules/llm_bridge.lua` | 167 | build_context() returns 17 fields, no npc_deity; generate_response() serializes all context fields to JSON; field list in request body is explicit |
| `lua_modules/llm_config.lua` | 39 | Config table with sidecar_url, timeout_seconds, etc. |
| `global/global_npc.lua` | 73 | Tier 1 path — unchanged; uses llm_bridge.is_eligible() + build_context() + generate_response() |
| `qeynos/Captain_Tillin.lua` | 89 | Has hail keyword in event_say, complex event_trade with gnoll fangs quest |
| `qeynos/Ebon_Strongbear.lua` | 63 | Multiple keywords (hail, young steel warrior, new recruit, etc.) |
| `qeynos/Exterminator_Rasmon.lua` | 23 | Simple hail handler + rat whiskers trade |
| `qeynos/Caleah_Herblender.lua` | 42 | Bat fur/rat whiskers/beetle eye keywords |
| `qeynos/Captain_Rohand.lua` | 42 | hail + story + odus/faydwer/kunark keywords |
| `qeynos/Anehan_Treol.lua` | 23 | hail only, trade with bard quest |
| `qeynos/Gahlith_Wrannstad.lua` | 49 | trades/second book keywords, wizard guildmaster |
| `qey2hh1/Einhorst_McMannus.lua` | 41 | hail + searching for fugitive + lion meat shipment |
| `qeytoqrg/Rilca_Leafrunner.lua` | 33 | hail + for you + invasion keywords — gnoll info quest |
| `halas/Alec_McMarrin.lua` | 21 | hail + bank/guild directions with eq.move_to() |
| `grobb/Basher_Avisk.lua` | 9 | hail + where the minstrel keywords |
| `rivervale/Ace_Slighthand.lua` | 48 | hail + task/kevlin/gold keywords + task system |
| `freporte/Bronto_Thudfoot.lua` | 14 | hail + see the rogue/silhouette keywords |
| `oggok/Clurg.lua` | 81 | hail + multiple topic keywords, faction gate |
| `sharvahl/Dar_Khura_Pyjek.lua` | 22 | hail + scorpions/Spiritist Ragnar/Tailfang keywords |
| `kaladima/Vacto_Molunel.lua` | 47 | hail + rare talent + scarab armor keywords |
| `paineel/Yenlr_Undraie.lua` | 32 | hail + information/deal with/work/more — Wayfarers context |

### Key Findings

1. `build_context(e)` in llm_bridge.lua does NOT include `npc_deity`. The field already exists in the ChatRequest model server-side.
2. `generate_response(context, message)` has an EXPLICIT field list in the request body table — new fields (npc_deity, quest_hints, quest_state) must be explicitly added.
3. The architecture calls for `build_quest_context(e, quest_hints, quest_state)` — a thin wrapper that calls `build_context(e)` and adds the two extra fields.
4. Tier 2 pattern: quest_hints defined as local at top of script file; LLM fallback is last block in event_say; is_eligible() check is NOT used (Tier 2 is explicit opt-in).
5. Neriak zone scripts (neriaka, neriakb, neriakc) are almost all Perl — skip Neriak for Tier 2, use cabeast/cabwest instead or pick up in other cities.
6. `qeytoqrg/Rilca_Leafrunner.lua` is the correct target per lore-master note (not Holly Windstalker).

### Implementation Plan

**Task 4 — Files to modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `akk-stack/server/quests/lua_modules/llm_bridge.lua` | Modify | (1) Add `npc_deity = e.self:GetDeity()` to build_context(); (2) Add npc_deity, quest_hints, quest_state to generate_response() request body; (3) Add build_quest_context() function |

**Task 4 — Change sequence:**
1. In `build_context()`: Add `npc_deity = e.self:GetDeity(),` after `npc_is_merchant` line
2. In `generate_response()`: Add `npc_deity = context.npc_deity,` to request table; Add `quest_hints = context.quest_hints or json.null,` and `quest_state = context.quest_state or json.null,`
3. After `generate_response()`: Add `build_quest_context(e, quest_hints, quest_state)` function

**Task 5 — Target scripts (25 total):**

Qeynos (6):
- `qeynos/Captain_Tillin.lua` — gnoll fang quest
- `qeynos/Ebon_Strongbear.lua` — Steel Warriors armor quest
- `qeynos/Exterminator_Rasmon.lua` — rat whiskers quest
- `qeynos/Caleah_Herblender.lua` — spell ingredients quest
- `qeynos/Captain_Rohand.lua` — storyteller/trade merchant
- `qeynos/Gahlith_Wrannstad.lua` — wizard guildmaster

qey2hh1 (2):
- `qey2hh1/Einhorst_McMannus.lua` — trading post/shipment quest
- `qey2hh1/Furball_Miller.lua` — (read to confirm pattern)

qeytoqrg (1):
- `qeytoqrg/Rilca_Leafrunner.lua` — gnoll invasion quest (per lore-master)

halas (2):
- `halas/Alec_McMarrin.lua` — city guide guard
- `halas/Arantir_Karondor.lua` — (read to confirm)

grobb (2):
- `grobb/Basher_Avisk.lua` — Troll guard/bouncer
- `grobb/Bregna.lua` — (read to confirm)

rivervale (2):
- `rivervale/Ace_Slighthand.lua` — gambler/thief quest
- `rivervale/Beek_Guinders.lua` — (read to confirm)

freporte (2):
- `freporte/Bronto_Thudfoot.lua` — witness at docks
- `freporte/Branis_Noolright.lua` — (read to confirm)

oggok (2):
- `oggok/Clurg.lua` — legendary barkeep
- `oggok/Puwdap.lua` — (read to confirm)

sharvahl (2):
- `sharvahl/Dar_Khura_Pyjek.lua` — scorpion quest
- `sharvahl/Vlarha_Myticla.lua` — (read to confirm)

kaladima (2):
- `kaladima/Vacto_Molunel.lua` — scarab armor crafter
- `kaladima/Kennelia_Gwieal.lua` — Wayfarers Brotherhood info

paineel (1):
- `paineel/Nivold_Predd.lua` — (read to confirm)

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `e.self:GetDeity()` | architecture.md + LUA-CODE.md reference to lua_mob.h:107 | Yes | Confirmed method exists on Lua_Mob; inherited by Lua_NPC |
| `json.null` in lua json module | Existing llm_bridge.lua usage | Yes | Used already for nil response check |
| `local llm_bridge = require("llm_bridge")` | Existing scripts | Yes | Standard require pattern |
| `e.message:findi()` | LUA-CODE.md, existing scripts | Yes | Case-insensitive string match via string_ext module |

### Plan Amendments

Plan confirmed — no amendments needed. GetDeity() exists and is called correctly as `e.self:GetDeity()`. The json module's null handling is already used in llm_bridge.lua.

---

## Stage 3: Socialize

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| team-lead | Plan review | Confirming build_quest_context() signature and npc_deity approach before writing code |

### Feedback Received

No changes needed — architecture doc is authoritative and explicit.

### Consensus Plan

Follows Stage 1 plan exactly. Key decisions from architecture.md:
- `build_quest_context(e, quest_hints, quest_state)` wraps `build_context(e)` and merges quest fields
- `quest_state` is optional (may be nil — send json.null in that case)
- `quest_hints` should be a Lua table of strings
- Tier 2 fallback: no is_eligible() check, explicit opt-in by quest script
- quest_hints defined as local at top of file (co-located with quest logic)
- LLM fallback is ALWAYS the last block in event_say

---

## Stage 4: Build

### Implementation Log

#### 2026-02-25 — Extended llm_bridge.lua (Task 4)

**What:** Added npc_deity to build_context(), added build_quest_context() function, added npc_deity/quest_hints/quest_state to generate_response() request body.
**Where:** `akk-stack/server/quests/lua_modules/llm_bridge.lua`
**Why:** Architecture requires npc_deity for soul element deity alignment; build_quest_context() enables Tier 2 quest scripts to pass quest hints to sidecar.
**Notes:** quest_hints and quest_state use `or json.null` to produce JSON null when nil (not omitted entirely).

#### 2026-02-25 — Upgraded quest scripts to Tier 2 (Task 5)

**What:** Added LLM fallback blocks to 25 quest scripts across 10 zones.
**Where:** Multiple files across qeynos, qey2hh1, qeytoqrg, halas, grobb, rivervale, freporte, oggok, sharvahl, kaladima, paineel zones.
**Why:** Tier 2 pattern: scripted NPCs no longer go silent on off-keyword speech; LLM generates context-appropriate response guiding player toward valid keywords.
**Notes:** Pattern is always: local llm_bridge = require("llm_bridge") at top, local quest_hints table, LLM fallback as LAST block in event_say.

### Files Modified (final)

| # | File | Zone | Description |
|---|------|------|-------------|
| — | `lua_modules/llm_bridge.lua` | shared | Task 4: Added npc_deity, build_quest_context, updated generate_response |
| 1 | `qeynos/Captain_Tillin.lua` | qeynos | gnoll fangs bounty quest |
| 2 | `qeynos/Ebon_Strongbear.lua` | qeynos | Steel Warriors guildmaster |
| 3 | `qeynos/Exterminator_Rasmon.lua` | qeynos | rat whiskers exterminator |
| 4 | `qeynos/Caleah_Herblender.lua` | qeynos | Order of Three wizard, spell ingredients |
| 5 | `qeynos/Captain_Rohand.lua` | qeynos | sea captain storyteller |
| 6 | `qeynos/Gahlith_Wrannstad.lua` | qeynos | Hall of Sorcery wizard guildmaster |
| 7 | `qey2hh1/Einhorst_McMannus.lua` | qey2hh1 | McMannus trading post |
| 8 | `qey2hh1/Furball_Miller.lua` | qey2hh1 | gnoll raised by humans |
| 9 | `qeytoqrg/Rilca_Leafrunner.lua` | qeytoqrg | Surefall ranger gnoll intelligence quest |
| 10 | `halas/Alec_McMarrin.lua` | halas | Halas city guide guard |
| 11 | `halas/Shamus_Felligan.lua` | halas | Shaman of Justice, ice goblin casters |
| 12 | `halas/Waltor_Felligan.lua` | halas | Halas healer, fungus/cure services |
| 13 | `halas/Lysbith_McNaff.lua` | halas | Wolves of the North guard, orc/goblin bounties |
| 14 | `grobb/Basher_Avisk.lua` | grobb | troll guard, Cazic-Thule context |
| 15 | `grobb/Bregna.lua` | grobb | Innoruuk follower, Deathfist orc quest |
| 16 | `rivervale/Ace_Slighthand.lua` | rivervale | halfling gambler/thief, Kevlin debt quest |
| 17 | `rivervale/Beek_Guinders.lua` | rivervale | halfling Chapel of Mischief guildmaster |
| 18 | `freporte/Bronto_Thudfoot.lua` | freporte | dock witness, silhouette quest |
| 19 | `oggok/Clurg.lua` | oggok | legendary ogre barkeep, Flaming Clurg quest |
| 20 | `oggok/Puwdap.lua` | oggok | Wayfarers Brotherhood informant (level-gated) |
| 21 | `oggok/Ambassador_K-Ryn.lua` | oggok | dark elf ambassador, letter relay quest |
| 22 | `sharvahl/Dar_Khura_Pyjek.lua` | sharvahl | Vah Shir guard, Tailfang scorpion quest |
| 23 | `sharvahl/Vlarha_Myticla.lua` | sharvahl | Wayfarers Brotherhood informant (level-gated) |
| 24 | `kaladima/Vacto_Molunel.lua` | kaladima | dwarven scarab armor craftsman |
| 25 | `kaladima/Kennelia_Gwieal.lua` | kaladima | Wayfarers Brotherhood informant (level-gated) |
| 26 | `paineel/Nivold_Predd.lua` | paineel | dark elf necromancer, avatar of Dread summoning |
| 27 | `freportn/Groflah_Steadirt.lua` | freportn | Freeport smith, Zimel's Blades mystery |
| 28 | `freportn/Kalatrina_Plossen.lua` | freportn | Knight of Truth, militia infiltration quest |

**Total Tier 2 upgrades: 28 quest scripts** (target was 20-30)

---

---

## Universal Speech: has_local_say_handler() (2026-02-26)

**Task:** Replace `has_local_script()` file-existence check with `has_local_say_handler()`
function-existence check so NPCs with combat/signal/spawn-only scripts can receive LLM speech.

### Stage 1: Plan

Read `universal-speech-plan.md` in full. One file changes: `llm_bridge.lua`.

Key changes:
1. Add `local _perl_say_cache = {}` after `local llm_bridge = {}`
2. Replace `has_local_script()` (lines 11-22) with `has_local_say_handler()` (~35 lines)
3. Update `is_eligible()` comment to reference the new check

### Stage 2: Research

All API calls verified against LUA-CODE.md and existing llm_bridge.lua:
- `debug.getregistry()` — standard LuaJIT debug library, returns Lua registry table
- `reg["npc_" .. npc_id]` — exact key format used by lua_parser.cpp (confirmed in architecture plan)
- `e.self:GetNPCTypeID()` — existing call already in `is_eligible()`; returns numeric NPC type ID
- `io.open` / `f:read("*a")` / `f:close()` — same pattern as original `has_local_script()`
- `eq.get_zone_short_name()` / `e.self:GetCleanName():gsub(" ", "_")` — same as original

Plan amendment: Added ID-based Perl path check (`npc_id .. ".pl"`) per Risk 5 in architecture plan.

### Stage 3: Socialize

No blocking dependencies. Team lead dispatch message served as alignment checkpoint.
Architecture plan is explicit and authoritative; no plan changes needed.

### Stage 4: Build

#### 2026-02-26 — Replaced has_local_script with has_local_say_handler

**What:** Replaced `has_local_script()` with `has_local_say_handler()` in llm_bridge.lua.
Added `_perl_say_cache` module table. Updated module header comment and is_eligible() comment.
**Where:** `akk-stack/server/quests/lua_modules/llm_bridge.lua`
**Why:** File-existence check blocked ~3,092 NPCs that only have combat/spawn/signal scripts
from receiving LLM speech. Function-existence check via Lua registry is precise and safe.
**Notes:**
- `debug.getregistry()["npc_" .. npc_id]` probes the same registry the C++ parser populates
- ID-based Perl path added per architecture plan Risk 5 (`48030.pl` pattern)
- `luac -p` syntax check: clean (no output = pass)
- Quest scripts directory is gitignored in akk-stack — file deployed on disk, not committed

---

## Context for Next Agent

Task 4 and 5 complete. The llm_bridge.lua module now exports:
- `build_context(e)` — unchanged behavior, now includes npc_deity field
- `build_quest_context(e, quest_hints, quest_state)` — new; wraps build_context and adds quest fields
- `generate_response(context, message)` — now sends npc_deity, quest_hints, quest_state to sidecar

Tier 2 pattern for any future quest script upgrades:
```lua
local llm_bridge = require("llm_bridge")
local quest_hints = {
    "Hint sentence 1.",
    "Hint sentence 2.",
    "Valid keywords: [keyword1], [keyword2].",
}
function event_say(e)
    -- ... keyword blocks ...
    -- LLM fallback (always last):
    llm_bridge.send_thinking_indicator(e)
    local context = llm_bridge.build_quest_context(e, quest_hints)
    local response = llm_bridge.generate_response(context, e.message)
    if response then e.self:Say(response) end
end
```
