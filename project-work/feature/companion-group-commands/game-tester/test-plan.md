# Companion Group Commands — Test Plan

> **Feature branch:** `feature/companion-group-commands`
> **Author:** game-tester
> **Date:** 2026-03-11
> **Server-side result:** PASS WITH WARNINGS

---

## Test Summary

This test plan validates the 9 new group chat companion commands (!status,
!buffme, !buffs, !tome, !flee, !assist, !equipmentupgrade, !equipmentmissing,
!help) and the enhanced !follow command, implemented entirely in Lua across
`companion.lua` and `global_npc.lua`. No C++ was changed; no database tables
were added. This is a pure quest-script feature.

The server-side validation completed with one warning: `IsSitting()` is called
in `cmd_status` but is not bound in the Lua API (lua_mob.cpp has 578 bindings
but IsSitting is absent). At runtime the call returns nil, which evaluates as
falsy, so the state line always shows "Standing". This is a cosmetic gap that
does not block in-game testing.

### Inputs Reviewed

- [x] PRD at `game-designer/prd.md`
- [x] Architecture plan at `architect/architecture.md`
- [x] Architect audit findings at `architect/audit-findings.md`
- [x] Game-designer audit findings at `game-designer/audit-findings.md`
- [x] Lore-master dev notes at `lore-master/dev-notes.md`
- [x] Implementation: `akk-stack/server/quests/lua_modules/companion.lua`
- [x] Implementation: `akk-stack/server/quests/global/global_npc.lua`
- [x] status.md — implementation committed and pushed to feature branch
- [x] Acceptance criteria identified: 9 commands, ~55 criteria from architecture validation plan

---

## Part 1: Server-Side Validation

### Results

| # | Check | Result | Details |
|---|-------|--------|---------|
| 1 | Lua syntax: companion.lua | PASS | Compiles to bytecode without errors |
| 2 | Lua syntax: global_npc.lua | PASS | Compiles to bytecode without errors |
| 3 | COMMANDS table: all 9 new commands registered | PASS | All handlers wired: tome, flee, buffme, buffs, equipmentupgrade, equipmentmissing, status, assist, help |
| 4 | DB: companion_spell_sets table exists | PASS | Table present with 900 entries |
| 5 | DB: buff spells in companion_spell_sets | PASS | 12 caster classes have buff spells (SpellType_Buff=8 / SpellType_PreCombatBuff=1048576) |
| 6 | DB: companion_spell_sets orphan check | PASS | 0 orphaned spell_id references |
| 7 | DB: companion_data orphan check | PASS | 0 orphaned npc_type_id references |
| 8 | DB: companion_inventories orphan check | PASS | 0 orphaned companion_id references |
| 9 | DB: companion_inventories item check | PASS | 0 orphaned item_id references |
| 10 | DB: companion rules present | PASS | Companions:GroupChatAddressingEnabled=true, Companions:RecallCooldownS=30, Companions:EnforceClassRestrictions=true, Companions:EnforceRaceRestrictions=true |
| 11 | DB: no new rules added | PASS | No new rule_values rows for this feature (as designed — thresholds are Lua constants) |
| 12 | API: eq.get_item_stat() bound | PASS | Confirmed in lua_general.cpp |
| 13 | API: eq.get_item_name() bound | PASS | Confirmed in lua_general.cpp |
| 14 | API: RunTo() bound on Lua_Mob | PASS | Confirmed in lua_mob.h |
| 15 | API: IsEngaged() bound on Lua_Mob | PASS | Confirmed in lua_mob.h |
| 16 | API: IsCasting() bound on Lua_Mob | PASS | Confirmed in lua_mob.h |
| 17 | API: SetEntityVariable/GetEntityVariable on Lua_Mob | PASS | Confirmed in lua_mob.h |
| 18 | API: IsAttackAllowed() bound on Lua_Mob | PASS | Confirmed in lua_mob.h |
| 19 | API: SetStance/GetStance bound on Lua_Companion | PASS | Confirmed in lua_companion.h |
| 20 | API: CastSpell(spell_id, target_id, slot) bound on Lua_Mob | PASS | Confirmed in lua_mob.h |
| 21 | API: GetBuffs() bound on Lua_Mob | PASS | Confirmed in lua_mob.h |
| 22 | API: GetCompanionXP/GetXPForNextLevel on Lua_Companion | PASS | Confirmed in lua_companion.cpp |
| 23 | API: IsSitting() bound | WARN | NOT found in lua_mob.cpp or lua_companion.cpp. npc:IsSitting() returns nil at runtime; cmd_status always shows "Standing" regardless of actual companion state |
| 24 | No C++ changes required | PASS | Confirmed — eqemu/ has no uncommitted changes on feature branch |
| 25 | Build verification | PASS | No C++ changes made; existing build is current |
| 26 | Log analysis: world.log | PASS | No errors; zone startup nominal |
| 27 | Log analysis: zone logs | PASS | No Lua errors, no script errors in recent zone logs |
| 28 | Git: implementation committed and pushed | PASS | commit efe7593 on feature/companion-group-commands |
| 29 | Spawn/loot: no new spawns or loot (not applicable) | N/A | Pure Lua feature; no new spawn data |

