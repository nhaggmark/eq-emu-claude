# companion-experience — Product Requirements Document

> **Feature branch:** `bugfix/companion-experience`
> **Author:** game-designer
> **Date:** 2026-03-05
> **Status:** Draft

---

## Problem Statement

The companion recruitment system is the signature feature of this server,
enabling 1–3 players to tackle all Classic-through-Luclin content by
recruiting NPC companions into their group. However, a critical bug
(BUG-001) breaks the core gameplay loop: **when a companion NPC deals the
killing blow, the player receives no experience**. This makes companions
a liability rather than an asset — players must micromanage kills to avoid
losing XP, which defeats the purpose of having companions.

Beyond the bug fix, the companion leveling infrastructure is partially
built but not wired up end-to-end. The `Companion` class already has
`AddExperience()`, `CheckForLevelUp()`, `GetXPForNextLevel()`, and
`ScaleStatsToLevel()` methods, and the `companion_data` table already has
`level`, `experience`, and `recruited_level` columns. But the XP
distribution path from group kills to companion leveling is not connected.
This feature completes that loop with clear design rules so companions
grow alongside the player in a balanced, predictable way.

This matters because:
- **Solo players** rely on companions for group content; broken XP makes
  the system unusable for progression.
- **Companion investment** should feel meaningful — watching your recruited
  guard or druid grow stronger over shared adventures is a core fantasy,
  akin to the bond between a Beastlord and their warder.
- **Small-group balance** depends on companions being effective but not
  overpowered; XP-based leveling is the natural throttle.

### What Already Exists vs. What's New

| Component | Status | Notes |
|-----------|--------|-------|
| `Companion::AddExperience()` | Exists | Adds XP and checks for level-up |
| `Companion::CheckForLevelUp()` | Exists | Checks threshold, triggers stat scaling |
| `Companion::GetXPForNextLevel()` | Exists | Returns `level * level * 1000` |
| `Companion::ScaleStatsToLevel()` | Exists | Proportional stat scaling from base |
| `Companion::LoadCompanionSpells()` | Exists | Reloads spells for current level |
| `companion_data` table (level, XP) | Exists | Persistence columns already present |
| `Companions::XPSharePct` rule | Exists | Default 50%, not yet wired up |
| `Companions::XPContribute` rule | Exists | Default true |
| `Companions::MaxLevelOffset` rule | Exists | Default 1 |
| Kill credit resolving through companions | **Missing (BUG-001)** | Companions not recognized in death chain |
| XP distribution from group kills to companions | **Missing** | SplitExp does not call AddExperience |
| Post-death hooks firing on companion kills | **Broken (BUG-001)** | Faction, tasks, quest credit fail |

## Goals

1. **Fix BUG-001:** Player receives full, correct experience from kills
   regardless of whether the player or a companion deals the killing blow.
   All post-death hooks (loot, faction, quest credit, task updates) fire
   normally in all companion group scenarios.

2. **Wire up companion XP distribution:** When a group earns kill XP,
   each companion in the group receives its share of XP toward leveling
   up. The split is governed by tunable rules that the server operator can
   adjust.

3. **Complete the companion leveling loop:** When a companion accumulates
   enough XP, it levels up — stats scale, spells update, and the player
   receives clear feedback. Companions have a level cap relative to the
   player to prevent them from surpassing their recruiter.

4. **No regression:** Solo XP (without companions), standard group XP
   (players only), and existing bot XP behavior remain unchanged.

## Non-Goals

- **Companion AA system:** Companions do not earn or spend Alternate
  Advancement points. That is a future feature if needed.
- **Companion XP loss on death:** Companions do not lose XP when they die.
  They are already penalized by the death/despawn timer mechanic.
- **Companion-to-companion XP:** Companions do not distribute XP to each
  other independently of the player. XP flows through the group split.
- **New UI elements:** No custom client UI for companion XP bars. Feedback
  is delivered through chat messages. The Titanium client cannot be
  modified.
- **XP for non-kill sources:** Companions do not gain XP from quest turn-
  ins, exploration, or tradeskills. Kill XP only.
- **Changing the player XP formula:** The player's own XP gain formula,
  group bonuses, ZEM, hell levels, and class/race penalties are untouched.
- **Structured advancement tiers:** No formal rank system (e.g.,
  "Journeyman / Veteran / Champion") for companions. Growth is organic
  through shared experience, not bureaucratic progression.

## User Experience

### Player Flow

1. **Player recruits an NPC companion** and adds it to their group (existing
   recruitment system — unchanged by this feature).

