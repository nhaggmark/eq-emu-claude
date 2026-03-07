# companion-experience — Architecture & Implementation Plan

> **Feature branch:** `bugfix/companion-experience`
> **PRD:** `game-designer/prd.md`
> **Author:** architect
> **Date:** 2026-03-05
> **Status:** Approved

---

## Executive Summary

This plan addresses three interconnected objectives: (1) fix BUG-001 where companion killing blows yield no player XP by adding companion recognition to the kill credit resolution chain in `NPC::Death`, (2) wire up companion XP distribution by adding `AddExperience()` calls in `Group::SplitExp` using the existing `XPSharePct` rule, and (3) complete the companion leveling loop by fixing `CheckForLevelUp` to support cascading level-ups and enforce the level 60 hard cap. All changes are in C++ (`attack.cpp`, `exp.cpp`, `companion.cpp`) with a minor Lua binding addition (`lua_companion.cpp/h`) and a Lua script update for `!status`. No new database tables, opcodes, or client packets are required.

## Existing System Analysis

### Current State

**Kill credit resolution** (`eqemu/zone/attack.cpp:2614-2656`): When an NPC dies, `NPC::Death` determines who gets XP credit through a chain:
1. `give_exp = hate_list.GetDamageTopOnHateList(this)` — gets top damage dealer
2. If `give_exp` has truthy value, overwritten with `killer` (from `GetHateDamageTop`)
3. If `give_exp->HasOwner()` — resolves through pet/bot owner chain to the ultimate owner client
4. Temp pet resolution via `GetSwarmOwner()`
5. `give_exp_client = give_exp->CastToClient()` — final XP recipient

This chain recognizes pets (`IsPet()`, `HasOwner()`), bots (`IsBot()`), and swarm pets (`IsTempPet()`) but does NOT recognize companions. Companions use `GetCompanionOwner()` / `GetOwnerCharacterID()` instead of the `ownerid` field that `HasOwner()` checks, so `HasOwner()` returns false for companions.

**Loot fix (already done)**: The corpse creation code at lines 2800 and 2827-2832 already handles companions — `killer->IsCompanion()` is checked, and `killer` is resolved to the companion's owner. This exact pattern is what the XP path needs.

**Group XP split** (`eqemu/zone/exp.cpp:1123-1195`): `Group::SplitExp` iterates `members[]`, calculates per-member XP, and calls `client->AddEXP()` for each client member. At lines 1190-1194, it already calls `RecordKill()` on companion members for history tracking but does NOT call `AddExperience()` for companion XP distribution.

**Companion XP infrastructure** (`eqemu/zone/companion.cpp`):
- `AddExperience(uint32 xp)` — adds XP, calls `CheckForLevelUp()` once, notifies owner on level-up
- `CheckForLevelUp()` — caps at `player_level - MaxLevelOffset`, does one level-up per call
- `GetXPForNextLevel()` — returns `level * level * 1000`
- `ScaleStatsToLevel(uint8)` — proportional stat scaling from recruitment baseline
- `Save()` — persists `m_companion_xp` to `companion_data.experience`

**Companion Lua binding** (`eqemu/zone/lua_companion.cpp`): Exposes `GetCompanionXP()` and `AddExperience()` but NOT `GetXPForNextLevel()`.

**`!status` command** (`akk-stack/server/quests/lua_modules/companion.lua:553-569`): Shows level, HP, mana, stance, mode, type but NOT XP progress.

**Rules** (`eqemu/common/ruletypes.h:1191-1195`):
- `Companions::XPContribute` (bool, default true) — exists, not yet wired into SplitExp logic
- `Companions::XPSharePct` (int, default 50) — exists, not yet used
- `Companions::MaxLevelOffset` (int, default 1) — exists, used in `CheckForLevelUp()`

### Gap Analysis

| Gap | Current State | Required State |
|-----|---------------|----------------|
| **Kill credit for companions** | `give_exp` resolution ignores companions; `HasOwner()` returns false | Companions must resolve to owner client like pets/bots |
| **XP distribution to companions** | `Group::SplitExp` only calls `RecordKill()` on companions | Must also call `AddExperience()` with share governed by `XPSharePct` |
| **Solo kill XP with companion** | Solo path (lines 2749-2768) never reached when companion is `give_exp` | Solo path must work when companion kills; ungrouped companion kills should also grant companion XP |
| **Level 60 hard cap** | `CheckForLevelUp` caps at `player_level - offset` but no absolute ceiling | Must enforce `min(player_level - offset, 60)` |
| **Cascading level-ups** | `CheckForLevelUp` does one level per call | Must loop to handle accumulated XP at cap release |
| **HP/mana restore on level-up** | Not implemented | PRD requires full HP/mana restore on level-up |
| **`GetXPForNextLevel` Lua binding** | Not exposed | Needed for `!status` XP display |
| **`!status` XP display** | Shows level only | Must show "Level 29 (1,234 / 900,000 XP)" |