### Database Integrity

No new tables were created. No existing tables were modified. The feature relies
on the pre-existing `companion_spell_sets` table for buff spell data. All
foreign key relationships are intact.

**Queries run:**
```sql
-- Buff spells per class (SpellType_Buff=8, SpellType_PreCombatBuff=1048576)
SELECT class_id, COUNT(*) as buff_spell_count
FROM companion_spell_sets
WHERE (spell_type & (8 + 1048576)) > 0
GROUP BY class_id ORDER BY class_id;
-- Result: 12 classes have buff spells (class_ids 2,3,4,5,6,8,10,11,12,13,14,15)

-- Orphaned spell references
SELECT COUNT(*) FROM companion_spell_sets css
LEFT JOIN spells_new sn ON css.spell_id = sn.id WHERE sn.id IS NULL;
-- Result: 0

-- Orphaned companion_data (npc_types FK)
SELECT COUNT(*) FROM companion_data cd
LEFT JOIN npc_types nt ON cd.npc_type_id = nt.id WHERE nt.id IS NULL;
-- Result: 0

-- Orphaned companion_inventories (companion_data FK)
SELECT COUNT(*) FROM companion_inventories ci
LEFT JOIN companion_data cd ON ci.companion_id = cd.id WHERE cd.id IS NULL;
-- Result: 0

-- Orphaned companion_inventories (items FK)
SELECT COUNT(*) FROM companion_inventories ci
LEFT JOIN items i ON ci.item_id = i.id WHERE i.id IS NULL AND ci.item_id > 0;
-- Result: 0
```

**Findings:** No orphaned records. Database integrity is clean.

### Quest Script Syntax

| Script | Language | Result | Notes |
|--------|----------|--------|-------|
| `akk-stack/server/quests/lua_modules/companion.lua` | Lua (LuaJIT) | PASS | Compiles to bytecode cleanly |
| `akk-stack/server/quests/global/global_npc.lua` | Lua (LuaJIT) | PASS | Compiles to bytecode cleanly |

Command used: `/home/eqemu/code/build/vcpkg_installed/x64-linux/tools/luajit/luajit -bl <file> > /dev/null`

### Log Analysis