2. **Player and companion fight mobs together.** Whether the player or the
   companion lands the killing blow, the post-death sequence fires normally:
   - The player receives their share of kill XP (standard group split).
   - The companion receives its share of XP toward its own leveling.
   - Loot drops on the corpse as expected.
   - Faction hits apply to the player.
   - Quest/task kill credit is granted to the player.

3. **Companion accumulates XP over time.** The player can check their
   companion's progress with a chat command (e.g., `!companion status`
   or similar — existing companion management commands). The companion's
   current XP, XP needed for next level, and current level are displayed.

4. **Companion levels up.** When enough XP is accumulated, the companion
   levels up automatically:
   - The companion speaks a level-up line reflecting their class and race.
     If the NPC-LLM sidecar is active, the dialogue is generated with
     class and race context — a Teir'Dal shadow knight might speak of
     growing power with cold resolve, a Vah Shir warrior might frame it
     as honorable growth, a gnome wizard might note it academically.
     If the sidecar is not active, a terse fallback is used:
     *"Guard Archus says, 'The battles have hardened me.'"*
   - A system message confirms the level: *"Guard Archus is now level 25."*
   - The companion's stats (HP, AC, STR, etc.) scale proportionally from
     their recruitment baseline.
   - The companion's spell list updates to include spells available at the
     new level (Classic-Luclin spell lines only).
   - The companion's data is saved to the database.

5. **Level cap enforcement.** If a companion reaches `player_level -
   MaxLevelOffset` (default: 1 level below the player), it stops gaining
   levels until the player levels up. Excess XP is not lost — it
   accumulates but does not trigger further level-ups until the cap rises.
   **Hard cap: companions may never exceed level 60** regardless of any
   rule configuration, enforcing the Classic-Luclin era ceiling.

6. **Multiple companions.** If the player has multiple companions in the
   group, each companion receives its own share of the group XP split.
   More companions means each individual share is smaller (standard group
   splitting), creating a natural trade-off between companion quantity and
   individual companion growth rate.

### Example Scenario

A level 30 half-elf ranger has recruited a level 28 human guard (warrior
class) companion from the Highpass garrison. They venture into the
Splitpaw gnoll lair to hunt the higher-level gnolls there, fighting as a
two-member group (player + companion).

1. The ranger pulls a blue-con Splitpaw gnoll (level 29). The companion
   tanks while the ranger does ranged DPS.

2. The companion lands the killing blow. The post-death hooks fire:
   - The ranger receives XP from the kill (full group split for a
     2-member group with the standard group bonus).
   - The companion receives 50% of its "share" as companion XP (governed
     by `Companions::XPSharePct`). The other 50% returns to the player
     pool.
   - The gnoll's corpse has loot. Faction hits apply to the ranger.

3. After several hours of grinding, the companion has accumulated enough
   XP to reach level 29. The guard says: *"I have learned much fighting
   at your side."* System message: *"Guard Hensley is now level 29."*
   The guard's HP, AC, and attack stats increase proportionally.

4. At level 29, the companion is now at the level cap (`player_level 30 -
   MaxLevelOffset 1 = max companion level 29`). The companion continues to
   accumulate XP but will not level to 30 until the ranger reaches level
   31.

5. The ranger recruits a second companion — a level 27 wood elf druid
   from Surefall Glade. Now in a 3-member group, XP is split three ways
   with the standard group bonus. Both companions receive their respective
   shares. The druid, being lower level, needs less XP per level and may
   catch up relatively quickly.

## Game Design Details

### Mechanics

#### 1. Kill Credit and XP Trigger (BUG-001 Fix)

When any mob in the zone dies, the server determines who gets kill credit.
Currently, this resolution chain handles players, pets, and bots but does
not recognize companions. The fix must ensure:

- If a **companion** is the top damage dealer or killer, kill credit
  resolves to the **companion's owner** (the recruiting player).
- Once resolved to the owner client, the standard group XP split proceeds
  as normal — the group's `SplitExp` distributes XP to all client members.
- All post-death hooks that depend on kill credit (faction, tasks, quest
  events, loot) also fire correctly when the credit resolves through a
  companion.

This should behave identically to how pet kills already resolve to the
pet's owner. The companion is effectively treated as an "owned entity" for
the purposes of kill credit resolution.

#### 2. Group XP Split with Companions

The group XP split follows standard EQ group mechanics with companion-
specific rules:

- **Group member count:** Companions count as group members for XP
  splitting purposes when `Companions::XPContribute` is true (default).
  A group of 1 player + 2 companions = 3 members for split calculations.

- **Group bonus:** The standard EQ group XP bonus applies based on total
  group member count (2% per additional member, or the server's configured
  `GroupExpMultiplier`).

