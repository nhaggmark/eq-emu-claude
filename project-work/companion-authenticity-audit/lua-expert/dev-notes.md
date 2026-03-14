# Companion Authenticity Audit — Dev Notes: Lua Expert

> **Feature branch:** `feature/companion-authenticity-audit`
> **Agent:** lua-expert
> **Task(s):** Task #2 — Lua audit: companion behavior scripts, stat scaling, equipment effects, stance logic
> **Date started:** 2026-03-14
> **Current stage:** Complete

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 2 | Lua audit: companion behavior scripts, stat scaling, equipment effects, stance logic | None | Complete |

---

## Audit Findings

This document is the complete Lua-layer audit of the companion system. All findings
are sourced from direct reading of the following files:

**Files Examined:**

| File | Lines | What Found |
|------|-------|------------|
| `akk-stack/server/quests/lua_modules/companion.lua` | ~1473 | Core recruitment, command dispatch, all ! commands |
| `akk-stack/server/quests/lua_modules/companion_culture.lua` | ~622 | LLM identity/personality system |
| `akk-stack/server/quests/lua_modules/companion_context.lua` | ~285 | LLM context builder |
| `akk-stack/server/quests/lua_modules/companion_commentary.lua` | ~170 | Unprompted NPC commentary |
| `akk-stack/server/quests/lua_modules/client_ext.lua` | ~337 | Client class extensions (GetFaction nil-guard) |
| `akk-stack/server/quests/global/global_npc.lua` | ~659 | Trade handler, buff queue, timers, death tracking |

---

## 1. Stat Scaling System

### Current Companion Behavior

There is **no stat scaling implemented in Lua**. The Lua layer has zero involvement in
computing or modifying companion stats (STR, STA, AGI, DEX, WIS, INT, CHA, HP, mana, AC).

Lua only *reads* these values for display:
- `companion.cmd_stats()` (`companion.lua:802-830`) calls `npc:GetSTR()`, `npc:GetSTA()`,
  `npc:GetAGI()`, `npc:GetDEX()`, `npc:GetINT()`, `npc:GetWIS()`, `npc:GetCHA()`,
  `npc:GetAC()`, `npc:GetATK()`, `npc:GetMR()`, `npc:GetFR()`, `npc:GetCR()`,
  `npc:GetPR()`, `npc:GetDR()`, `npc:GetMinDMG()`, `npc:GetMaxDMG()` for the `!stats` display.
- `companion.cmd_status()` (`companion.lua:701-796`) reads HP/mana for the `!status` display.

Stat formulas (what a companion's base stats are at each level, how stats scale on level-up,
what class-specific stat priorities apply) are **entirely in C++** (`Companion::LevelUp()`) and
**the database** (`companion_stat_scaling` table, if it exists). The Lua layer is a passive reader.

### Gap Assessment: NOT APPLICABLE (Lua layer)

Stat scaling is not a Lua concern. See c-expert audit for C++ formula analysis.
The only Lua-observable gap: the `!stats` command exposes all stats to the player in raw form,
which is a useful debugging tool. No authenticity gap in the Lua layer itself.

---

## 2. Equipment System

### Current Companion Behavior

Equipment is handled in two places in Lua:

**Trade window handling** (`global_npc.lua:162-319` — `event_trade`):
- Only fires for companions (`npc:IsCompanion()` guard at line 165)
- Ownership check: only the companion's owner can trade items (`GetOwnerCharacterID()` vs `CharacterID()`)
- Returns all money (companions cannot hold coins, lines 187-205)
- For each item in the trade window (up to 4 slots):
  - Calls `item_data:Slots()` to get the equip slots bitmask
  - `companion_find_slot()` (`global_npc.lua:142-160`) picks the best slot:
    - Pass 1: find the first *empty* matching slot (prefer empty over occupied)
    - Pass 2: fall back to first matching slot (displaces existing item)
  - Class/race restriction check via `Companions:EnforceClassRestrictions` and
    `Companions:EnforceRaceRestrictions` rules — calls `inst:IsEquipable(check_race, comp_class)`
  - NPC model race mapping (`NPC_RACE_TO_PLAYER_RACE` table, lines 112-124): maps citizen/guard
    NPC race IDs (44, 55, 67, 71, 77, 78, 81, 90, 92, 93, 94) to their player race equivalents
    so `IsEquipable()` gets a valid race ID (NPC model races return 0 from `GetPlayerRaceBit()`)
  - For unmappable non-player races (raw_race > 16): uses race=1 (Human) to bypass race check,
    class check still applies
  - Returns displaced item to player via `GiveSlot()` before placing new item
  - Returns stackable item excess (companions only need 1 stack, returns charges-1)
  - pcall wrapper: any Lua error during item processing returns the item to the player safely
  - Safety comment at line 219: "After event_trade returns, C++ unconditionally safe_delete's
    all trade slot instances — if we haven't SummonItem'd a rejected item by then, it's gone."

