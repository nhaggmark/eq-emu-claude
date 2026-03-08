# companion-levelup-fixes — Architecture & Implementation Plan

> **Feature branch:** `bugfix/companion-levelup-fixes`
> **PRD:** `game-designer/prd.md` (N/A — bug fix driven by BUG-007 report + user audit request)
> **Author:** architect
> **Date:** 2026-03-08
> **Status:** Approved

---

## Executive Summary

A thorough audit of the companion level-up process (`Companion::CheckForLevelUp` -> `ScaleStatsToLevel` -> `NPC::SetLevel`) reveals three bugs that combine to cause the reported "companion disappears from group interface" issue. The root cause is that the level-up code path is missing client notification packets that bots and mercs correctly send: (1) the `WhoLevel` appearance packet is called with wrong parameters so it never reaches any client, (2) `SendHPUpdate()` is never called so the group window HP bar becomes stale, and (3) no group update is sent to refresh the client's group window state. The fix is confined to `companion.cpp` — adding three missing packet calls after level-up, modeled directly on the bot level-up pattern in `bot.cpp:3990-4018`.

## Existing System Analysis

### Current State

The companion level-up system works as follows:

1. **XP accumulation:** `Companion::AddExperience(xp)` adds XP to `m_companion_xp` and calls `CheckForLevelUp()` in a loop to handle cascading level-ups.

2. **Level-up check:** `Companion::CheckForLevelUp()` computes a level cap (`owner_level - MaxLevelOffset`, clamped 1-60), checks XP against `GetXPForNextLevel()` (formula: `level * level * 1000`), then on level-up:
   - Calls `ScaleStatsToLevel(new_level)` which scales all stats proportionally and calls `NPC::SetLevel()`
   - Calls `LoadCompanionSpells()` to re-query `companion_spell_sets` for the new level
   - Sets HP and mana to full (reward for leveling)
   - Calls `Save()` to persist to `companion_data` table

3. **Stat scaling:** `ScaleStatsToLevel()` computes `scale = new_level / recruited_level`, applies it to all base stats (STR, STA, DEX, AGI, INT, WIS, CHA, AC, ATK, resists, HP, mana), then calls `CalcBonuses()` to recalculate derived stats including equipment bonuses.

4. **NPC::SetLevel():** Sets `level = in_level`, calls `SendLevelAppearance()` for the ding visual, and calls `SendAppearancePacket(AppearanceType::WhoLevel, in_level)`.

### Gap Analysis

Comparing the companion level-up path against the working bot level-up path (`bot.cpp:3990-4018`), three critical steps are missing:

| Step | Bot Level-Up | Companion Level-Up | Gap? |
|------|-------------|-------------------|------|
| Recalculate stats | `CalcBotStats()` | `ScaleStatsToLevel()` + `CalcBonuses()` | No |
| Ding visual | `SendLevelAppearance()` | Via `NPC::SetLevel()` | No |
| Heal to full | `SetHP/SetMana` | `SetHP(GetMaxHP())` + `SetMana(GetMaxMana())` | No |
| **HP update to group** | **`SendHPUpdate()`** | **MISSING** | **YES** |
| **Broadcast WhoLevel** | **`SendAppearancePacket(WhoLevel, level, true, true)`** | **Called with wrong params (false, false) — never sent** | **YES** |
| Reload spells | `AI_AddBotSpells()` | `LoadCompanionSpells()` | No |
| Save | (deferred) | `Save()` | No |

Additionally, the merc level-up path (`Client::UpdateMercLevel()` in `merc.cpp:5622-5628`) also correctly calls `SendAppearancePacket(AppearanceType::WhoLevel, GetLevel(), true, true)` — broadcasting to the whole zone.

## Technical Approach

### Architecture Decision

This is a pure C++ fix in `companion.cpp`. No database changes, no Lua changes, no rule changes, no configuration changes.

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| `eqemu/zone/companion.cpp` | Bug fix — add missing packet calls | The level-up code path is missing `SendHPUpdate()` and correct `SendAppearancePacket` calls that the bot and merc systems include. This is the least-invasive fix: adding 2-3 lines of packet code to the existing `CheckForLevelUp()` method. |

