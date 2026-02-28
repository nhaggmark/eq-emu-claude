# NPC Recruitment — User Story Feasibility Review

> **Author:** architect-reviewer (preliminary findings from code research)
> **Date:** 2026-02-27
> **Status:** Draft — awaiting game-designer user stories for full review
> **Architecture baseline:** `architect/architecture.md` (18 tasks, Companion : public NPC)

---

## Preliminary Code Research Findings

These findings are from direct examination of the EQEmu C++ source code, prior to the
game-designer's user stories being completed. They address the user's key questions about
leveling, equipment, and long-term companion persistence.

---

## 1. Companion Leveling

### User Question
"What happens as I level up? Do my recruited NPCs level up as well?"

### Current Architecture
The current PRD and architecture explicitly mark companion leveling as a **non-goal**:
- "No companion leveling (PRD: recruits stay at their database level)"
- Companions derive stats from `npc_types` — the NPC's fixed database entry

### Code Research

**NPC::SetLevel() — `zone/npc.cpp`:**
- Exists but is minimal — only changes the display level and triggers appearance update
- Does NOT recalculate stats (STR, STA, DEX, AGI, INT, WIS, CHA)
- Does NOT recalculate HP, mana, or endurance pools
- Does NOT update skills, attack speed, or combat abilities
- Does NOT refresh spell lists

**Bot::SetLevel() — `zone/bot.cpp`:**
- Also very minimal
- Bot leveling is handled differently — bots are player-created with character_data-style persistence
- Bot stat calculation uses a different formula path than NPCs

**Group::SplitExp() — `zone/exp.cpp` (line ~1169):**
- Only awards XP to group members where `m->IsClient()` returns true
- NPCs, bots, and mercs in the group count toward the member count (affecting the XP divisor)
- They NEVER receive XP themselves
- Any companion leveling system would need a custom XP tracking mechanism

### Feasibility Assessment

**Technically possible but requires significant new code:**

1. **XP accumulation** — New field in `companion_data` table (e.g., `experience BIGINT`).
   Hook into `Group::SplitExp()` to award a fraction of XP to companions. New method:
   `Companion::AddExperience(uint64 xp)` that checks for level-up thresholds.

2. **Stat recalculation on level-up** — This is the hard part. Options:
   - **Option A: Scale from npc_types base stats.** Store the companion's "recruited level"
     and current level. Apply a scaling formula: `stat = base_stat * (current_level / recruited_level)`.
     Simple, predictable, but may produce odd results at extreme level gaps.
   - **Option B: Use player stat formulas.** Apply the same stat progression tables that
     player characters use (from `base_data` table). This produces authentic EQ stat curves
     but requires mapping NPC race/class to player race/class stat tables.
   - **Option C: Use bot stat formulas.** Bots already calculate stats for all 16 classes.
     Adapt `Bot::CalcBotStats()` for companions. Most complex but most accurate.
   - **Recommended: Option A (scaling)** for simplicity. The companion's base stats from
     npc_types are already balanced for their original level. Scaling preserves relative
     strengths while allowing level growth.

3. **Spell list updates on level-up** — `companion_spell_sets` is already level-ranged
   (min_level/max_level columns). `LoadCompanionSpells()` just needs to be called again
   after a level change, filtering by the new level.

4. **HP/Mana recalculation** — New `Companion::RecalculateStats()` method that recomputes
   max_hp, max_mana, max_endurance based on the scaled stats and new level.

**Estimated additional scope:** ~400 lines C++, 2-3 new DB columns, 1 new task.

### Risks
- Level 10 NPC scaled to level 50 may have odd stat distributions
- Need to handle the case where companion out-levels available spell data
- XP split with companions changes the leveling pace for the player

---

## 2. Equipment / Outfitting Companions

### User Question
"How are they outfitted? I want to be able to gear out my NPC."

### Current Architecture
The current PRD explicitly marks equipment as a **non-goal**:
- "Recruits use the stats and equipment of their original NPC definition"
- "Players cannot trade gear to recruits or customize their loadouts"
- Architecture uses NPCType struct directly — no equipment slots

### Code Research

**Bot Equipment System — `zone/bot.h`, `zone/bot.cpp`:**
- Bots have a FULL equipment system that is the closest precedent
- `bot_inventories` table stores equipped items per bot
- `Bot::PerformTradeWithClient()` handles the trade window interaction
- `Bot::BotTradeAddItem()` validates item-to-slot assignment
- `Bot::FinishTrade()` finalizes the trade, updates DB, recalculates stats
- Equipment affects bot appearance (visible armor models), stats, and combat
- ~300+ lines of code per equipment operation
- Bot equipment slots mirror player slots (EQ::invslot::EQUIPMENT_BEGIN to EQUIPMENT_END)