**Equipment commands** (`companion.lua:660-698`):
- `!equipment` / `!gear`: calls `npc:ShowEquipment(client)` — C++ renders the equipment window
- `!equip`: display-only, instructs player to use trade window
- `!unequip <slot>` or `!unequip all`: calls `npc:GiveSlot(client, slot_name)` or `npc:GiveAll(client)`
- `!equipmentmissing`: iterates slots 0-22 (skip 21=PowerSource), reports empty slots
- `!equipmentupgrade`: parses an item link from message body, computes a stat score using
  `eq.get_item_stat()`, compares to currently equipped item in the relevant slot

**Item stat score formula** (`companion.lua:1267-1288`):
```
score = AC + STR + STA + AGI + DEX + WIS + INT + CHA + HP + mana
        + (if weapon: floor(damage * 10 / delay))
```
This is a simple additive score, not weighted by class role.

### Expected Authentic EQ Behavior

In authentic EQ:
- Items equip into specific slots based on the item's slot bitmask — this is correctly implemented
- Race/class restrictions apply — correctly implemented with the NPC-to-player-race mapping fix
- When a better weapon is equipped, damage increases — **depends on C++ picking up the new item data**
- AC from armor should stack — depends on C++ recalculating AC after equipment change
- Haste items: the `haste` effect from a haste item works through spell effects or item haste
  fields — whether this works on companions depends on C++ `Companion::CalcBonuses()` behavior
- Focus effects: only apply if C++ `Companion::SpellEffect()` reads focus data from equipped items
- Weapon procs: depend on C++ melee combat code reading proc spell IDs from equipped items

### Gap Assessment

**Lua equipment handling: MATCH** — the Lua trade and equip system is comprehensive. Items
are correctly slotted, ownership enforced, money returned, displaced items returned, class/race
restrictions checked with correct race mapping. The pcall safety wrapper prevents item loss.

**Stat effect of equipment (Lua-invisible):** Whether equipping a weapon actually improves
companion damage, or whether haste/focus/procs work, is entirely a C++ question. The Lua
layer correctly calls `GiveItem()` and `GiveSlot()` — what C++ does with that equipment
afterward is the gap to investigate.

**Item upgrade evaluation score:** The `!equipmentupgrade` command uses an unweighted additive
score that does not account for class-role priorities (e.g., a healer values WIS/mana more than
STR). This is a UX minor divergence, not a combat authenticity gap.

---

## 3. Stance / AI System

### Current Companion Behavior

Three stances are implemented via `companion:SetStance(int)` C++ binding:
- `0` = Passive: disengage, do not attack
- `1` = Balanced (default): fight when attacked or when owner is attacked
- `2` = Aggressive: actively seek and attack enemies

**Lua stance commands** (`companion.lua:564-588`):
- `!passive`: calls `SetStance(0)`, then `WipeHateList()` (line 568)
- `!balanced`: calls `SetStance(1)`, different dialogue by companion_type (lines 573-581)
- `!aggressive`: calls `SetStance(2)` (line 585)

**Guard/follow mode** (`companion_modes` table, `companion.lua:43-43`):
- Module-level Lua table tracking per entity ID, keys are `npc:GetID()`, values `"follow"/"guard"`
- `!follow`: calls `SetGuardMode(false)`, sets mode to `"follow"`
- `!guard`: calls `SetGuardMode(true)`, sets mode to `"guard"`
- `!hold`: calls `SetGuardMode(true)` + `SetStance(0)` + `WipeHateList()` — guard + passive combined
- Mode is reset on quest reload (module-level table, not persisted)

**Combat engagement commands** (`companion.lua:1141-1216`):
- `!target`: sets companion's target to player's target, adds to hate list in non-passive stance
- `!assist`: wipes companion hate list, sets target to player's target, adds to hate list,
  auto-switches passive->balanced if passive, breaks guard mode