### Data Model

No changes. The `companion_data` table already stores the level correctly — the bug is in client notification, not persistence.

### Code Changes

#### C++ Changes

**File: `eqemu/zone/companion.cpp`**

**Method: `Companion::CheckForLevelUp()`** (around line 1655-1665)

After the existing calls to `SetHP(GetMaxHP())` / `SetMana(GetMaxMana())` and before `Save()`, add:

1. **`SendHPUpdate()`** — Sends the companion's current HP/maxHP to:
   - All clients who have the companion targeted
   - All group members via `Group::SendHPPacketsFrom()`
   - All clients with the companion on x-target
   This updates the group window HP bar immediately after the HP/maxHP change.

2. **`SendAppearancePacket(AppearanceType::WhoLevel, new_level, true, true)`** — Broadcasts the new level to ALL clients in the zone with `whole_zone=true` and `ignore_self=true`. This updates:
   - The group window level display
   - The target window level display
   - The /who listing

These two calls match the bot level-up pattern exactly (`bot.cpp:4015-4016`).

#### Lua/Script Changes

None required.

#### Database Changes

None required.

#### Configuration Changes

None required.

## Comprehensive Bug Inventory

The audit found the following bugs in the level-up process:

### BUG A: WhoLevel appearance packet never broadcast (CRITICAL — root cause)

**Location:** `NPC::SetLevel()` (npc.cpp:2260) called from `ScaleStatsToLevel()` (companion.cpp:268)

**Root cause:** `NPC::SetLevel()` calls `SendAppearancePacket(AppearanceType::WhoLevel, in_level)` with default parameters `whole_zone=false, ignore_self=false, target=nullptr`. Inside `SendAppearancePacket()` (mob.cpp:4121), when `whole_zone` is false and `target` is null, the code falls through to `IsClient()` check. Since the companion is NOT a client, the packet is never queued to anyone. The WhoLevel update is effectively lost.

**Impact:** The Titanium client never learns the companion's new level. The group window and target window continue showing the old level. If the client uses the stale level to calculate HP bar percentage, the displayed HP becomes wildly incorrect (e.g., the companion has 100% HP at the new max, but the client calculates against the old max, showing an impossible percentage).

**Fix:** After level-up, explicitly call `SendAppearancePacket(AppearanceType::WhoLevel, new_level, true, true)` in `CheckForLevelUp()`, matching the bot/merc pattern.

### BUG B: SendHPUpdate() never called after level-up (CRITICAL — contributes to group display issue)

**Location:** `Companion::CheckForLevelUp()` (companion.cpp:1613-1666)

**Root cause:** The level-up code sets `SetHP(GetMaxHP())` and `SetMana(GetMaxMana())` but never calls `SendHPUpdate()`. The group window relies on HP update packets (`OP_MobHealth` via `Mob::CreateHPPacket()`) to display the member's health bar. Without this call, the client's cached HP data for the companion is stale — it still reflects the pre-level HP values. The group window may show 0% HP, an overflowing HP bar, or may fail to render the member entirely.

**Impact:** Group window HP bar is incorrect. May cause the companion to appear dead or invisible in the group window depending on how the Titanium client handles HP ratio overflow.

**Fix:** Call `SendHPUpdate()` after `SetHP(GetMaxHP())` / `SetMana(GetMaxMana())` in `CheckForLevelUp()`.

### BUG C: No group update packet sent (MINOR — cosmetic)

**Location:** `Companion::CheckForLevelUp()` (companion.cpp:1613-1666)

**Root cause:** Neither `OP_GroupUpdate` nor any group-specific refresh is sent during level-up. The group window continues showing stale data until the next natural group event (member zone, new member join, etc.).

**Impact:** Low — the WhoLevel and HP updates (Bugs A and B) are the primary mechanisms the client uses for group window display. A full group update would be belt-and-suspenders but is not strictly necessary if A and B are fixed.