- **Player XP:** Each client in the group receives their XP share as
  normal via `AddEXP`. Players should not notice any difference from
  standard group XP splitting — companions are just another group member.

- **Companion XP share:** Each companion's "share" of the group XP split
  is further modified by `Companions::XPSharePct` (default 50%):
  - 50% of the companion's share goes to the companion as leveling XP.
  - The remaining 50% is returned to the player's XP pool (bonus XP for
    the companion's owner).
  - This means having a companion is always a net positive for the player's
    own XP gain compared to soloing, while the companion also grows.

- **Con-based scaling:** Companions use the same consider-based XP scaling
  as players. A companion fighting gray-con mobs earns no XP from those
  kills, just as a player would not.

#### 3. Companion XP Table and Leveling

- **XP per level:** Companions use a simplified XP curve:
  `XP_needed = level * level * 1000`. This is faster than the player XP
  curve but still requires significant grinding at higher levels.

  | Level | XP to Next Level |
  |-------|-----------------|
  | 1     | 1,000           |
  | 10    | 100,000         |
  | 20    | 400,000         |
  | 30    | 900,000         |
  | 40    | 1,600,000       |
  | 50    | 2,500,000       |
  | 60    | 3,600,000       |

- **Level cap:** The companion level cap is the **lower** of:
  1. `player_level - Companions::MaxLevelOffset` (default offset: 1), AND
  2. **60 (absolute hard cap — the Classic-Luclin era ceiling)**

  A level 60 player's companion caps at level 59. This ensures:
  - The player always remains the leader / most powerful member.
  - Companions are strong enough to contribute meaningfully.
  - There is always room for the companion to grow when the player does.
  - **No companion may ever exceed level 60**, regardless of server
    configuration or rule overrides.

- **XP accumulation at cap:** When at the level cap, the companion
  continues to accumulate XP internally but does not level up. When the
  player levels and the cap rises, the companion may immediately level if
  it has enough stored XP (potentially multiple level-ups in sequence).

- **Level-up effects:** When a companion levels up:
  - **Stats scale** proportionally from recruitment baseline using the
    ratio `new_level / recruited_level`. All stats (STR, STA, DEX, AGI,
    INT, WIS, CHA, AC, ATK, HP, Mana, resists) scale together.
  - **Spell list reloads** to include spells available at the new level
    (from `npc_spells` / `npc_spells_entries`). Only spells from
    Classic-Luclin spell lines are included; the existing era filtering
    on the spell tables enforces this.
  - **HP and mana restore** to full on level-up (a reward for hitting the
    milestone).
  - **Data persists** — level, XP, and scaled stats are saved to the
    companion database table.

#### 4. Companion Death and XP

- **No XP loss on death.** Companions do not lose experience when they
  die. Rationale: companion death already carries meaningful penalties:
  - The player loses their combat partner until resurrection or re-summon.
  - The companion has a despawn timer (`Companions::DeathDespawnS`,
    default 30 minutes) after which it auto-dismisses.
  - Death count is tracked in the companion's history.
  
- **XP continues after resurrection.** If a companion is resurrected or
  re-summoned, it retains all accumulated XP and continues gaining from
  where it left off.

#### 5. Edge Cases

- **Solo player (no group):** If the player is ungrouped and their
  companion kills a mob, kill credit must still resolve to the player.
  The player receives full solo XP. The companion receives XP based on
  its share calculation (as if in a 2-member group with the
  `XPSharePct` modifier applied).

- **Gray cons:** Mobs that con gray to the companion yield no companion
  XP (same rule as players). The player may still receive XP if the mob
  cons to them appropriately.

- **Level disparity in group:** If a player is level 50 and their
  companion is level 20, the companion receives its proportional share
  from the group split. The large level gap means the companion will
  level faster (lower XP thresholds) while the player's share is
  unaffected. However, very low-level companions fighting high-level
  content would earn standard XP — the existing level-range con system
  handles whether a mob is "appropriate" for XP naturally.

- **Multiple companions:** A group of 1 player + 5 companions (max
  group size 6) splits XP 6 ways. Each companion gets a small share
  but the player benefits from the returned `XPSharePct` surplus from
  all companions. This naturally discourages "companion armies" for XP
  purposes — more companions means each one grows slower.

- **Companion at level 1:** Level 1 companions need only 1,000 XP to
  reach level 2, so they will level quickly in the early stages. This is
  intentional — a newly recruited low-level companion should catch up
  reasonably fast.