**Movement commands** with combat implications:
- `!tome`: GMMove to player, wipe hate list, set passive via SetStance(0), restore stance
  after 500ms via timer (`comp_tome_restore_<id>`) — this temporarily clears combat state
- `!flee`: set passive, GMMove to player — hate list intentionally NOT cleared (mobs continue pursuit)
- `!recall`: GMMove if distance > 200 units (RECALL_MIN_DISTANCE), 30s cooldown via data bucket

**Nil-guard pattern** used throughout: `npc.SetStance and npc:SetStance(0)` — this is because
`SetStance`, `GetStance`, `SetGuardMode`, `GetCompanionType`, `GetCombatRole`, `GetCompanionID`
are methods on `Lua_Companion` (C++ custom class). When luabind's inheritance resolution
fails (documented in memory: "Luabind Inheritance Issue"), these methods are nil on the
Lua_Companion object. The nil-guard prevents crashes.

### Expected Authentic EQ Behavior

In authentic EQ, pet stances work as follows:
- **Passive**: pet stops attacking, does not initiate combat
- **Balanced/Guard**: pet attacks things that attack the pet or the owner
- **Aggressive**: pet attacks anything in range

The companion system implements these three modes but uses custom Companion C++ logic rather
than the standard NPC AI. Whether the C++ stance handling matches pet-level authenticity is
a C++ question.

**`!hold` (guard + passive):** There is no exact EQ equivalent command — this is a custom
addition that combines guard position with passive stance. It is a good QoL design.

**`!tome` passive override + timer restore:** This is an engineering workaround for a
C++ AI tick race condition (BUG-022). The passive tick clears the target pointer before
the re-engage logic fires. This is invisible to the player but is a workaround for
an AI behavior gap.

### Gap Assessment

**Stance commands: MATCH** — three stances are implemented, correctly mapped to C++ API.
WipeHateList() is called appropriately on passive/hold.

**Guard/follow mode: MATCH** — the Lua companion_modes table tracks this correctly; SetGuardMode
is called on the C++ side.

**Nil-guard fragility (MINOR DIVERGENCE):** The pattern `npc.SetStance and npc:SetStance(0)`
means that if the luabind inheritance gap causes SetStance to be nil, the command silently
does nothing. The companion appears to acknowledge the command (via Say) but the stance
does not actually change. This is a known issue (memory note). The fix is in C++ (lua_companion.cpp).

**Recall distance enforcement (design choice):** The 200-unit minimum for `!recall` prevents
combat abuse. This has no EQ equivalent but is a deliberate design constraint.

---

## 4. Buff / Debuff System

### Current Companion Behavior

**Buff casting (companion-to-player/party)** is implemented via the timer-based buff queue
in `global_npc.lua:438-597` (`event_timer` handler for `buff_request_*` timers):

1. Player issues `!buffme` or `!buffs` command
2. Lua checks: companion is alive, has mana (max_mana > 0), mana ratio >= 10%
3. Sets entity variable `buff_request_target` = `"owner"` or `"party"`
4. Timer `buff_request_<entity_id>` fires after 2000ms
5. On timer: waits until companion is not engaged and not casting
6. Queries `companion_spell_sets` table: `WHERE class_id=? AND min_level<=? AND max_level>=?
   AND (spell_type & ?) > 0` with `BUFF_TYPE_MASK = 8 + 1048576` (SpellType_Buff |
   SpellType_PreCombatBuff)
7. Builds ordered queue of `{spell_id, target_id}` pairs (spell-major ordering)
8. Processes ONE entry per 2-second timer tick via `npc:CastSpell(spell_id, target_id, 7)`
9. Skips invalid/dead targets silently; re-arms timer after each cast
10. Queue exhausted: cleans up all entity variables
11. Retry cap: 30 retries * 2s = 60 seconds maximum wait before giving up

**Bug fix context (BUG-025):** The original code had a nested loop that only cast the first
spell because `CastSpell()` sets `casting_spell_id` on the first call and subsequent calls
in the same tick silently return false. The fix (implemented) was the two-phase queue
serialization above.

**Buff display** (`!status`): Calls `npc:GetBuffs()` and iterates the result, showing spell
name and tics remaining. `tics * 6 = seconds remaining` conversion is correct (EQ tick = 6s).