**NPC Equipment — `zone/npc.h`:**
- NPCs have `equipment[]` array in NPCType struct (used for appearance only in npc_types)
- `NPC::AddLootDrop()` / `NPC::AddItem()` can add items to NPC inventory
- NPCs can USE items in some contexts but don't have the same slot-based equip system as bots
- NPC appearance (visible armor) is controlled by `npc_types.d_melee_texture1/2`,
  `npc_types.armortint_*`, etc. — NOT by equipped items

**Trade Window — `zone/trading.cpp`:**
- `Client::FinishTrade(NPC*)` already exists for NPC trade interactions (quest hand-ins)
- This is the standard mechanism: player opens trade, puts items in, clicks "Trade"
- The server-side handler receives the items and can process them
- This can be intercepted for companion equipment

**FillSpawnStruct — appearance packets:**
- When an NPC spawns, `FillSpawnStruct()` sends appearance data to the client
- Equipment appearance is sent as part of the spawn struct (equipment textures, tints)
- Changing equipment on a live NPC requires sending an `OP_WearChange` packet
- Bot does this: `Bot::SendWearChange()` updates the client's rendering of equipped items

### Feasibility Assessment

**Technically feasible — Bot system provides a complete template:**

1. **Database** — New `companion_inventories` table (mirrors `bot_inventories`):
   ```sql
   CREATE TABLE companion_inventories (
     companion_id    INT UNSIGNED NOT NULL,
     slot_id         MEDIUMINT UNSIGNED NOT NULL,
     item_id         INT UNSIGNED NOT NULL,
     charges         SMALLINT NOT NULL DEFAULT 0,
     PRIMARY KEY (companion_id, slot_id)
   );
   ```

2. **Trade window integration** — Override `Companion::FinishTrade()` to intercept
   trade window interactions. When a player trades items to their own companion:
   - Validate item vs. slot (class/race restrictions from items table)
   - Store in `companion_inventories`
   - Update companion stats (AC, ATK, HP, etc. from item stats)
   - Send `OP_WearChange` for visual update
   - Return any replaced items to the player

3. **Stat contribution from gear** — New `Companion::CalcItemBonuses()` method that
   sums stat contributions from equipped items. Called during `RecalculateStats()`.

4. **Visual updates** — `Companion::SendWearChange()` sends appearance updates when
   gear changes. Adapted directly from `Bot::SendWearChange()`.

5. **Persistence** — Equipment saved/loaded with companion data during zone transitions
   and suspend/unsuspend. The `companion_inventories` table persists across sessions.

**Titanium client constraint:** The trade window is standard EQ UI — it works with any
NPC. The player targets their companion, clicks "Trade" (or presses the trade hotkey),
places items, and clicks "Give." No custom UI needed.

**Estimated additional scope:** ~600 lines C++, 1 new DB table, 2-3 new tasks.

### Risks
- Item duplication exploits (need careful handling of trade rollbacks)
- Class/race item restrictions for NPCs may not map cleanly to item tables
- Some NPC races may not render equipment visually (non-humanoid models)
- Need to handle companion dismissal — do equipped items return to player or persist?

---

## 3. Long-term Companion Persistence / Soul Development

### User Question
"If I decide to keep an NPC that I develop a soul relationship with the whole game, how does that work?"

### Current Architecture
- `companion_data` table tracks recruited companions with `is_suspended` flag
- Soul elements (Phase 3) provide static personality traits per npc_type_id
- ChromaDB stores conversation memory per npc_type_id + player_id
- Current design: "No companion persistence across dismissal (each recruitment is fresh)"

### Code Research

**ChromaDB Memory System — `npc-llm-sidecar/app/memory.py`:**
- Conversations stored in collections keyed by `npc_{npc_type_id}`
- Each memory document includes `player_id` in metadata
- Memory persists across sessions — if the same NPC is re-recruited, their conversation
  history with that player still exists in ChromaDB
- This is already long-term persistent by design