- **Companion at level 59 (effective max):** With `MaxLevelOffset` of 1
  and a server level cap of 60, the highest a companion can reach is
  level 59. XP continues to accumulate beyond this point but has no
  effect. The absolute hard cap of 60 is enforced even if
  `MaxLevelOffset` is set to 0 via server rules.

### Balance Considerations

**Why this works for 1–3 players:**

- **Solo player + 1 companion:** The player gets a combat partner that
  grows over time, making solo play viable for group content. The XP
  split (2-member group with bonus) is generous enough that the player
  doesn't feel punished for having a companion. The companion's share
  being partially returned (`XPSharePct`) means the player levels only
  slightly slower than pure solo.

- **2 players + companions:** Each player's companion grows at the rate
  dictated by the group size. In a 4-member group (2 players + 2
  companions), the XP split is standard. Players level at the expected
  group rate; companions are a bonus.

- **3 players + companions:** Approaching a full group (up to 6 members).
  XP per member is smaller but the group bonus helps. Companion growth
  is slower but the group is already powerful enough that companion
  levels are less critical.

**Preventing trivialization:**

- The `MaxLevelOffset` ensures companions never match or exceed the
  player, maintaining the player as the protagonist.
- The `XPSharePct` split means companions level slower than players by
  design.
- The `StatScalePct` rule provides an additional global knob to tune
  companion power if needed.
- Companions use the same con system — they can't powerlevel by having a
  high-level player kill greens.

### Era Compliance

This feature is fully era-compliant for Classic through Luclin:

- **XP mechanics:** Based on standard EQ group XP splitting which existed
  from launch. No post-Luclin mechanics are referenced.
- **Level cap:** Hard cap of 60 enforced on all companions. The
  `MaxLevelOffset` rule provides an additional buffer (default: companion
  max = player_level - 1). No companion may exceed level 60 regardless
  of server configuration.
- **Companion classes:** The companion spell AI supports all 15 Classic-
  Luclin classes (Warrior through Beastlord). No post-Luclin classes
  (Berserker) are included.
- **Spells and abilities:** Companion spell lists are drawn from the
  existing `npc_spells` tables which are already era-filtered. When a
  companion levels up and its spell list reloads, only spells available
  in the Classic-Luclin era are included.
- **No AA for companions:** AA progression is a player-only system in
  Classic-Luclin, and companions are excluded by design.
- **Excluded races:** Frogloks (race 74/330) are correctly excluded from
  companion recruitment by the existing system. They are enslaved NPCs
  in Classic-Luclin Norrath, not free adventurers who would join a party.
- **Terminology:** This feature uses "companion" exclusively — not
  "mercenary" (Seeds of Destruction, 2008), "heroic adventure"
  (post-Planes of Power), or "partisan" (post-PoP). These terms are
  post-era anachronisms.
- **Narrative precedent:** The closest canonical analogue within the era
  is the Beastlord warder (Luclin) — a persistent companion that scales
  with its owner through a bond forged in shared combat.

### Era Compliance Hard Stops

The following must NEVER appear in this feature:

| Violation | Why |
|-----------|-----|
| Companion level exceeding 60 | Classic-Luclin cap is 60, full stop |
| "Mercenary" framing or terminology | Mercs are Seeds of Destruction (2008) |
| "Heroic Adventures" or "Partisan" quest terms | Post-Planes of Power |
| Froglok companions in examples or design | Enslaved NPCs in Classic-Luclin |
| Named NPCs from Gates of Discord or later | Post-era content |
| Spells or abilities introduced after Luclin | Era filter on spell tables required |
| Berserker class companions | Class introduced in Gates of Discord |

## Affected Systems

- [x] C++ server source (`eqemu/`) — kill credit resolution, group XP
  split, companion XP distribution, post-death hook chain
- [ ] Lua quest scripts (`akk-stack/server/quests/`)
- [ ] Perl quest scripts (maintenance only)
- [ ] Database tables (`peq`) — companion_data table already has XP column
- [x] Rule values — existing `Companions::XPSharePct`,
  `Companions::XPContribute`, `Companions::MaxLevelOffset` rules
- [ ] Server configuration
- [ ] Infrastructure / Docker

## Dependencies

- **Companion recruitment system:** Must be functional (it is — companions
  can be recruited, added to groups, and persist in the database).
- **Companion data persistence:** The `companion_data` table must have
  columns for XP and level tracking (already present — `level`,
  `experience`, `recruited_level` columns exist).
- **Group system:** The standard EQ group system must support companions
  as members (already implemented — companions join groups via
  `CompanionJoinClientGroup()`).

## Open Questions