**Can companions receive buffs from the player?**
There is no Lua-side restriction on player-to-companion buffing. The player can target the
companion and cast spells normally. Whether C++ accepts these spells (spell target type
restrictions, buff slot restrictions) is a C++ question. No Lua code blocks incoming buffs.

**Debuffs:** No Lua-side handling. Companions can be debuffed the same as any NPC unless
C++ has specific restrictions.

**Automatic combat AI buffing:** The Lua layer has NO automatic combat casting logic.
Companions do NOT automatically cast offensive spells, heals, or buffs in combat via Lua.
All autonomous combat casting (if any) is in C++ `Companion::AI_SpellCast()`. The `!buffme`
and `!buffs` commands are the only Lua-triggered spell casting.

### Expected Authentic EQ Behavior

In authentic EQ:
- Caster classes (Cleric, Shaman, Druid, Wizard, Necromancer, Magician, Enchanter, Beastlord)
  autonomously cast spells appropriate to combat situation
- Pre-combat: healers cast group heals, casters buff the group
- In combat: nukers use best nuke for the situation, healers triage heal
- Buff durations on companions work the same as on players (ticks of 6 seconds)
- The `companion_spell_sets` table drives what spells a companion of class X at level Y can cast

### Gap Assessment

**Player-initiated buffing (MATCH):** `!buffme` and `!buffs` work correctly. The queue
serialization fix is in place. Spell selection from `companion_spell_sets` is correct.