**Fix:** Not required if Bugs A and B are fixed. Can be added later if needed.

### BUG D: Missing Mob::SetLevel override for Companion (QUALITY — not a bug per se)

**Location:** `Companion` class (companion.h)

**Root cause:** `Companion` does not override `SetLevel()`. It inherits `NPC::SetLevel()` which sends packets with wrong parameters (Bug A). A companion-specific override could fix the broadcast issue at the SetLevel layer instead of patching it in CheckForLevelUp.

**Impact:** Code quality issue. The current fix (adding explicit broadcast calls in CheckForLevelUp) is simpler and avoids the risk of unintended side effects from overriding SetLevel.

**Fix:** Recommend keeping the current approach (explicit calls in CheckForLevelUp) rather than adding a SetLevel override. Simpler and more auditable.

## State Preservation Audit

The audit also verified that the following states ARE correctly preserved during level-up:

| State | Preserved? | Mechanism |
|-------|-----------|-----------|
| Group membership | YES | `members[]` and `membername[]` arrays are not touched during level-up |
| `isgrouped` flag | YES | `SetGrouped()` is never called during level-up |
| Equipment (`m_equipment[]`) | YES | Equipment array is not modified during level-up |
| Equipment bonuses | YES | `CalcBonuses()` calls `CalcItemBonuses()` which re-reads equipment |
| Hate list | YES | Not cleared during level-up |
| Target | YES | Not changed during level-up |
| Follow state (`followid`) | YES | Not changed during level-up |
| Stance | YES | `m_current_stance` not modified during level-up |
| Owner relationship | YES | `m_owner_char_id` not modified during level-up |
| Entity variables | YES | Entity variable map not cleared during level-up |
| Spell recast timers | YES | `LoadCompanionSpells()` resets `time_cancast` to current time (new spells available immediately) |
| Entity ID | YES | Not changed — no despawn/respawn occurs |
| Buff slots | YES | `CalcSpellBonuses()` inside `CalcBonuses()` re-reads active buffs |

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | Add `SendHPUpdate()` and correct `SendAppearancePacket(WhoLevel)` calls after level-up in `Companion::CheckForLevelUp()` | c-expert | — | 3 lines of code in companion.cpp |

### Detailed Task 1 Description

In `Companion::CheckForLevelUp()` (companion.cpp), after the `SetMana(GetMaxMana())` call (approximately line 1659) and before the `Save()` call (line 1662), insert:

```cpp
// Notify clients of HP/level changes so the group window updates correctly.
// Matches the bot level-up pattern (bot.cpp:4015-4016).
SendHPUpdate();
SendAppearancePacket(AppearanceType::WhoLevel, new_level, true, true);
```

This is a 2-line fix. The `SendHPUpdate()` call broadcasts HP data to all group members and clients who have the companion targeted. The `SendAppearancePacket()` call broadcasts the new level to all clients in the zone.

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `SendHPUpdate()` causes crash on null group | Very Low | High | `SendHPUpdate()` already handles null group gracefully (mob.cpp:1592-1597 checks `IsGrouped()` and `GetGroupByMob()`) |
| WhoLevel broadcast causes Titanium client crash | Very Low | High | Identical call used by bots and mercs for years. The Titanium client handles this packet for all entity types. |
| `CalcBonuses()` after stat scaling produces incorrect values | Low | Medium | Same function used by all entities. The companion's stat scaling sets `base_hp` before `CalcBonuses()` runs `CalcMaxHP()` which reads `base_hp`. Verified correct. |

### Compatibility Risks

This fix adds standard packet calls that the existing client already handles. No risk to existing NPC, bot, or merc systems. The fix is completely contained within the companion level-up path.

### Performance Risks

None. The added calls send 2 packets during a level-up event (rare occurrence). Negligible network and CPU impact.

## Review Passes

### Pass 1: Feasibility