1. **Should companion XP be visible in a progress bar or percentage?**
   Currently the design uses chat messages only (Titanium client
   limitation). Should `!companion status` show "1,234 / 900,000 XP
   (0.1%)" or just "Level 30, needs more experience"? Recommendation:
   show exact numbers — players like seeing progress.

2. **Should there be a "catch-up" mechanic for newly recruited high-level
   companions?** If a level 55 player recruits a level 30 NPC, that
   companion has a very long road to level 54. The current design says
   "this is fine — recruit level-appropriate NPCs." But we could add a
   rest XP or catch-up bonus. Recommendation: defer to a future feature
   if players report this as a pain point.

3. **What happens to companion XP when dismissed and re-recruited?** The
   re-recruitment system (Task 23) already preserves companion data for
   `DismissedRetentionDays` (default 30 days). XP and level should be
   preserved across dismiss/re-recruit cycles. The architect should verify
   this works with the existing persistence model.

## Acceptance Criteria

- [ ] **AC-1:** Player receives XP when their companion deals the killing
  blow to a mob. XP amount matches what a standard group kill would yield.
- [ ] **AC-2:** Player receives XP when the player deals the killing blow
  with a companion in the group. No regression from current behavior.
- [ ] **AC-3:** Companion receives XP toward leveling after each kill (when
  `Companions::XPContribute` is true). Amount is the companion's group
  share multiplied by `Companions::XPSharePct`.
- [ ] **AC-4:** Companion levels up when accumulated XP exceeds
  `GetXPForNextLevel()`. Stats scale, spells reload, player receives a
  chat notification.
- [ ] **AC-5:** Companion does not level beyond `player_level -
  MaxLevelOffset`. XP accumulates but level-up does not trigger until the
  cap rises. Companion may never exceed level 60 (absolute hard cap).
- [ ] **AC-6:** Multiple companions in a group each receive their own XP
  share. XP is split according to group size.
- [ ] **AC-7:** All post-death hooks fire correctly when a companion deals
  the killing blow: loot drops, faction hits apply, quest/task kill credit
  is granted to the player.
- [ ] **AC-8:** Solo XP (no companion) is completely unchanged. No
  regression.
- [ ] **AC-9:** Existing bot and mercenary XP behavior is unchanged. No
  regression.
- [ ] **AC-10:** Companion XP and level persist across save/load, zone
  changes, suspend/unsuspend, and server restarts.
- [ ] **AC-11:** `!companion status` (or equivalent command) displays the
  companion's current level, XP, and XP needed for next level.

---

## Appendix: Technical Notes for Architect

_These are advisory observations from reviewing the codebase topography.
The architect makes all implementation decisions._

### Kill Credit Resolution (BUG-001)

The kill credit chain in `NPC::Death` (attack.cpp ~line 2614-2655)
resolves `give_exp` through owner chains for pets and bots but does not
handle companions. The companion entity type needs to be recognized in
this resolution chain so that `give_exp` resolves to the companion's
owner client. The existing pattern for pets (`HasOwner()` /
`GetUltimateOwner()`) could serve as a model, or the companion could be
handled as a special case alongside the bot/pet checks.

Key code path: `give_exp = hate_list.GetDamageTopOnHateList(this)` ->
owner resolution -> `give_exp_client` determination -> `SplitExp()`.

### Group XP Split

`Group::SplitExp()` in exp.cpp (~line 1123) already iterates group
members and has companion-aware code (line 1188-1194) that calls
`RecordKill()` on companions. The XP share to companions via
`AddExperience()` could be added in this same loop or in the client's
`AddEXP()` path.

### Existing Companion XP Infrastructure

The companion class already has:
- `m_companion_xp` (uint32) — accumulated XP
- `AddExperience(uint32 xp)` — adds XP and checks for level-up
- `CheckForLevelUp()` — checks XP against threshold, triggers stat scaling
- `GetXPForNextLevel()` — returns `level * level * 1000`
- `ScaleStatsToLevel(uint8)` — proportional stat scaling from base
- `LoadCompanionSpells()` — reloads spell list for current level

### Relevant Rules

| Rule | Default | Purpose |
|------|---------|---------|
| `Companions::XPContribute` | true | Companions count in group XP split |
| `Companions::XPSharePct` | 50 | % of companion's share that goes to companion |
| `Companions::MaxLevelOffset` | 1 | Companion max level = player_level - this |

### Lua Mod Hook

`GetExperienceForKill` is exposed as a Lua mod hook (lua_mod.h). The
architect should verify that this hook fires correctly when kill credit
resolves through a companion.

---

> **Next step:** Pass this PRD to the **architect** for technical feasibility
> assessment and implementation planning.