**Autonomous combat casting (MAJOR DIVERGENCE — NOT Lua's fault):** Lua has zero autonomous
combat casting. Whether companions cast spells in combat depends entirely on C++
`Companion::AI_SpellCast()`. If that C++ function is not implemented or is a stub, companions
will never autonomously cast. This is the single largest authenticity gap the Lua layer
can flag — it cannot be fixed in Lua.

**Buff duration display (MATCH):** The `!status` buff display correctly converts tics to
minutes using the tics*6 formula.

**Mana gating (MATCH):** The 10% mana check before issuing `!buffme`/`!buffs` is sensible
and matches player-like behavior.

---

## 5. Spell Casting Behavior

### Current Companion Behavior

As noted in section 4, Lua-initiated spell casting is limited to the `!buffme`/`!buffs`
command chain. The specific mechanics:

**Spell selection:** From `companion_spell_sets` DB table, ordered by `priority ASC, id ASC`.
This is a curated spell list — not derived from the companion's memory book or class spell
list in real-time. The table must be populated by data-expert for each class/level range.

**Cast invocation:** `npc:CastSpell(spell_id, target_id, 7)` — slot 7 is described as
"misc spell slot." This is a Lua call to the C++ `Mob::CastSpell()`. The C++ engine then
handles the actual spell casting mechanics (cast time, fizzle chance, interruption, etc.).

**Spell cooldowns (Lua side):** Lua does not track individual spell cooldowns. The 2-second
timer between queue entries provides a natural minimum interval. True spell recast timers
are handled by C++ (spell recast delay).

**No autonomous nuke/heal/debuff casting:** Lua does not implement AI decision-making for
combat spells. The `event_say`, `event_timer`, and `event_trade` handlers in `global_npc.lua`
cover the three cases Lua handles (conversation, buff queue, equipment). There is no
`event_damage_taken` or `event_combat` handler that would trigger autonomous spell casting.

**Focus effects:** Lua does not check or apply focus effects. These are C++ engine functions.
Whether companion-equipped focus items affect their spells is entirely a C++ question.

### Gap Assessment

**Command-triggered buffing (MATCH):** Correct spell selection and sequential casting.

**Autonomous caster AI (MAJOR DIVERGENCE):** A real EQ Wizard companion should nuke.
A real EQ Cleric companion should heal group members in combat. A real EQ Enchanter companion
should mez adds and buff the group. None of this happens via Lua. Whether C++ fills this gap
is the key question for the c-expert audit.

**Focus effects on companion spells (UNKNOWN — C++ territory):** Lua cannot determine this.
The Lua layer calls `CastSpell()` correctly; whether C++ applies focus effects from equipped
items depends on `Companion::SpellEffect()` or equivalent.

---

## 6. Death and Recovery

### Current Companion Behavior

**On companion death (Lua side):**
- `global_npc.lua:event_death_zone()` tracks zone-wide kills but explicitly skips companions:
  `if e.self:IsCompanion() then return end` (line 607)
- No `event_death` handler exists in `global_npc.lua` for companions. Death handling is
  in C++ (`Companion::Death()` hook).
- `companion.lua:1454-1470` — `trigger_soul_wipe()`: clears ChromaDB memories via curl POST
  to `http://npc-llm:8100/v1/memory/clear`. Called from C++ `Companion::Death()` for permanent
  death. Uses `io.popen(cmd)` for synchronous curl execution.

**Post-death state:** C++ handles is_suspended flag, DeathDespawnS timer, XP loss on death.
Lua only handles:
1. The soul wipe (ChromaDB memory clear) on permanent death
2. Dead checks in command handlers (`GetHP() <= 0` guards throughout companion.lua)

**Equipment on death (BUG-012 already fixed):** Per status.md reference, equipment persistence
through death was a previous bug that has been fixed. Equipment is persisted via the C++ layer.

**Buff stripping on death:** Not handled in Lua. In authentic EQ, death strips most buffs.
Whether this happens on companions depends on C++ — when a companion dies and then is
resurrected, whether it retains buffs is a C++ question.

**Re-recruitment after death:**
- `companion.check_existing_companion_record()` (`companion.lua:390-402`) queries for
  `is_dismissed=1 OR is_suspended=1` — `is_suspended=1` is the dead companion state
- Re-recruitment track bypasses cooldown, level range, faction, persuasion — minimal
  safety checks only (combat, capacity, enabled)
- C++ `CreateFromNPC()` detects the suspended record and calls `Load()` + `Unsuspend()` transparently

### Gap Assessment

**Soul wipe (MATCH):** ChromaDB memory clearing on permanent death is implemented correctly.
The synchronous `io.popen(curl)` is slightly fragile (blocks the Lua thread briefly) but
functional.

**Dead companion command guards (MATCH):** All action commands (`!buffme`, `!assist`, `!follow`,
`!flee`, `!tome`) have dead-companion guards that return appropriate messages.

**Buff stripping on death (UNKNOWN — C++ territory):** Lua does not and cannot control this.

**XP loss on death (UNKNOWN — C++ territory):** Lua does not implement XP loss on death.
Whether companions lose XP like players (at level-appropriate rates) is a C++ question.

**Re-recruitment flow (MATCH):** The two-track recruitment system (fresh vs. re-recruit)
is correctly implemented. Dead companions use the same re-recruitment path as dismissed ones.

---

## 7. Group Integration

### Current Companion Behavior

**Group XP splitting:** No Lua involvement. C++ handles XP distribution. Whether companions
count as group members for XP splitting purposes depends on C++ group XP code.

**Group buff targeting (`!buffs`)** (`global_npc.lua:499-516`):
- Iterates `group:GetMember(i)` for i=0..5
- Targets all valid living group members (including companion NPC members)
- Spell-major ordering: spell 1 cast on all targets, then spell 2, etc.

**Group chat delivery** (`companion_say()` helper, `companion.lua:555-562`):
- All companion command responses go through `companion_say()` which calls
  `group:GroupMessage(npc, msg)` if the owner has a group, falls back to `npc:Say()` if not
- This means companion responses appear in group chat channel (not say channel) when grouped

**`@all` group dispatch** (in `global_npc.lua:event_say()`):
- When a gsay (group say) message is sent to all companions (`@all`), each companion
  gets an entity variable `gsay_response_channel = "group"` and optional stagger delay
  `gsay_stagger_ms` set by C++ (so companions don't all respond simultaneously)
- Responses are delivered via `group:GroupMessage(npc, msg)` after the stagger delay

**Group composition for LLM context** (`companion_context.lua:146-169`):
- `get_group_composition()` iterates group members and captures name, race, class, level,
  `is_companion` flag for each member
- This feeds the LLM context so companions are aware of party composition

**Player `GetGroupMemberCount()`** (`client_ext.lua:282-292`):
- Handles both group and raid contexts
- Returns 0 if client has no group

### Gap Assessment

**Group buff targeting (MATCH):** Correctly targets all group members including other companions.

**Group chat routing (MATCH):** All companion dialogue goes to group channel when grouped,
matching how a real player in your group would talk.

**`@all` stagger (MATCH):** Multiple companions don't all speak at once; C++ sets stagger delays
and Lua delivers them via timers.

**XP splitting (UNKNOWN — C++ territory):** Whether companions count for group XP splits
is a C++ question. The EQ standard is that each member in the group reduces XP per kill.

**Group buffs on companions (UNKNOWN):** Whether standard group spells (e.g., Group Heal,
Aegolism) hit companion NPC entities is a C++ targeting question (target type restrictions
on group spells).

---

## 8. Level-Up System

### Current Companion Behavior

**XP display** (`companion.lua:746-747`):
```lua
local current_xp    = npc:GetCompanionXP()
local next_level_xp = npc:GetXPForNextLevel()
```
Both are C++ bindings on `Lua_Companion`. The `!status` command shows `XP: N / M` where
N is current XP and M is XP needed for next level.

**Level-up event handling:** There is no `event_level_up` handler in `global_npc.lua` for
companions. The `companion_culture.lua` defines a `"level_up"` event type for LLM dialogue
context (line 458-469), implying the C++ layer fires some event or callback that triggers
a level-up LLM response. However, the Lua event handler for this is not visible in the
files examined — it may be in a C++ → Lua callback registered elsewhere, or it may be
incomplete.

**What changes on level-up (Lua perspective):**
- The Lua layer has no visibility into what stat changes happen on level-up
- `!stats` will show updated stats after a level-up (reads current values from C++)
- `companion_spell_sets` queries use `min_level <= ? AND max_level >= ?` with current level,
  so buffing commands automatically pick up spells for the new level after leveling

**Evolution tier** (`companion_culture.lua:57-66`):
- 0=early (0-10h), 1=mid (10-50h), 2=late (50h+) — based on `time_active_seconds`
- This drives LLM dialogue personality, not game mechanics

### Gap Assessment

**XP tracking (MATCH for display):** `GetCompanionXP()` and `GetXPForNextLevel()` are
correctly read and displayed.

**Level-up event handling (INCOMPLETE):** The `companion_culture.lua` defines a `"level_up"`
event type suggesting a level-up LLM response is intended. But no `event_level_up` NPC
handler is visible in `global_npc.lua`. If C++ fires an NPC event on companion level-up,
there is no Lua handler to receive it. The LLM response for level-up may be unimplemented.

**Post-level stat uptake (UNKNOWN — C++ territory):** Whether companions get stat increases
on level-up, whether they gain new spell slots, whether HP/mana scales appropriately —
all C++ questions.

**Spell list update on level-up (MATCH — by design):** The `companion_spell_sets` query
is level-gated so `!buffs` automatically picks the correct spell tier for the new level.
No Lua update needed on level-up.

---

## 9. Recruitment Roll System

### Current Companion Behavior

**Base chance:** `Companions:BaseRecruitChance` rule (default 50%)

**Modifiers applied** (`companion.lua:492-501`):
1. Faction bonus: Ally=+30%, Warmly=+20%, Kindly=+10% (from `FACTION_BONUS` table)
2. Disposition modifier: Eager=+25%, Restless=+15%, Curious=+5%, Content=-10%, Rooted=-30%
   (read from NPC entity variable `companion_disposition`)
3. Persuasion bonus: from `companion_culture_persuasion` DB table, primary stat + secondary
   source. Default: `(CHA - 75) / 5`
4. Level penalty: `abs(player_level - npc_level) * 5` per level difference

**Roll clamp:** 5% minimum, 95% maximum

**Cooldown on failure:** `Companions:RecruitCooldownS` rule (default 900s = 15min) via
data bucket with TTL

**Re-recruitment bonus:** +10% (`REREC_BONUS`) — but looking at the code (`companion.lua:453-474`),
the re-recruitment track does NOT actually apply this bonus. The constant `REREC_BONUS = 10`
is defined (line 74) but the re-recruitment track bypasses the persuasion roll entirely
(eligible → success, no roll). The bonus exists as a constant but is never used in the
current implementation. This may be intended behavior (re-recruitment always succeeds
for previously dismissed companions) or may be a discarded design.

### Gap Assessment

**Roll system (MATCH for first-time):** The four-modifier recruitment roll is a coherent
design that rewards good faction, NPC disposition, charisma, and appropriate level.

**Re-recruitment bonus (MINOR DIVERGENCE — design question):** `REREC_BONUS = 10` is
defined but never applied. Re-recruitment is unconditional (always succeeds given minimal
checks). The `!dismiss` help text says "re-recruit later with +10% bonus" which is incorrect
per current code. The bonus is effectively infinite (guaranteed success). This should be
flagged for game-designer review.

---

## 10. Companion Type System (Loyal vs. Mercenary)

### Current Companion Behavior

Two companion types are tracked:
- `0` = Companion (loyal) — genuine choice, loyalty, warmth
- `1` = Mercenary — transactional, professional, cold

Type is read via `npc:GetCompanionType()` (C++ binding, nil-guarded throughout).
Type affects:
- `!balanced` response dialogue (loyal: "I will fight at your side." vs. mercenary: "Understood.")
- LLM system prompt framing (`companion_culture.get_type_framing()`)
- Evolution context framing (loyal grows personally, mercenary grows professionally)
- All LLM event dialogues (recruitment, dismiss, level-up, equipment receive, etc.)

The companion type is set during `CreateCompanion()` in C++ (based on NPC entity data or
faction/class heuristics — unclear from Lua alone). There is no Lua code that sets
`companion_type` — it is set by C++ and read by Lua.

### Gap Assessment

**Type differentiation (MATCH):** The two-type system is well implemented in Lua. Dialogue
and framing differ appropriately between loyal and mercenary types.

**Type assignment (UNKNOWN — C++ territory):** How C++ determines which type to assign
a given NPC on recruitment is not visible in Lua. Whether all NPCs can be either type,
or whether type is derived from class/race/faction, is a C++ question.

---

## 11. Faction System Integration

### Current Companion Behavior

**Faction for LLM dialogue** (`llm_faction.lua` module, referenced in `global_npc.lua`):
- `GetFaction()` method added to Client class in `client_ext.lua:64-75`
- Has a nil-guard for companion objects: `if npc.IsCompanion and npc:IsCompanion() then npc_arg = npc:CastToNPC() end`
- This works around the luabind inheritance gap: `GetFactionLevel` expects `Lua_NPC` as last arg;
  `CastToNPC()` produces the correct wrapper type

**Faction-based recruitment** (`companion.lua:346-352`):
- `get_faction_bonus()` reads `GetCharacterFactionLevel(npc_faction_id)`
- Faction level 1-5 (1=Ally, 5=Scowling) drives the bonus table

**Faction events (mercenary only):**
- `companion_culture.lua` defines "faction_warning" and "faction_departure" event types
  (lines 506-523) for LLM dialogue context
- These events are triggered from C++ when mercenary faction drops, not from Lua

### Gap Assessment

**Faction nil-guard (MATCH):** The `CastToNPC()` workaround is correctly implemented and
prevents `GetFactionLevel` crashes on companion objects.

**Faction-based mercenary behavior (UNKNOWN — C++ territory):** Whether C++ actually fires
faction_warning/faction_departure events or auto-dismisses mercenaries based on faction is
a C++ question.

---

## 12. Commentary System

### Current Companion Behavior

Companions make unprompted remarks via `companion_commentary.lua`:
- Timer `comp_commentary_<entity_id>` fires every `companion_commentary_min_interval_s` (default 600s=10min)
- Conditions to speak: alive, not in combat (if `companion_commentary_combat_block` set),
  grace period elapsed (default 120s=2min), hard cap elapsed (default 900s=15min),
  and at least one context change detected
- Context changes: zone change, named NPC killed, extended idle (20min without comment)
- 25% random probability gate after all conditions pass
- Response delivered via `npc:Say(response)` (not group chat — may be a minor inconsistency
  since other companion dialogue uses `companion_say()` which routes to group chat)

**Kill tracking** (`global_npc.lua:603-658` — `event_death_zone`):
- Fires for every NPC death in the zone
- Skips companions, pets, unnamed targets
- Updates all companions' `comp_recent_kills` entity variable (last 5, comma-separated)
- Flags `comp_named_kill = "1"` for named NPCs (those without "a "/"an " prefix)

### Gap Assessment

**Commentary system (MATCH for intent):** The zone-event integration for kill tracking is
solid. The context change detection covers the main triggers a companion would realistically
comment on.

**Commentary channel routing (MINOR DIVERGENCE):** Unprompted commentary uses `npc:Say()`
(public say channel) rather than `companion_say()` (group chat channel). All interactive
command responses go to group chat. Unprompted remarks going to public say is inconsistent
and would be visible to non-group members.

---

## Summary: Gap Table

| System | Lua Coverage | Gap Assessment | Location of Fix |
|--------|-------------|----------------|-----------------|
| Stat scaling | Display only (reads C++ values) | NOT LUA CONCERN | C++ / DB |
| Equipment handling | Full (trade, slot, restrictions) | MATCH | — |
| Equipment stat effects | None (C++ handles) | UNKNOWN | C++ audit needed |
| Stance commands | Full (3 stances + guard/follow) | MATCH (nil-guard fragility is minor) | C++ lua_companion.cpp |
| Combat AI (spells) | None | MAJOR DIVERGENCE | C++ AI_SpellCast |
| Autonomous healing | None | MAJOR DIVERGENCE | C++ AI_SpellCast |
| Buff commands | Full (queue, sequencing, DB lookup) | MATCH | — |
| Buff duration display | Correct | MATCH | — |
| Death handling | Soul wipe only | C++ handles the rest | C++ audit |
| XP loss on death | None (C++ territory) | UNKNOWN | C++ audit |
| Group buff targeting | Full (spell-major, all members) | MATCH | — |
| Group chat routing | Correct | MATCH | — |
| Commentary channel | `npc:Say()` not `group:GroupMessage()` | MINOR DIVERGENCE | companion_commentary.lua |
| Level-up event | Not implemented in Lua | INCOMPLETE | global_npc.lua (add handler) |
| Re-recruitment bonus | Constant defined, never applied | MINOR DIVERGENCE | companion.lua or design decision |
| Faction nil-guard | Workaround in place | MATCH | — |

---

## Critical Findings for Architect

**Finding 1 — MAJOR: Autonomous spell casting gap**
The Lua layer has zero combat AI. Companions do NOT automatically cast spells in combat
(nukes, heals, debuffs, CC). The `!buffme`/`!buffs` commands are the only spell triggers.
All autonomous combat casting must exist in C++ `Companion::AI_SpellCast()` or it doesn't
happen at all. This is the single largest authenticity gap visible from the Lua layer.

**Finding 2 — MINOR: Level-up LLM dialogue incomplete**
`companion_culture.lua` defines a `"level_up"` event type, but there is no `event_level_up`
NPC handler in `global_npc.lua`. If C++ fires an NPC event on companion level-up, Lua won't
handle it. The level-up LLM response appears to be unimplemented.

**Finding 3 — DESIGN QUESTION: Re-recruitment bonus**
`REREC_BONUS = 10` is defined in `companion.lua:74` but never applied. The `!dismiss` help
text advertises "+10% bonus" but re-recruitment is unconditional (always succeeds). Either
the bonus should be applied to the roll, or the help text should be updated.

**Finding 4 — MINOR: Commentary channel inconsistency**
Unprompted companion commentary goes to `npc:Say()` (public say channel, visible to all).
All command responses go to `group:GroupMessage()` (group chat only). This inconsistency
means unprompted remarks are visible to non-group members and break the group-private
interaction model.

**Finding 5 — CONFIRMED: Nil-guard fragility**
All `Lua_Companion`-specific methods (SetStance, GetStance, SetGuardMode, GetCompanionType,
GetCombatRole, GetCompanionID) use nil-guards because luabind doesn't resolve inherited
methods at runtime for the Companion class. When nil-guarded, commands silently succeed
(NPC says "I will stand down.") but the actual stance change doesn't occur. This is a C++
fix (lua_companion.cpp needs explicit method bindings for all companion-specific methods).

---

## Files Referenced

- `/mnt/d/Dev/eq/akk-stack/server/quests/lua_modules/companion.lua` — primary audit target
- `/mnt/d/Dev/eq/akk-stack/server/quests/lua_modules/companion_culture.lua` — LLM personality
- `/mnt/d/Dev/eq/akk-stack/server/quests/lua_modules/companion_context.lua` — LLM context
- `/mnt/d/Dev/eq/akk-stack/server/quests/lua_modules/companion_commentary.lua` — commentary
- `/mnt/d/Dev/eq/akk-stack/server/quests/lua_modules/client_ext.lua` — GetFaction nil-guard
- `/mnt/d/Dev/eq/akk-stack/server/quests/global/global_npc.lua` — trade handler, buff queue, timers