## Technical Approach

### Architecture Decision

This feature requires **C++ changes** as the primary layer. The kill credit bug is in the C++ death path (`attack.cpp`), and the XP distribution must be wired into the C++ group XP split (`exp.cpp`). No rules, config, SQL schema, or Lua-level workarounds can fix a missing branch in the C++ kill credit resolution chain.

A **small Lua binding addition** exposes `GetXPForNextLevel` so the `!status` command can display XP progress. The `!status` Lua script update is a minor change.

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| `eqemu/zone/attack.cpp` | C++ — kill credit fix | Root cause of BUG-001: companion not recognized in `give_exp` resolution chain. Must add companion → owner resolution alongside existing pet/bot resolution. |
| `eqemu/zone/exp.cpp` | C++ — XP distribution | `Group::SplitExp` must call `AddExperience()` on companion members. Also handle solo (ungrouped) companion XP in the solo kill path. |
| `eqemu/zone/companion.cpp` | C++ — leveling fixes | `CheckForLevelUp` needs level 60 hard cap, cascading level-ups (while loop), and HP/mana restore. |
| `eqemu/zone/lua_companion.h/cpp` | C++ — Lua binding | Expose `GetXPForNextLevel()` to Lua for `!status` display. |
| `akk-stack/server/quests/lua_modules/companion.lua` | Lua script | Update `cmd_status` to show XP progress using `GetCompanionXP()` and `GetXPForNextLevel()`. |

### Data Model

**No schema changes required.** The `companion_data` table already has:
- `experience` (BIGINT UNSIGNED / uint64) — accumulated XP
- `level` (TINYINT UNSIGNED / uint8) — current level
- `recruited_level` (TINYINT UNSIGNED / uint8) — level at recruitment time

The `Save()` and `Load()` methods already persist and restore these fields correctly.

### Code Changes

#### C++ Changes

##### 1. Kill Credit Resolution Fix — `eqemu/zone/attack.cpp`

**Location:** `NPC::Death()`, lines 2614-2656

**Root Cause:** When a companion is the top damage dealer, `give_exp` points to the Companion entity. The code checks `give_exp->HasOwner()` at line 2620, which returns `false` because Companions track ownership via `m_owner_char_id` / `GetCompanionOwner()` rather than the Mob `ownerid` field. Result: `give_exp_client` is never set, no XP/faction/tasks fire.

**Fix:** Add a companion-specific resolution block immediately after the pet/bot owner resolution (after line 2640), following the exact pattern used in the loot fix at lines 2827-2832:

```cpp
// After line 2640 (after pet/bot resolution, before temp pet check):
// Companion kills: resolve to owner client, matching the loot fix pattern
if (give_exp && give_exp->IsCompanion()) {
    Client* comp_owner = give_exp->CastToCompanion()->GetCompanionOwner();
    if (comp_owner) {
        give_exp = comp_owner;
    } else {
        give_exp = nullptr;
    }
}
```

This must be placed BEFORE the `give_exp->IsClient()` check at line 2654. Once `give_exp` resolves to the owner Client, all downstream code (XP distribution, faction hits, task credit, quest events) fires normally.

##### 2. Companion XP Distribution — `eqemu/zone/exp.cpp`

**Location:** `Group::SplitExp()`, lines 1186-1194

**Change:** After the existing `RecordKill` loop, add companion XP distribution using the `XPSharePct` rule. The companion's share is calculated from the same per-member XP the clients receive.

```cpp
// After the RecordKill loop (line 1194):
// Distribute XP to companion group members
if (RuleB(Companions, XPContribute)) {
    int xp_share_pct = RuleI(Companions, XPSharePct);
    if (xp_share_pct > 0) {
        for (const auto& m : members) {
            if (m && m->IsCompanion()) {
                // Calculate companion's share: same per-member amount, scaled by XPSharePct
                uint64 member_share = group_experience / member_count;
                uint32 companion_xp = static_cast<uint32>(member_share * xp_share_pct / 100);
                if (companion_xp > 0) {
                    // Check con level for the companion (gray = no XP)
                    uint8 comp_con = Mob::GetLevelCon(m->GetLevel(), other->GetLevel());
                    if (comp_con != ConsiderColor::Gray) {
                        m->CastToCompanion()->AddExperience(companion_xp);
                    }
                }
            }
        }
    }
}
```