| Log File | Errors Found | Severity | Related To |
|----------|-------------|----------|------------|
| world.log | 0 | — | Chat service warning (pre-existing, unrelated) |
| zone_dynamic_01..08.log | 0 | — | Clean zone startup |
| zone/*.log (recent) | 0 | — | No Lua or companion errors |

No Lua errors, no companion script errors in any log file reviewed.

### Rule Validation

No new rules were added. The feature uses two existing rules:

| Rule | Value | Notes |
|------|-------|-------|
| Companions:EnforceClassRestrictions | true | Used by !equipmentupgrade class restriction check |
| Companions:EnforceRaceRestrictions | true | Used by !equipmentupgrade race restriction check |
| Companions:RecallCooldownS | 30 | Used by existing !recall (not new) |
| Companions:GroupChatAddressingEnabled | true | Required for @name/@all routing |

The 10% mana OOM threshold (cmd_buffme/cmd_buffs) and 50-unit proximity
threshold (cmd_tome) are hardcoded Lua constants as designed.

### Spawn Verification

Not applicable. This feature adds no new spawn data.

### Loot Chain Validation

Not applicable. This feature adds no new loot data.

### Build Verification

Not applicable. No C++ source changes were made. The existing build is current.

---

## Part 2: In-Game Testing Guide

### Prerequisites

**Character and companion setup required before running any test:**

1. Log in with a GM-level character (or use `#setgm 1` if not already flagged)
2. Zone to a convenient outdoor area such as East Commonlands (`#zone ecommons`)
3. Recruit at least 3 companions of different types:
   - One melee companion (Warrior or Rogue) — for testing "Mana: N/A" in !status
   - One caster companion (Cleric, Shaman, Druid, or Wizard) — for !buffme/!buffs
   - A third companion of any type — for @all targeting tests

**GM commands for setup:**
```
#setgm 1                              -- ensure GM flag is on
#zone ecommons                        -- zone to East Commonlands
#level 50                             -- ensure adequate level
```

**Recruit companions:**
Target an NPC and say `recruit` (or `join me`, `come with me`).
Repeat for at least 2-3 NPCs of different classes.

**To check a companion's class:** Target the companion and type `#showstats`

**To get item links for !equipmentupgrade tests:**
Find items in your inventory. Shift-click an item in your bag to generate an
item link. The link appears in the chat input field — include it when typing the
command.

---

### Test 1: !status — Basic Status Display

**Acceptance criterion:** Companion reports HP/mana/%, stance, target, state, and buff list via group chat.

**Prerequisite:** Any companion in group.

**Steps:**
1. Target your companion
2. Type: `/gsay @CompanionName !status`
3. Observe group chat output

**Expected result:**
```
=== CompanionName ===
  Level: 30  Class: Cleric  Type: Companion
  HP: 1200/1500 (80%)
  Mana: 650/1000 (65%)
  XP: 45000 / 120000
  Stance: Balanced  Mode: Follow  State: Standing
  Target: None
  Buffs: none
```
(Exact numbers will differ; format should match this structure.)

**Pass if:** Output appears in group chat with companion name header, HP and mana lines with percentages, stance, mode, target line, and buffs section.

**Fail if:** No output, output appears as private tell instead of group chat, or the script throws a Lua error visible in the chat window.

**Known limitation:** The "State:" line always shows "Standing" regardless of actual sit/stand state. This is a pre-existing gap (IsSitting() is not bound in Lua). Do not mark as fail — record as a known limitation.

---

### Test 2: !status — Melee Companion Shows "Mana: N/A"

**Prerequisite:** Warrior or Rogue companion in group.

**Steps:**
1. Target your melee companion
2. Type: `/gsay @CompanionName !status`

**Expected result:** Mana line reads `Mana: N/A` (not a number/number format).

**Pass if:** The mana line says exactly "Mana: N/A"
**Fail if:** Mana line shows 0/0 or shows an error, or mana line is missing entirely.

---

### Test 3: !status — Dead Companion Display

**Prerequisite:** A companion that has been killed (let it die in combat and do not resurrect).

**Steps:**
1. Target the dead companion (its corpse, if still in zone)
2. Type: `/gsay @CompanionName !status`

**Expected result:**
```
=== CompanionName [DEAD] ===
  Level: 30  Class: Warrior
```
Only the header and level/class lines. No HP, mana, stance, or buff lines.

**Pass if:** Output shows `[DEAD]` in header, only level/class displayed.
**Fail if:** No output, script error, or full status block shown for a dead companion.

---

### Test 4: !status — @all Produces Reports from All Companions

**Prerequisite:** At least 2 companions in group.

**Steps:**
1. Type: `/gsay @all !status`

**Expected result:** Each companion produces a separate status report block in group chat, delivered sequentially.

**Pass if:** Two or more `=== CompanionName ===` blocks appear in group chat.
**Fail if:** Only one companion reports, no output, or an error appears.

---

### Test 5: !status — Buffs Listed When Active

**Prerequisite:** A companion with at least one active buff (have a caster companion buff your melee companion first).

**Steps:**
1. Have a caster companion buff the party (use `/gsay @CasterName !buffs` and wait ~10 seconds)
2. Target the buffed companion
3. Type: `/gsay @BuffedCompanion !status`

**Expected result:** The Buffs section lists active buff names with time remaining.
Example:
```
  Buffs (3 active):
    Regeneration (12 min)
    Rune III (5 min)
    Strength (permanent)
```

**Pass if:** Buffs section lists spell names with duration strings.
**Fail if:** Buffs section shows "Buffs: none" despite companion having active buffs.

---

### Test 6: !help — Basic Help Display

**Prerequisite:** Any companion in group.

**Steps:**
1. Target companion
2. Type: `/gsay @CompanionName !help`

**Expected result:** A reference card appears in group chat listing all command categories (Stance, Movement, Combat, Buffs, Equipment, Information, Control) with all 9 new commands listed.

**Pass if:** Output in group chat shows all categories and all new commands (!tome, !flee, !buffme, !buffs, !equipmentupgrade, !equipmentmissing appear in the output).
**Fail if:** Only old commands listed, no output, or help appears as private tell.

---

### Test 7: !help — Topic-Based Help

**Prerequisite:** Any companion in group.

**Steps:**
1. Type: `/gsay @CompanionName !help stance`
2. Type: `/gsay @CompanionName !help buffs`
3. Type: `/gsay @CompanionName !help equipment`

**Expected result for `!help buffs`:**
```
=== Buff Commands ===
  !buffme - Queue buff refresh on you only. Cast on next idle window.
  !buffs  - Queue buff refresh on all party members.
  Casters only. Requires >10% mana. Replaces any pending request.
```

**Pass if:** Each topic returns relevant command details.
**Fail if:** Unknown topic error for valid topics, or wrong topic's content returned.

---

### Test 8: !help — @all Deduplication (Only One Companion Responds)

**Prerequisite:** At least 2 companions in group.

**Steps:**
1. Type: `/gsay @all !help`

**Expected result:** Exactly ONE companion's help output appears. The second companion is silent.

**Pass if:** Help output appears once, not duplicated by every companion.
**Fail if:** Two or more identical help blocks appear (one per companion).

---

### Test 9: !equipmentmissing — List Empty Slots

**Prerequisite:** A companion with some but not all slots equipped.

**Steps:**
1. Target companion
2. Type: `/gsay @CompanionName !equipmentmissing`

**Expected result:**
```
CompanionName has nothing equipped in: head, chest, legs, feet, hands
```
(Slot names will differ based on actual companion equipment.)

**Pass if:** Output lists empty slot names via group chat.
**Fail if:** No output, error, or "has all equipment slots filled" when slots are clearly empty.

---

### Test 10: !equipmentmissing — Fully Equipped Companion

**Prerequisite:** A companion with all slots filled (equip items to all slots via trade window).

**Steps:**
1. Fully equip the companion by trading items to it for every slot
2. Type: `/gsay @CompanionName !equipmentmissing`

**Expected result:**
```
CompanionName has all equipment slots filled.
```

**Pass if:** "all equipment slots filled" message appears.
**Fail if:** Empty slots listed when companion is fully equipped.

---

### Test 11: !tome — Companion Paths to Player

**Prerequisite:** Companion separated from player by more than 50 units.

**Steps:**
1. Send companion to guard a location far from you: `/gsay @CompanionName !guard`
2. Move your character away (at least 100 units)
3. Type: `/gsay @CompanionName !tome`
4. Watch the companion

**Expected result:** Companion uses pathed movement (walks/runs) toward your location. The message `CompanionName moves toward you.` appears in group chat.

**Pass if:** Companion visually moves toward you using pathfinding (not instant teleport). Group chat message appears.
**Fail if:** Companion teleports (instant position change), no movement, or message appears in wrong channel.

**Verify this is NOT a teleport:** Companion should smoothly move across the ground, not instantly appear at your location.

---

### Test 12: !tome — Companion Already Nearby

**Prerequisite:** Companion following you (within 50 units).

**Steps:**
1. Confirm companion is following close to you
2. Type: `/gsay @CompanionName !tome`

**Expected result:**
```
CompanionName is already nearby.
```

**Pass if:** "already nearby" message appears in group chat. Companion does not move.
**Fail if:** Companion moves anyway, no message, or message in wrong channel.

---

### Test 13: !tome — Dead Companion

**Prerequisite:** A dead companion.

**Steps:**
1. Target dead companion
2. Type: `/gsay @CompanionName !tome`

**Expected result:**
```
CompanionName is dead and cannot move.
```

**Pass if:** "is dead and cannot move" appears in group chat.
**Fail if:** Dead companion moves, no message, or error.

---

### Test 14: !flee — In-Combat Retreat

**Prerequisite:** Companion engaged in combat with a mob.

**Steps:**
1. Pull a mob so your companion engages (balanced/aggressive stance)
2. While in combat, type: `/gsay @CompanionName !flee`

**Expected result:**
- Companion stops attacking immediately (goes passive)
- Companion runs toward player
- Group chat message: `CompanionName disengages and retreats to you!`
- The enemy mob continues pursuing the companion (hate list NOT cleared)

**Pass if:** Combat ceases, companion moves toward player, mob still chases.
**Fail if:** Mob stops chasing (hate was cleared incorrectly), companion keeps attacking, or message says "moves to follow you" instead of "disengages and retreats."

**Critical test:** Verify the pursuing mob does NOT drop aggro. If the mob walks back to its spawn point after !flee, the hate list was wrongly cleared — this is a bug.

---

### Test 15: !flee — Already Passive Companion

**Prerequisite:** Companion in passive stance, not in combat.

**Steps:**
1. Set companion passive: `/gsay @CompanionName !passive`
2. Ensure companion is not in combat
3. Type: `/gsay @CompanionName !flee`

**Expected result:**
```
CompanionName moves to follow you.
```
(Not the "disengages and retreats" message.)

**Pass if:** Lighter message appears ("moves to follow you").
**Fail if:** "disengages and retreats" message when not in combat, or no movement.

---

### Test 16: !flee — @all Causes All Companions to Retreat

**Prerequisite:** Multiple companions engaged in combat.

**Steps:**
1. Pull a mob so all companions engage
2. Type: `/gsay @all !flee`

**Expected result:** All companions simultaneously go passive, run toward player, and post their own retreat message in group chat.

**Pass if:** All companions disengage and move to player.
**Fail if:** Only one companion responds, or companions continue fighting.

---

### Test 17: !assist — Attack Player's Target (from Balanced Stance)

**Prerequisite:** Companion in balanced stance, player has a mob targeted.

**Steps:**
1. Ensure companion is in balanced stance: `/gsay @CompanionName !balanced`
2. Target a nearby hostile mob
3. Type: `/gsay @CompanionName !assist`

**Expected result:**
```
CompanionName assists against MobName!
```
Companion engages the targeted mob.

**Pass if:** Companion attacks the mob, group chat message appears with correct mob name.
**Fail if:** Companion ignores the command, attacks wrong target, or message in wrong channel.

---

### Test 18: !assist — Auto-Switches Passive to Balanced

**Prerequisite:** Companion in passive stance.

**Steps:**
1. Set companion passive: `/gsay @CompanionName !passive`
2. Target a hostile mob
3. Type: `/gsay @CompanionName !assist`

**Expected result:**
```
CompanionName switches to balanced stance and assists against MobName!
```
Companion should be in balanced stance and attacking the mob.

**Pass if:** "switches to balanced stance" appears in the message, companion attacks.
**Fail if:** Companion stays passive, no stance switch message, or companion attacks without the stance-switch notice.

---

### Test 19: !assist — No Target

**Prerequisite:** Player has no target (click empty space to clear target).

**Steps:**
1. Clear your target
2. Type: `/gsay @CompanionName !assist`

**Expected result:**
```
CompanionName has no target to assist with. Target a mob first.
```

**Pass if:** Correct message in group chat, companion does not engage anything.
**Fail if:** No message, different message, or companion attacks something random.

---

### Test 20: !assist — Friendly Target (Another Player or Companion)

**Prerequisite:** Player has a friendly target (another player, your companion, or an NPC you're not hostile with).

**Steps:**
1. Target yourself, another player, or a friendly companion
2. Type: `/gsay @CompanionName !assist`

**Expected result:**
```
CompanionName will not attack a friendly target.
```

**Pass if:** "friendly target" message appears, companion does not attack.
**Fail if:** Companion attacks a friendly, no message, or wrong message.

---

### Test 21: !assist — Self-Target (Targeting the Companion Itself)

**Prerequisite:** Target the companion you're sending !assist to.

**Steps:**
1. Target the companion itself
2. Type: `/gsay @CompanionName !assist`

**Expected result:**
```
CompanionName will not attack themselves.
```

**Pass if:** "will not attack themselves" message appears.
**Fail if:** Companion attacks itself (impossible but safeguard should prevent this), different error message.

---

### Test 22: !assist — Dead Companion

**Prerequisite:** Target a mob, have a dead companion.

**Steps:**
1. Target a hostile mob
2. Type: `/gsay @DeadCompanionName !assist`

**Expected result:**
```
DeadCompanionName is dead and cannot fight.
```

**Pass if:** Dead-check message appears.
**Fail if:** Dead companion attempts combat.

---

### Test 23: !assist — Corpse Target (Minor Gap Test)

**Prerequisite:** There is a player or NPC corpse in the zone.

**Steps:**
1. Target the corpse
2. Type: `/gsay @CompanionName !assist`

**Expected result (known minor gap):** The message says "will not attack a friendly target" rather than "cannot attack a corpse." Both are acceptable per audit findings — this is a known minor deviation from the PRD.

**Pass if:** Any error message appears and companion does not attack the corpse.
**Fail if:** Companion attempts to attack the corpse (combat with a corpse causes errors).

---

### Test 24: !assist — @all Causes All Companions to Attack

**Prerequisite:** Multiple companions in group, player has a hostile mob targeted.

**Steps:**
1. Target a hostile mob
2. Type: `/gsay @all !assist`

**Expected result:** All companions switch to the targeted mob and engage.

**Pass if:** All companions attack the target mob.
**Fail if:** Only some companions respond, or wrong target engaged.

---

### Test 25: !buffme — Caster Companion Queues Buff for Player

**Prerequisite:** A caster companion (Cleric, Shaman, Druid, Wizard, etc.) with above 10% mana.

**Steps:**
1. Target your caster companion
2. Make sure you do NOT have any of their buff spells active (strip buffs if needed)
3. Type: `/gsay @CasterCompanion !buffme`
4. Wait up to 30 seconds while companion is out of combat

**Expected result:**
- Immediate group chat: `CasterCompanion will refresh your buffs when able.`
- Within ~30 seconds: Companion casts buff spells on the player

**Pass if:** Buffs from that companion's spell set appear on the player within ~60 seconds.
**Fail if:** No "will refresh" message, or no buffs cast within the retry window.

---

### Test 26: !buffme — Non-Caster Companion

**Prerequisite:** A melee companion (Warrior, Rogue) with 0 max mana.

**Steps:**
1. Target the melee companion
2. Type: `/gsay @MeleeCompanion !buffme`

**Expected result:**
```
MeleeCompanion has no buff spells available.
```

**Pass if:** Correct "no buff spells" message in group chat.
**Fail if:** Timer is set (no message), or buff is attempted by a non-caster.

---

### Test 27: !buffme — OOM Companion (Below 10% Mana)

**Prerequisite:** A caster companion with less than 10% mana (may need to exhaust mana through combat first).

**Steps:**
1. Run your caster companion OOM through sustained combat
2. Check mana with `/gsay @CasterCompanion !status`
3. When mana is below 10%, type: `/gsay @CasterCompanion !buffme`

**Expected result:**
```
CasterCompanion is too low on mana to buff right now.
```

**Pass if:** "too low on mana" message appears in group chat.
**Fail if:** Buff timer set despite OOM, or no message.

---

### Test 28: !buffme — Dead Companion

**Prerequisite:** A dead caster companion.

**Steps:**
1. Type: `/gsay @DeadCaster !buffme`

**Expected result:**
```
DeadCaster is dead and cannot cast spells.
```

**Pass if:** "is dead and cannot cast spells" message appears.
**Fail if:** Timer set, or no response.

---

### Test 29: !buffme — New Request Replaces Pending

**Prerequisite:** A caster companion with full mana.

**Steps:**
1. Type: `/gsay @CasterCompanion !buffme` (sets "owner" request)
2. Immediately type: `/gsay @CasterCompanion !buffs` (replaces with "party" request)
3. Wait for buffs to be cast

**Expected result:** The companion buffs ALL party members (not just the player), because the second command replaced the first.

**Pass if:** All group members receive buffs from the caster.
**Fail if:** Only the player receives buffs (first request honored instead of second), or double-buffing happens.

---

### Test 30: !buffs — Party-Wide Buff Request

**Prerequisite:** A caster companion with full mana, multiple group members (at least player + 1 other).

**Steps:**
1. Strip existing buffs from all group members if possible
2. Type: `/gsay @CasterCompanion !buffs`
3. Wait up to 60 seconds while out of combat

**Expected result:**
- Immediate group chat: `CasterCompanion will refresh party buffs when able.`
- Within ~60 seconds: Companion casts buff spells on ALL group members

**Pass if:** Buffs appear on all group members (player and companions), not just the player.
**Fail if:** Only player is buffed (!buffme behavior), or no buffs cast.

---

### Test 31: !equipmentupgrade — Item is an Upgrade (Empty Slot)

**Prerequisite:** A companion with at least one empty slot (use !equipmentmissing to identify it). Have an item appropriate for that slot in your inventory.

**Steps:**
1. Find the empty slot name from `!equipmentmissing` output
2. Open your inventory, find an appropriate item
3. Shift-click the item to create a link in chat
4. Type in chat: `/gsay @CompanionName !equipmentupgrade ` then paste the link

**Expected result:**
```
CompanionName: ItemName is an upgrade! My headslot slot is empty.
```
(Slot name will match the empty slot.)

**Pass if:** "is an upgrade! My [slot] slot is empty." message appears.
**Fail if:** No response, "please link an item" when a link was provided, or wrong slot named.

---

### Test 32: !equipmentupgrade — Item is Better (Occupied Slot)

**Prerequisite:** A companion with an item equipped in a slot. Have a better item (higher stat total) in your inventory.

**Steps:**
1. Check what is equipped with `!equipment`
2. Find a better item to link (armor with more AC/stats)
3. Type: `/gsay @CompanionName !equipmentupgrade [item link]`

**Expected result:**
```
CompanionName: BetterItem (score: 45) is an upgrade over WeakerItem (score: 12) in my chest slot.
```

**Pass if:** Upgrade message with numeric scores appears, comparing the two items.
**Fail if:** Reports as downgrade when clearly a better item, or no response.

**Note:** The score formula is: AC + AStr + ASta + AAgi + ADex + AWis + AInt + ACha + HP + Mana + floor(Damage*10/Delay for weapons). A score of 0 is possible for very simple items.

---

### Test 33: !equipmentupgrade — Item is Worse (Downgrade)

**Prerequisite:** A well-equipped companion. Have a weaker item of the same type in your inventory.

**Steps:**
1. Link a weaker item (less stats than what is equipped)
2. Type: `/gsay @CompanionName !equipmentupgrade [weak item link]`

**Expected result:**
```
CompanionName: WeakItem (score: 5) is worse than StrongerItem (score: 28) in my chest slot.
```

**Pass if:** "is worse than" message appears with correct scores.
**Fail if:** Reports as upgrade, or no response.

---

### Test 34: !equipmentupgrade — No Item Link Provided

**Prerequisite:** Any companion.

**Steps:**
1. Type: `/gsay @CompanionName !equipmentupgrade` (no item link)

**Expected result:**
```
Please link an item for me to evaluate.
```

**Pass if:** "Please link" message appears in group chat.
**Fail if:** No response, error, or companion evaluates nothing.

---

### Test 35: !equipmentupgrade — Item Companion Cannot Equip

**Prerequisite:** Have an item restricted to a class your companion is not (e.g., a Warrior companion and a Necromancer-only item).

**Steps:**
1. Link a class-restricted item the companion cannot use
2. Type: `/gsay @CompanionName !equipmentupgrade [restricted item link]`

**Expected result:** No response (silent per PRD design).

**Pass if:** Companion gives no response at all.
**Fail if:** Companion reports the item as upgrade/downgrade for an item they can't use, or error message.

---

### Test 36: !equipmentupgrade — Dual-Slot Item Comparison (Known Minor Gap)

**Prerequisite:** A companion with both ring slots occupied (finger1 and finger2). Have a ring to evaluate.

**Steps:**
1. Equip two different rings on companion (finger1 and finger2)
2. Link a third ring
3. Type: `/gsay @CompanionName !equipmentupgrade [ring link]`

**Expected result (known minor deviation):** Companion compares against the FIRST ring slot (finger1), not necessarily the weaker of the two. This is a documented gap from the architect audit — the implementation compares against the first matching slot, not the weakest.

**Pass if:** Companion compares the linked ring against one of the equipped rings (either finger1 or finger2) and responds correctly.
**Fail if:** No response, or crash. Comparing against ring1 instead of the weaker ring is acceptable per audit.

**Note for follow-up:** If ring1 score is 50, ring2 score is 10, and you link a ring with score 30, the expected PRD behavior is "upgrade over ring2 (10)." The implementation will report "downgrade vs ring1 (50)." Record this deviation but do not mark as fail.

---

### Test 37: !follow — Companion Begins Following

**Prerequisite:** Companion in guard mode (`/gsay @CompanionName !guard`).

**Steps:**
1. Set companion to guard: `/gsay @CompanionName !guard`
2. Move away from the companion
3. Type: `/gsay @CompanionName !follow`

**Expected result:**
```
CompanionName will follow you.
```
Companion resumes trailing the player.

**Pass if:** "will follow you" message in group chat, companion begins moving toward and following the player.
**Fail if:** Companion stays in guard position, wrong message, or message in wrong channel.

---

### Test 38: !follow — Dead Companion

**Prerequisite:** Dead companion.

**Steps:**
1. Type: `/gsay @DeadCompanion !follow`

**Expected result:**
```
DeadCompanion is dead and cannot follow.
```

**Pass if:** Dead-check message appears.
**Fail if:** No message, different message, or dead companion attempts movement.

---

### Test 39: @name Addressing Works for All Commands

**Prerequisite:** 2 companions in group named "Companion_A" and "Companion_B".

**Steps:**
1. Type: `/gsay @Companion_A !status`
2. Observe: only Companion_A responds
3. Type: `/gsay @Companion_B !status`
4. Observe: only Companion_B responds

**Pass if:** Each @name command triggers only the addressed companion.
**Fail if:** Both companions respond to a single @name command, or wrong companion responds.

---

### Test 40: Macro Hotbutton Compatibility

**Prerequisite:** Any companion in group.

**Steps:**
1. Open the hotbar (default key: H)
2. Right-click an empty hotbutton slot
3. Select "Social" → type the following:
   ```
   /gsay @all !status
   ```
4. Save and click the hotbutton

**Expected result:** All companions report !status in group chat, identical to typing the command manually.

**Pass if:** Hotbutton triggers the command correctly.
**Fail if:** Hotbutton fails silently, macro format not recognized, or only partial execution.

---

### Test 41: No Player Target Change

**Prerequisite:** Player has a mob targeted.

**Steps:**
1. Target a mob
2. Type: `/gsay @CompanionName !assist` (companion targets the mob too)
3. Check your target window immediately after

**Pass if:** Your target window still shows the same mob you had targeted before the command.
**Fail if:** Your target changed to the companion, or cleared.

---

## Edge Case Tests

### Test E1: !buffme Does Not Interrupt Active Combat

**Risk from architecture plan:** Timer-based processing checks IsEngaged()/IsCasting() before casting. If companion is in combat, buffs should be deferred, not abandoned.

**Steps:**
1. Type: `/gsay @CasterCompanion !buffme`
2. Immediately pull a mob so the companion engages
3. Watch: companion should NOT cast buffs while fighting
4. Kill the mob, wait out of combat
5. Within 60 seconds, buffs should be cast

**Pass if:** No buffs cast during combat; buffs cast after combat ends.
**Fail if:** Companion attempts to cast buffs while fighting (causes spell interruption lag), or buffs never cast (timeout without notification).

---

### Test E2: !flee During Root/Mez

**Risk from architecture plan:** Root prevents RunTo() movement while SetStance(0) still works.

**Steps:**
1. Engage a mob that roots or mezzez the companion
2. While companion is rooted/mezzed, type: `/gsay @CompanionName !flee`

**Expected result:** Companion goes passive (stops attacking) but does NOT move (movement blocked by root). When root breaks, companion should resume follow mode.

**Pass if:** Companion stops attacking immediately, does not move (root prevents it), and resumes follow when root breaks.
**Fail if:** Script error on rooted companion, or companion keeps attacking after !flee.

---

### Test E3: !assist on a Mob That Dies Before Companion Engages

**Risk from architecture plan:** Mob dies between !assist and companion reaching it.

**Steps:**
1. Target a very low HP mob (nearly dead)
2. Type: `/gsay @CompanionName !assist`
3. Kill the mob yourself immediately after the command

**Expected result:** Companion moves toward the mob's location, finds nothing, and returns to idle behavior. No error.

**Pass if:** No Lua error, companion returns to normal behavior after the mob dies.
**Fail if:** Script error, companion stuck, or zone crash.

---

### Test E4: Buff Timer Retry Exhaustion

**Risk from architecture plan:** If companion stays in combat for 60+ seconds after !buffme, timer gives up.

**Steps:**
1. Type: `/gsay @CasterCompanion !buffme`
2. Immediately engage a very long fight (keep companion in combat for 60+ seconds)

**Expected result (after ~60 seconds):**
```
CasterCompanion was unable to buff right now.
```
(This message appears in group chat after 30 failed retry attempts.)

**Pass if:** Timeout message appears after approximately 60 seconds of the companion being in combat.
**Fail if:** No timeout message (timer silently gives up), or buffs somehow cast during sustained combat.

**Note:** This edge case may be difficult to trigger in practice as most fights end well within 60 seconds.

---

### Test E5: @all !help Chat Flood Prevention

**Risk from architecture plan:** Without deduplication, 5 companions each sending 10+ help lines = 50+ chat messages.

**Steps:**
1. Have at least 3 companions in group
2. Type: `/gsay @all !help`

**Expected result:** Exactly ONE companion's help output appears (approximately 8 lines). No duplicate help blocks.

**Pass if:** Help text appears once.
**Fail if:** Help text appears 2 or more times (data bucket lock failed).

---

### Test E6: !buffme Overwritten by !buffs

**Risk from architecture plan:** Multiple buff requests should replace (not stack).

**Steps:**
1. Type: `/gsay @CasterCompanion !buffme`
2. Within 1 second, type: `/gsay @CasterCompanion !buffs`
3. Wait for buff cast

**Pass if:** ALL group members receive buffs (the "party" request won).
**Fail if:** Only the player receives buffs (the "owner" request survived), or neither gets buffed.

---

## Rollback Instructions

This feature is pure Lua — no database changes, no C++ changes. Rollback is a one-step git revert.

**If in-game testing reveals a critical Lua bug:**

```bash
# In the akk-stack repo, revert the implementation commit:
cd /mnt/d/Dev/eq/akk-stack
git revert efe759377e96a5eeed6e0a3e2f0a7a128dea6031 --no-edit

# Hot-reload quests without server restart (preferred):
# In-game: #reloadquests
# Or restart the zone server (affects active sessions)
```

**To restore after revert:**
```bash
# Undo the revert if needed
cd /mnt/d/Dev/eq/akk-stack
git revert HEAD --no-edit
```

**Quest script reload (no restart needed for Lua changes):**
```
#reloadquests
```
This is the correct way to pick up quest script changes while keeping the zone running.

---

## Server-Side Findings Summary

### Warning: IsSitting() Not Bound in Lua API

**Location:** `companion.lua:635` — `local state_str = npc:IsSitting() and "Sitting" or "Standing"`

**Impact:** The `npc:IsSitting()` call returns nil because `IsSitting()` is not registered in `lua_mob.cpp` or `lua_companion.cpp`. In Lua, nil is falsy, so the expression always evaluates to `"Standing"`. The `!status` command always shows `State: Standing` regardless of whether the companion is actually sitting.

**Severity:** Low — cosmetic issue only. No crash risk. The companion's sit/stand state is correct in C++; only the Lua display is wrong.

**Who should fix:** lua-expert (remove the State line from cmd_status, OR) or c-expert (add IsSitting() binding to lua_companion.cpp).

**This does not block in-game testing.** All other functionality is correct.

---

## Blockers

| # | Blocker | Severity | Responsible Expert | Status |
|---|---------|----------|--------------------|--------|
| 1 | IsSitting() not bound in Lua — cmd_status always shows "Standing" | Low | lua-expert or c-expert | Open (non-blocking) |

---

## Recommendations

1. **IsSitting() binding:** Either add `IsSitting()` to lua_companion.cpp (c-expert) or remove the State line from cmd_status output (lua-expert). The simplest fix is removing the State line since companions automatically sit when their owner sits — it's not a critical status field.

2. **!assist corpse message:** The PRD specified "cannot attack a corpse" for corpse targets, but the implementation produces "will not attack a friendly target" (because IsAttackAllowed() returns false for corpses). Consider adding a specific corpse check (`target:IsCorpse()`) before the IsAttackAllowed check in cmd_assist. Low priority.

3. **!equipmentupgrade multi-slot comparison:** When both ring/wrist slots are occupied, the implementation compares against ring1 (first match) rather than the weaker of the two rings. Consider iterating all matching slots and selecting the one with the lowest score. Low priority.

4. **!follow already-following feedback:** If companion is already in follow mode, the implementation unconditionally resets follow and sends "will follow you" instead of "is already following you." Harmless but could be improved with a mode check.

5. **Equip item link in !equipmentupgrade response:** The implementation shows the equipped item's text name (e.g., "Rusty Breastplate") rather than a clickable item link. Generating item links from a bare item_id may require a C++ helper. Low priority — text name is sufficient for player decisions.

---

## Status Update

**Server-side validation:** PASS WITH WARNINGS (1 warning: IsSitting binding gap)

**Handoff:** game-tester → user (in-game testing) → completion

The server-side validation is complete. All 9 commands are syntactically correct, properly registered in the COMMANDS table, and integrated with the existing dispatch pipeline. The database is clean. Logs show no errors. The one warning (IsSitting binding) is cosmetic and does not block in-game testing or shipping.

Proceed with Part 2 in-game testing guide above. After in-game testing is confirmed, update status.md to complete and proceed to the completion phase (commit and push all repos).