**Soul Element System — `npc-llm-sidecar/app/soul_elements.py`:**
- Static soul traits from `soul_elements.json` — these persist forever (they're config)
- The dream document describes EMERGENT soul development (NPCs developing personality
  through conversation) — this is a FUTURE feature, not yet implemented
- Currently: soul = static config data, not dynamic

**Companion Data Persistence — architecture plan:**
- `companion_data` table has `recruited_at` timestamp
- `is_suspended` flag for login/logout persistence
- No `dismissed_at` or `times_recruited` tracking

### Feasibility Assessment

**The foundation already supports long-term persistence. Key additions needed:**

1. **Companion memory continuity** — Already works! ChromaDB stores memories by
   `npc_{npc_type_id}`. If a companion zones, suspends, or even gets dismissed and
   re-recruited, their conversation history with the player persists in ChromaDB.
   No changes needed for basic memory persistence.

2. **Long-term companion tracking** — Add fields to `companion_data`:
   - `total_xp_earned BIGINT` — lifetime XP earned while in the party
   - `total_kills INT` — lifetime kills with this companion
   - `zones_visited TEXT` — JSON array of zone IDs visited together
   - `time_recruited INT` — total seconds spent as an active companion
   - `times_died INT` — death count
   These enable the LLM to reference shared history ("We've fought through
   Blackburrow, Permafrost, and the Hole together...")

3. **Emergent soul development** (FUTURE — the dream document's vision):
   - The LLM sidecar could extract "soul-defining moments" from conversations
   - Store these as persistent soul elements that compound over time
   - This is the dream document's core vision but is a separate feature
   - For now: static soul elements + conversation memory provide a good foundation

4. **Re-recruitment after dismissal** — If a companion is dismissed, should the
   relationship persist? Options:
   - **Option A: Full persistence.** Companion data stays in DB with `is_dismissed=1`.
     Re-recruiting the same NPC restores the full relationship (level, gear, memories).
     Feels most emotionally satisfying. Risk: database bloat from abandoned companions.
   - **Option B: Memory only.** Companion data is deleted on dismissal, but ChromaDB
     memories persist. Re-recruiting gives you the conversation history but resets
     level and gear. Middle ground.
   - **Option C: Clean slate.** Current design — each recruitment is fresh. Only
     ChromaDB memories persist (already the case).
   - **Recommended: Option A** for named NPCs the player has invested in. Add a
     `companion_data.is_dismissed` flag instead of deleting the row. Re-recruitment
     restores the full companion state.

5. **Death and soul loss** — Per the dream document, death erases the soul. For
   recruited companions:
   - Companion death triggers a resurrection timer (DeathDespawnS = 1800 seconds)
   - If resurrected within the timer: companion restored with full state
   - If NOT resurrected: companion auto-dismisses, soul is wiped (ChromaDB collection
     cleared for that NPC), personality resets. The NPC respawns at their original post
     as a stranger.
   - This creates the emotional weight the dream document describes

**Estimated additional scope:** ~200 lines C++, 5-6 new DB columns, 1 new task.
Emergent soul development is a separate future feature.

---

## 4. Summary: Impact on Current Architecture

### Stories That Fit Within Current Architecture (no changes)
- All recruitment flow stories
- Combat and party dynamics
- Basic zone persistence and suspend/unsuspend
- Cultural voice and dialogue
- Death mechanics (basic version)
- Replacement NPC spawning

### Stories Requiring Moderate Architecture Extensions
- **Companion leveling** — XP tracking, stat scaling, spell list refresh (~400 lines C++)
- **Long-term persistence** — Additional DB columns, re-recruitment logic (~200 lines C++)
- **Death/soul wipe integration** — ChromaDB clearing on permanent death (~100 lines Python)

### Stories Requiring Major New Systems
- **Equipment management** — Full gear system adapted from Bot (~600 lines C++, new DB table)
- **Emergent soul development** — LLM-driven personality extraction (future feature, not Phase 1)

### Technically Infeasible (with Titanium client)
- Custom companion management UI (no client-side changes possible)
- Companion-specific inventory window (must use standard trade window)
- Real-time companion stat display beyond group window HP/mana bars

---

## 5. Revised Task Estimate

Current architecture: 18 tasks
Additional tasks for expanded scope:

| # | New Task | Agent | Scope |
|---|----------|-------|-------|
| 19 | Add XP tracking + leveling system to Companion class | c-expert | Medium (~400 lines) |
| 20 | Create `companion_inventories` table + equipment persistence | data-expert | Small (~50 lines SQL) |
| 21 | Implement equipment system in Companion class (trade, equip, stats, visuals) | c-expert | Large (~600 lines) |
| 22 | Add long-term tracking fields to `companion_data` | data-expert | Small (~20 lines SQL) |
| 23 | Implement re-recruitment logic (restore dismissed companion) | c-expert | Medium (~200 lines) |
| 24 | Death/soul wipe — clear ChromaDB on permanent companion death | lua-expert | Small (~50 lines) |

**Revised total: 24 tasks** (6 additional)
**Additional C++ scope: ~1200 lines**
**Additional SQL scope: ~70 lines**

---

## 6. Open Questions for Game Designer

1. **Level scaling formula**: Linear scaling from base stats, or use player stat tables?
2. **Equipment on dismissal**: Do items return to player, or persist on the companion?
3. **Equipment class restrictions**: Use item table race/class flags, or custom companion rules?
4. **XP rate for companions**: Same as player split, or reduced (e.g., 50%)?
5. **Level cap for companions**: Can a level 10 recruit reach level 65? Or cap at original + N?
6. **Re-recruitment cost**: Is re-recruiting a dismissed companion free, or harder than first time?