**Solo (ungrouped) companion XP:** In the solo kill path at `NPC::Death` (attack.cpp line 2749-2768), after the client receives solo XP, add companion XP for the player's companion if present. This requires finding the player's active companion(s) from the entity list.

```cpp
// After the solo client->AddEXP call (line 2755):
// Solo companion XP: if the player has companions, give them XP too
if (RuleB(Companions, XPContribute)) {
    int xp_share_pct = RuleI(Companions, XPSharePct);
    auto& comp_list = entity_list.GetCompanionList();
    for (auto& [id, comp] : comp_list) {
        if (comp && comp->GetOwnerCharacterID() == give_exp_client->CharacterID()) {
            uint32 comp_xp = static_cast<uint32>(final_exp * xp_share_pct / 100);
            if (comp_xp > 0) {
                uint8 comp_con = Mob::GetLevelCon(comp->GetLevel(), GetLevel());
                if (comp_con != ConsiderColor::Gray) {
                    comp->AddExperience(comp_xp);
                }
            }
        }
    }
}
```

##### 3. Companion Leveling Fixes — `eqemu/zone/companion.cpp`

**3a. Level 60 hard cap in `CheckForLevelUp()`:**

After line 1461 (`max_level -= (uint8)offset;`), add:

```cpp
// Absolute hard cap: companions may never exceed level 60 (Classic-Luclin era ceiling)
if (max_level > 60) {
    max_level = 60;
}
```

**3b. Cascading level-ups in `AddExperience()`:**

Replace the single `CheckForLevelUp()` call with a while loop:

```cpp
void Companion::AddExperience(uint32 xp)
{
    m_companion_xp += xp;

    // Check for cascading level-ups (e.g., cap released after player levels)
    bool leveled = false;
    while (CheckForLevelUp()) {
        leveled = true;
    }

    if (leveled) {
        Client* owner = GetCompanionOwner();
        if (owner) {
            owner->Message(Chat::Yellow,
                "%s has grown stronger. They are now level %d.",
                GetCleanName(), GetLevel());
        }
    }
}
```

Also remove the existing level-up message from inside `CheckForLevelUp` to avoid duplicate messages during cascading level-ups:

```cpp
bool Companion::CheckForLevelUp()
{
    // ... existing logic unchanged ...
    // Level up!
    m_companion_xp -= xp_needed;
    uint8 new_level = current_level + 1;
    ScaleStatsToLevel(new_level);
    LoadCompanionSpells();

    // Restore HP and mana to full on level-up
    SetHP(GetMaxHP());
    SetMana(GetMaxMana());

    Save();
    LogInfo("Companion [{}] leveled up to [{}]", GetName(), new_level);
    return true;
}
```

##### 4. Lua Binding Addition — `eqemu/zone/lua_companion.h` and `lua_companion.cpp`

Add `GetXPForNextLevel()` to the Lua binding:

**lua_companion.h** — Add to class declaration:
```cpp
uint32 GetXPForNextLevel();
```

**lua_companion.cpp** — Add implementation:
```cpp
uint32 Lua_Companion::GetXPForNextLevel()
{
    Lua_Safe_Call_Int();
    return self->GetXPForNextLevel();
}
```

**lua_companion.cpp** — Add to registration block:
```cpp
.def("GetXPForNextLevel", &Lua_Companion::GetXPForNextLevel)
```

#### Lua/Script Changes

##### 5. `!status` XP Display — `akk-stack/server/quests/lua_modules/companion.lua`

Update `cmd_status` function (line 553-569) to include XP information:

```lua
function companion.cmd_status(npc, client, args)
    local stance_names = { [0] = "Passive", [1] = "Balanced", [2] = "Aggressive" }
    local type_names   = { [0] = "Companion", [1] = "Mercenary" }
    local mode = companion_modes[npc:GetID()] or "follow"
    mode = mode:sub(1, 1):upper() .. mode:sub(2)

    client:Message(15, "=== " .. npc:GetCleanName() .. " ===")
    client:Message(15, "  Level: " .. npc:GetLevel() ..
                       "  Class: " .. npc:GetClassName())
    client:Message(15, "  HP: " .. npc:GetHP() .. "/" .. npc:GetMaxHP() ..
                       "  Mana: " .. npc:GetMana() .. "/" .. npc:GetMaxMana())

    -- XP progress
    local current_xp = npc:GetCompanionXP()
    local next_level_xp = npc:GetXPForNextLevel()
    client:Message(15, "  XP: " .. current_xp .. " / " .. next_level_xp)

    client:Message(15, "  Stance: " ..
                       (stance_names[npc:GetStance()] or "Unknown") ..
                       "  Mode: " .. mode)
    client:Message(15, "  Type: " ..
                       (type_names[npc:GetCompanionType()] or "Unknown"))
end
```

#### Database Changes

None required. The `companion_data` table schema is complete.

#### Configuration Changes

No new rules needed. All three relevant rules already exist:
- `Companions::XPContribute` (bool, default true)
- `Companions::XPSharePct` (int, default 50)
- `Companions::MaxLevelOffset` (int, default 1)

The C++ code will clamp `XPSharePct` to `[0, 100]` range and `MaxLevelOffset` to `[0, 59]` range at point of use to handle misconfiguration defensively.

## Implementation Sequence

| # | Task | Agent | Depends On | Scope |
|---|------|-------|------------|-------|
| 1 | **Fix kill credit resolution for companions in `NPC::Death`** — Add companion → owner resolution in the `give_exp` chain (`attack.cpp:2614-2656`). Insert `IsCompanion()` check after pet/bot resolution, before `give_exp_client` assignment. This fixes BUG-001: XP, faction, tasks, and quest credit all fire correctly when a companion lands the killing blow. | c-expert | — | ~20 lines changed in `attack.cpp` |
| 2 | **Wire companion XP distribution in `Group::SplitExp`** — Add companion `AddExperience()` calls in `exp.cpp` after the existing `RecordKill` loop. Calculate companion share using `XPSharePct` rule. Check companion con level (gray = no XP). Also add solo companion XP in the ungrouped kill path in `attack.cpp`. Clamp `XPSharePct` to [0, 100]. | c-expert | 1 | ~40 lines in `exp.cpp`, ~15 lines in `attack.cpp` |
| 3 | **Fix `CheckForLevelUp` for cascading level-ups and level 60 hard cap** — Modify `companion.cpp`: (a) Add `max_level = min(max_level, 60)` in `CheckForLevelUp()`. (b) Change `AddExperience()` to call `CheckForLevelUp()` in a while loop. (c) Move level-up message from `CheckForLevelUp` to `AddExperience` to avoid duplicate messages. (d) Add HP/mana restore to full on level-up. (e) Clamp `MaxLevelOffset` to [0, 59]. | c-expert | 1 | ~25 lines changed in `companion.cpp` |
| 4 | **Add `GetXPForNextLevel` Lua binding** — Add declaration to `lua_companion.h`, implementation to `lua_companion.cpp`, and `.def()` registration. | c-expert | 3 | ~8 lines across 2 files |
| 5 | **Update `!status` command to show XP progress** — Modify `companion.lua` `cmd_status` to display current XP and XP needed for next level using `GetCompanionXP()` and `GetXPForNextLevel()`. | lua-expert | 4 | ~5 lines changed in `companion.lua` |

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `give_exp` resolution order matters — inserting companion check in wrong position could shadow pet/bot resolution | Low | High | Insert AFTER the pet/bot resolution block (after line 2640) and BEFORE the temp pet check (line 2642). The companion check is a new else-if branch that only fires when `give_exp->IsCompanion()`. Pets and bots are never companions (different entity types). |
| Cascading level-ups in `AddExperience()` while loop could be unbounded | Low | Medium | `CheckForLevelUp` always consumes XP (`m_companion_xp -= xp_needed`) and enforces a cap. With max level 60 and entry at level 1, at most 59 iterations. |
| `GetCompanionOwner()` returns nullptr if owner is offline/in different zone | Low | Low | The companion check explicitly handles nullptr by setting `give_exp = nullptr`. This is the same pattern as the existing pet resolution. A companion without an owner in-zone cannot be fighting. |

### Compatibility Risks

**No regression risk to existing systems:**
- Solo XP (no companion): The `give_exp` resolution chain only adds a new companion branch; the existing pet/bot/client branches are unchanged.
- Standard group XP (players only): The companion XP loop only iterates companion members (`IsCompanion()`). No clients are affected.
- Bot/merc XP: Bot and merc resolution uses `IsPet()` / `IsBot()` / `IsMerc()` checks, which are distinct from `IsCompanion()`. No overlap.
- Loot: The loot fix (already in place at lines 2800/2827-2832) is untouched.