**Can we build this?** Yes. The fix requires adding 2 lines of code that call existing, well-tested methods (`SendHPUpdate()` and `SendAppearancePacket()`). Both methods are used extensively by bots, mercs, and clients throughout the codebase. The Titanium client already handles both packet types for NPC-like group members (bots use `NPC=0` in their spawn struct, identical to companions).

**Hardest part:** None — this is a straightforward missing-packet-call bug fix.

### Pass 2: Simplicity

**Is this the simplest approach?** Yes. Alternatives considered:

1. **Override `SetLevel()` in Companion class** — Would fix Bug A at the source but introduces an override that could have unintended side effects if SetLevel is called from other paths. The explicit calls in CheckForLevelUp are more auditable and less risky.

2. **Send a full OP_GroupUpdate during level-up** — Unnecessary overhead. The HP update + WhoLevel appearance packet are sufficient for the client to maintain correct group window state. Full group updates are only needed for member add/remove.

3. **Fix `NPC::SetLevel()` to always broadcast WhoLevel to the whole zone** — Would affect ALL NPCs in the game, not just companions. Excessive scope change for a companion-specific fix.

The chosen approach (2 lines in CheckForLevelUp) is the minimum viable fix.

### Pass 3: Antagonistic

**What could go wrong?**

1. **Double level appearance effect:** `NPC::SetLevel()` already calls `SendLevelAppearance()` (ding visual). Adding `SendAppearancePacket(WhoLevel)` does NOT cause a second ding — it only updates the level number in the client's spawn table. No visual duplication.

2. **Race condition during cascading level-ups:** `AddExperience()` calls `CheckForLevelUp()` in a loop. Each iteration sends HP update and WhoLevel packets. If the companion levels up 3 times rapidly (e.g., cap released), the client receives 3 sets of packets. This is correct behavior — each packet supersedes the previous with the latest level/HP values.

3. **Stale group pointer during level-up:** `SendHPUpdate()` calls `entity_list.GetGroupByMob(this)` to find the group. During level-up, the companion's group membership is unchanged, so this lookup is safe and returns the correct group.

4. **HP overflow on Titanium client:** After level-up, HP is set to max. The `CreateHPPacket()` inside `SendHPUpdate()` sends `hp_ratio` as a percentage (0-100). Since HP is at max, the ratio is 100%. No overflow risk.

5. **Entity ID reuse:** Level-up does NOT despawn/respawn the entity. The entity ID remains stable. The client's entity tracking is not disrupted.

### Pass 4: Integration

**Implementation order:** Single task, no dependencies.

**Build verification:** After the code change, rebuild the zone binary:
```bash
docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"
```

**Testing sequence:**
1. Recruit a companion
2. Grant sufficient XP to trigger a level-up (via `#setxp` or combat)
3. Verify: companion stays in group window
4. Verify: companion HP bar shows 100% after level-up
5. Verify: companion level number updates in group/target window
6. Verify: companion retains equipment, stance, follow state after level-up
7. Verify: companion gains new spells appropriate for the new level
8. Verify: cascading level-ups (multiple levels at once) work correctly

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| c-expert | Task 1: Add missing packet calls in `CheckForLevelUp()` | C++ source change in `companion.cpp` |

## Validation Plan

- [ ] Recruit a companion and level it up via combat or GM command — companion remains in group window throughout
- [ ] After level-up, companion HP bar shows 100% (full health)
- [ ] After level-up, companion level number in target/group window matches actual level
- [ ] After level-up, companion retains all equipped items (verify with `!equipment` command)
- [ ] After level-up, companion retains current stance (passive/balanced/aggressive)
- [ ] After level-up, companion continues following the owner
- [ ] After level-up, companion casts spells appropriate for new level (verify with caster companion)
- [ ] Multiple consecutive level-ups (e.g., releasing level cap) do not break group membership
- [ ] Server does not crash during companion level-up
- [ ] Companion level is correctly saved to `companion_data` table after level-up

---

> **Next step:** Spawn the implementation team with ONLY the agents listed
> in "Required Implementation Agents" above. Do not spawn experts without
> assigned tasks.