**Regression test targets:**
1. Solo kill XP without companions — must be identical to before
2. Group kill XP without companions — must be identical to before
3. Bot/pet kill credit — must be identical to before
4. Companion kill credit (BUG-001 fix) — must now work correctly

### Performance Risks

**Negligible impact:**
- Kill credit resolution adds one `IsCompanion()` virtual method call per NPC death — O(1), no database queries.
- Companion XP distribution adds one `AddExperience()` call per companion per kill in the group loop — already iterating `members[]`.
- `Save()` on level-up writes one row to `companion_data` — happens once per level, not per kill.
- No new timers, no new per-tick processing.

## Review Passes

### Pass 1: Feasibility

**Can we build this?** Yes, with high confidence.

- The kill credit fix follows the exact pattern already implemented for loot (lines 2827-2832). The loot fix proves the approach works.
- `AddExperience()`, `CheckForLevelUp()`, `ScaleStatsToLevel()`, and `LoadCompanionSpells()` all exist and are tested (they just aren't called from the XP path).
- `companion_data` table already has `experience`, `level`, and `recruited_level` columns with working persistence.
- All three rules (`XPContribute`, `XPSharePct`, `MaxLevelOffset`) exist in `ruletypes.h`.
- The Lua binding infrastructure for companions is established (`lua_companion.h/cpp`).

**Hardest part:** Getting the `give_exp` resolution placement exactly right in `NPC::Death` — it must come after pet/bot resolution but before the temp pet check. The code is dense (lines 2614-2656) and insertion order matters.

### Pass 2: Simplicity

**Is this the simplest approach?** Yes. Alternatives considered and rejected:

1. **Setting `ownerid` on companions** so `HasOwner()` returns true naturally: Rejected because it would make companions behave like pets throughout the codebase (auto-despawn on owner death, follow mechanics, etc.), which would conflict with the companion lifecycle model.

2. **Using a Lua mod hook** (`GetExperienceForKill`): Rejected because the kill credit resolution happens BEFORE the XP calculation. The mod hook fires after `give_exp_client` is determined. If `give_exp_client` is nullptr (the bug), the hook never fires.

3. **Adding companion XP via a zone event or timer**: Rejected as over-engineered. The XP path already iterates group members in `SplitExp`.

**Can anything be deferred?** The `!status` XP display (task 5) is technically deferrable but trivial and highly desirable for player feedback. Include it.

### Pass 3: Antagonistic

**Edge cases and failure modes:**

1. **Companion kills mob while owner is dead:** `give_exp` resolves to the dead owner client. `AddEXP` has its own dead-player checks. Companion XP should still flow since `AddExperience` has no owner-alive requirement. **Safe.**

2. **Multiple companions, one kills:** The hate list resolves `give_exp` to the companion that dealt the most damage. The resolution maps this to the owner client. All companions in the group get their XP share via `SplitExp`. **Correct behavior.**

3. **Companion kills another companion's target:** Same as above — hate list determines credit, resolution goes to owner client. **No issue.**

4. **XPSharePct set to 0:** Companion receives 0 XP. The code checks `if (companion_xp > 0)` before calling `AddExperience`. **Safe, intentional tuning knob.**

5. **XPSharePct set to 100:** Companion receives its full share, no surplus returns to player. The player still gets their own share from `SplitExp`. **Balanced, not exploitable.**

6. **MaxLevelOffset set to 0:** Companion can match player level but not exceed it (and hard cap of 60 applies). **Safe.**

7. **Companion at level 59, player at 60, MaxLevelOffset 1:** Companion is at cap. XP accumulates but `CheckForLevelUp` returns false. When player reaches 61 (not possible on this server, but defensively): companion could level to 60 (capped by hard cap). **Correct.**

8. **Player zones while companion has pending level-up XP:** Companion is suspended, XP is saved via `Save()`. On unsuspend, `Load()` restores `m_companion_xp`. Next kill triggers `CheckForLevelUp`. **XP preserved.**

9. **Server crash mid-combat:** XP is only persisted on `Save()` calls (level-up, suspend, zone). In-progress XP since last save is lost. This is acceptable — same as player XP behavior. **Acceptable risk.**

10. **Race condition: companion kills mob at same instant as player:** `NPC::Death` is called once per NPC death. The hate list determines a single `give_exp`. No double-XP risk. **Thread-safe (single-threaded zone process).**

**Exploit vectors:**
- None identified. Companions are already subject to con-based XP scaling (gray = no XP). The `XPSharePct` rule means companion XP comes FROM the group split, not in addition to it. Having companions is a net-neutral or net-positive for player XP (surplus goes back to player), but companion XP is always a fraction of a group share.

### Pass 4: Integration

**Implementation order is critical:**

1. **Task 1 (kill credit fix) MUST come first.** Without it, `give_exp_client` is null when companions kill, so the group/solo XP paths never fire. Tasks 2-5 all depend on this.

2. **Tasks 2 and 3 can proceed in parallel** after task 1, but must both be in the same build. They are both c-expert tasks modifying different files (`exp.cpp`/`attack.cpp` vs `companion.cpp`).

3. **Task 4 (Lua binding) depends on task 3** because it exposes `GetXPForNextLevel()` which is defined in `companion.cpp`. If task 3 changes the method signature, task 4 must match.

4. **Task 5 (Lua script) depends on task 4** because it calls `GetXPForNextLevel()` which must be bound first.

**Build/test sequence:**
1. Apply tasks 1+2+3+4 (all C++) → build → test kill credit and XP distribution
2. Apply task 5 (Lua) → `#reloadquest` → test `!status` display

**Cross-file dependencies:**
- `attack.cpp` includes `companion.h` (already present for loot fix)
- `exp.cpp` includes `companion.h` (needs to be added for `CastToCompanion()`)
- `lua_companion.cpp` includes `companion.h` (already present)

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| **c-expert** | Tasks 1, 2, 3, 4 | All four tasks involve C++ source changes: kill credit resolution in attack.cpp, XP distribution in exp.cpp, leveling fixes in companion.cpp, and Lua binding in lua_companion.h/cpp |
| **lua-expert** | Task 5 | Update companion.lua `cmd_status` to display XP progress using newly-bound methods |

## Validation Plan

The game-tester should verify the following after implementation:

- [ ] **V-1 (BUG-001):** Player receives XP when their companion deals the killing blow. Verify XP bar moves. Test in both grouped and solo scenarios.
- [ ] **V-2 (No regression - solo):** Player receives normal solo XP when killing mobs without any companion present. Amount should be identical to before the change.
- [ ] **V-3 (No regression - group):** Standard group XP (players only, no companions) is unchanged.
- [ ] **V-4 (No regression - bots/pets):** Bot and pet kill credit still works correctly if applicable.
- [ ] **V-5 (Companion XP):** After a grouped kill, companion receives XP (verify via `!status` showing XP > 0).
- [ ] **V-6 (Companion level-up):** After sufficient kills, companion levels up. Verify: chat message appears, level increases, HP/mana restore to full, stats scale.
- [ ] **V-7 (Level cap):** Companion at `player_level - MaxLevelOffset` stops leveling. XP continues to accumulate (visible via `!status`) but level does not increase.
- [ ] **V-8 (Level 60 hard cap):** If MaxLevelOffset is set to 0, companion caps at 60 even if player is 60.
- [ ] **V-9 (Cascading level-up):** Set MaxLevelOffset to 0, get companion to cap, then set MaxLevelOffset back to a higher value. On next kill, verify companion levels up multiple times if it has enough stored XP.
- [ ] **V-10 (Gray cons):** Companion earns no XP from mobs that con gray to it.
- [ ] **V-11 (Faction):** Player receives faction hits when companion deals killing blow (same as when player kills directly).
- [ ] **V-12 (Task credit):** Player receives task/quest kill credit when companion deals killing blow.
- [ ] **V-13 (Loot - no regression):** Loot still drops correctly when companion deals killing blow (already fixed, verify no regression).
- [ ] **V-14 (!status XP display):** `!status` command shows current XP and XP needed for next level.
- [ ] **V-15 (Persistence):** Companion XP persists across suspend/unsuspend, zone changes, and server restarts.
- [ ] **V-16 (Multiple companions):** With 2+ companions in group, each receives its own XP share. More companions = smaller individual shares.

---

> **Next step:** Spawn the implementation team with ONLY the agents listed
> in "Required Implementation Agents" above: **c-expert** and **lua-expert**.
> They will coordinate via `SendMessage` and work through the task list in
> dependency order. c-expert handles tasks 1-4, lua-expert handles task 5.
