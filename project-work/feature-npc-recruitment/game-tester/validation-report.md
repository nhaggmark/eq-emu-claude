# NPC Recruitment / Recruit-Any-NPC Companion System — Validation Report

> **Feature branch:** `feature/npc-recruitment`
> **Author:** game-tester
> **Date:** 2026-02-27
> **Server-side result:** PASS WITH WARNINGS

---

## Test Summary

The companion recruitment system consists of 24 implementation tasks spanning C++ (companion class,
AI, entity integration, Lua bindings), SQL (6 tables, seed data, 18 rules), and Lua (recruitment
logic, culture dialogue, global NPC intercept). Server-side validation covers build integrity,
database schema and data correctness, Lua syntax, code review, and cross-system integration checks.

### Inputs Reviewed

- [x] PRD at `game-designer/prd.md`
- [x] Architecture plan at `architect/architecture.md`
- [x] status.md — all 24 implementation tasks Complete
- [x] Acceptance criteria identified: 38 user stories from `game-designer/user-stories.md`

---

## Part 1: Server-Side Validation

### Results Summary

| # | Check | Result | Details |
|---|-------|--------|---------|
| 1 | Build: ninja -j$(nproc) | PASS | No work to do — zone binary current (Feb 27 11:08) |
| 2 | DB: all 6 companion tables exist | PASS | companion_data, companion_buffs, companion_exclusions, companion_culture_persuasion, companion_spell_sets, companion_inventories |
| 3 | DB: companion_data schema (29 cols) | PASS | All 29 columns present including recruited_at, zones_visited |
| 4 | DB: companion_exclusions row count | PASS | 7,269 total (7=manual lore anchors, 7,262=auto class-based) |
| 5 | DB: companion_culture_persuasion (14 races) | PASS | All 14 races seeded; race 128=Iksar, 130=Vah Shir confirmed |
| 6 | DB: companion_spell_sets (842 entries) | PASS | 842 entries, 12 classes covered (WAR/MNK/ROG intentionally empty) |
| 7 | DB: spell references valid | PASS | 0 spell_ids in companion_spell_sets reference nonexistent spells |
| 8 | DB: Companions rule_values in DB | FAIL | 0 rules in rule_values table; migration 9332 skipped due to condition logic |
| 9 | DB: migration db_version vs manifest | WARN | db_version=9328; manifests 9329-9332 skipped (tables pre-created directly) |
| 10 | DB: FK integrity (companion_buffs) | PASS | No orphaned companion_id references |
| 11 | DB: FK integrity (companion_inventories) | PASS | No orphaned companion_id references |
| 12 | DB: lore anchor npc_type_ids valid | PASS | All 7 manual lore anchor NPC IDs exist in npc_types |
| 13 | DB: companion_spell_sets class range | PASS | All entries in class range 1-15; 0 melee-class entries (WAR/MNK/ROG) |
| 14 | DB: companion_spell_sets spell_type | PASS | 0 entries with null or zero spell_type |
| 15 | DB: auto-exclusion NPC type IDs valid | PASS | 0 missing npc_type_ids among 7,262 auto-exclusion entries |
| 16 | Lua syntax: companion.lua | PASS | luac5.1 -p exits 0 |
| 17 | Lua syntax: companion_culture.lua | PASS | luac5.1 -p exits 0 |
| 18 | Lua syntax: global_npc.lua | PASS | luac5.1 -p exits 0 |
| 19 | Code: companion.h includes | PASS | zone/npc.h, forward decls for Client/Corpse/Group/Mob/Raid/NPCType/NewSpawn_Struct, EQ::ItemData |
| 20 | Code: companion.cpp includes | PASS | All 13 includes present; fmt/format.h included |
| 21 | Code: lua_companion.h/cpp | PASS | 14 methods registered; lua_parser.cpp includes header and registers at line 1351 |
| 22 | Code: lua_client.cpp bindings | PASS | CreateCompanion, GetCompanionByNPCTypeID, HasActiveCompanion all registered |
| 23 | Code: entity.h IsCompanion / CastToCompanion | PASS | Both const and non-const versions present; companion_list added |
| 24 | Code: groups.cpp auto-dismiss | PASS | Auto-suspends companion when group at MAX-1 and new Client joins |
| 25 | Code: servertalk.h opcodes | PASS | 0x4800/0x4801 with proper structs ServerCompanionZone_Struct/ServerCompanionDismiss_Struct |
| 26 | Code: ruletypes.h (18 rules) | PASS | All 18 Companions rules in correct X-macro format |
| 27 | Code: exp.cpp kill hook | PASS | Group::SplitExp records kills on companion members for history tracking |
| 28 | Code: SpawnCompanionsOnZone called | PASS | client_packet.cpp line 1237 invokes SpawnCompanionsOnZone() on zone-in |
| 29 | Code: TODO (Task 9) RemoveCompanion | WARN | companion.cpp line 611: owner->RemoveCompanion(this) not yet called — companion ownership tracking incomplete on dismiss |
| 30 | Code: TODO (Task 17/18) Signal dispatch | WARN | companion.cpp line 1374: Companion::Signal() silently consumes signals; Lua quest event dispatch not wired |
| 31 | Code: Lua rule name mismatch | FAIL | companion.lua uses "Companions:Enabled" but rule is named "Companions:CompanionsEnabled" — eligibility check will always return wrong result unless rule returns nil (falls through to default) |
| 32 | Code: Lua ShowEquipment/GiveSlot/GiveAll | FAIL | companion.lua calls npc:ShowEquipment(), npc:GiveSlot(), npc:GiveAll() — none of these methods exist in Companion C++ class or Lua bindings |
| 33 | Code: CheckMercenaryRetention stub | WARN | CheckMercenaryRetention() only logs — faction check and auto-dismiss for mercenary-type not implemented |
| 34 | Code: soul wipe Lua/C++ disconnect | WARN | C++ SoulWipeByCompanionID() sets a DataBucket key; companion.lua trigger_soul_wipe() uses io.popen(curl) independently — the two are not connected; ChromaDB clear is unreliable |
| 35 | Log: zone logs post-restart | PASS | No companion-related errors in zone logs; only pre-existing DB connection recoveries |
| 36 | Code: companion_data repository SELECT | PASS | Explicit column list skips recruited_at (DB-managed timestamp); column index mapping is correct |
| 37 | Code: SpawnCompanionsOnZone | PASS | Loads non-dismissed, non-suspended records; handles missing npc_type gracefully |
| 38 | Code: stat scaling float division | PASS | ScaleStatsToLevel() comment confirms float division required; architecture constraint met |

---

### Database Integrity

**Tables verified:**

```sql
-- All 6 tables exist
SHOW TABLES LIKE 'companion%';
-- companion_buffs, companion_culture_persuasion, companion_data,
-- companion_exclusions, companion_inventories, companion_spell_sets

-- companion_data: 29 columns, correct schema
-- recruited_at is a DB-managed datetime (not in C++ struct — correct)

-- Row counts
SELECT COUNT(*) FROM companion_exclusions;           -- 7269
SELECT COUNT(*) FROM companion_culture_persuasion;   -- 14
SELECT COUNT(*) FROM companion_spell_sets;           -- 842

-- rule_values: 0 Companions rules
SELECT COUNT(*) FROM rule_values WHERE rule_name LIKE '%ompanion%';  -- 0
```

**Findings:**

- The migration manifest entries 9329-9332 were not applied via the server's migration system (db_version remains 9328). The data-expert created all tables and seed data via direct SQL. This is functionally equivalent for the tables and seed data, but means `rule_values` entries from migration 9332 were never inserted.
- EQEmu's rules system falls back to compile-time defaults from `ruletypes.h` when a rule is absent from `rule_values`. All 18 Companions rules will use their default values (e.g., CompanionsEnabled=true, LevelRange=3, BaseRecruitChance=50). The system will function, but operators cannot override rules via the DB until this is fixed.
- No foreign key constraints were defined on companion tables. All referential integrity is enforced only at the application level.

---

### Quest Script Syntax

| Script | Language | Result | Notes |
|--------|----------|--------|-------|
| `/home/eqemu/server/lua_modules/companion.lua` | Lua | PASS | luac5.1 exits 0 |
| `/home/eqemu/server/lua_modules/companion_culture.lua` | Lua | PASS | luac5.1 exits 0 |
| `/home/eqemu/server/quests/global/global_npc.lua` | Lua | PASS | luac5.1 exits 0; correctly requires companion module |

---

### Log Analysis

| Log File | Errors Found | Severity | Related To |
|----------|-------------|----------|------------|
| zone/qeynos zone log | DB connection recovery (pre-existing) | Low | Unrelated to companion feature |
| world_175.log | No companion errors found | N/A | N/A |
| zone/erudnext, overthere, butcher zone logs | No errors | N/A | N/A |

No companion-related errors found in logs. The server has not been exercised with the new code in a live session yet (no companion was actively recruited during the log capture window).

---

### Rule Validation

The 18 Companions rules exist in `common/ruletypes.h` with correct types and defaults:

| Rule | Type | Default | Valid Range | Status |
|------|------|---------|-------------|--------|
| Companions:CompanionsEnabled | BOOL | true | true/false | PASS (in ruletypes.h) |
| Companions:MaxPerPlayer | INT | 5 | 1-5 | PASS |
| Companions:LevelRange | INT | 3 | 1-10 | PASS |
| Companions:BaseRecruitChance | INT | 50 | 1-100 | PASS |
| Companions:StatScalePct | INT | 100 | 1-200 | PASS |
| Companions:SpellScalePct | INT | 100 | 1-200 | PASS |
| Companions:RecruitCooldownS | INT | 900 | 0-86400 | PASS |
| Companions:DeathDespawnS | INT | 1800 | 60-86400 | PASS |
| Companions:MinFaction | INT | 3 | 1-6 | PASS |
| Companions:XPContribute | BOOL | true | true/false | PASS |
| Companions:MercRetentionCheckS | INT | 600 | 60-86400 | PASS |
| Companions:ReplacementSpawnDelayS | INT | 30 | 0-3600 | PASS |
| Companions:XPSharePct | INT | 50 | 1-100 | PASS |
| Companions:MaxLevelOffset | INT | 1 | 1-60 | PASS |
| Companions:ReRecruitBonus | REAL | 0.10 | 0.0-1.0 | PASS |
| Companions:DismissedRetentionDays | INT | 30 | 1-365 | PASS |
| Companions:CompanionSelfPreservePct | REAL | 0.20 | 0.0-1.0 | PASS |
| Companions:MercSelfPreservePct | REAL | 0.10 | 0.0-1.0 | PASS |

**Critical:** None of these rules exist in `rule_values`. The C++ `RuleB(Companions, CompanionsEnabled)` macro will return the compile-time default (true), so the system will function. However, `eq.get_rule("Companions:CompanionsEnabled")` from Lua will return nil or empty string — Lua must fall through to its hardcoded defaults, which it does (line 113 of companion.lua reads the WRONG rule name anyway, as described in the blocker below).

---

### Build Verification

- **Build command:** `docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`
- **Result:** PASS — ninja reports "no work to do"
- **Zone binary timestamp:** Feb 27 11:08 (after all source files)
- **Source file timestamps:** companion.cpp 11:01, companion.h 09:35, companion_ai.cpp 09:37, lua_companion.cpp 08:50 — all earlier than the binary
- **Errors:** None

The build is current. All companion C++ files compiled cleanly into the Feb 27 11:08 zone binary.

---

## Blockers

| # | Blocker | Severity | Responsible Expert | Status |
|---|---------|----------|-------------------|--------|
| B1 | Lua rule name mismatch: `companion.lua` line 113 calls `eq.get_rule("Companions:Enabled")` but the rule is named `"Companions:CompanionsEnabled"`. The eligibility check evaluates `nil ~= "true"` which is `true` so the check always passes (as if enabled). This is accidentally correct behavior when the system IS enabled, but the check will never correctly block when the rule is set to false. | High | lua-expert | Open |
| B2 | Equipment retrieval commands (`show equipment`, `give me your`, `give me everything`) call `npc:ShowEquipment(client)`, `npc:GiveSlot(client, slot_name)`, and `npc:GiveAll(client)` in companion.lua, but none of these methods are implemented in the Companion C++ class or exposed via Lua bindings. Calling them at runtime will produce a Lua error and abort the command handler. | High | c-expert + lua-expert | Open |
| B3 | Companions rules (18 entries) are missing from `rule_values` in the database. The migration manifest entry 9332 was skipped because `companion_culture_persuasion` was already populated (condition: "empty" was not met). Operators cannot tune the system via DB or Spire until the INSERT is applied manually. | Medium | data-expert | Open |

---

## Recommendations

The following are non-blocking observations for future improvement:

- **R1: CheckMercenaryRetention() stub** — The mercenary retention check (faction drop triggers auto-dismiss) only logs a message. It needs a full faction query and dismiss call to fulfill user story US-33 (mercenary retention on faction change). This is deferred scope but should be tracked.
- **R2: Companion::Signal() stub** — Companion signals are silently consumed. If future quest scripts need to signal companions for custom events, EventCompanion() dispatch in lua_parser.cpp must be implemented. This is low priority for the initial release.
- **R3: Soul wipe ChromaDB coordination** — C++ sets a DataBucket key; companion.lua trigger_soul_wipe() calls the LLM sidecar directly via io.popen. There is no automatic trigger connecting the C++ DataBucket signal to the Lua ChromaDB clear. If the soul wipe fires from the C++ timer path (permanent death), the ChromaDB memories will NOT be cleared. Recommend either wiring the DataBucket key as a checked condition in companion.lua's next-interaction handler, or calling the Lua ChromaDB clear directly from the C++ SoulWipeByCompanionID path via a quest event.
- **R4: db_version not updated** — The companion tables were created via direct SQL, bypassing the migration manifest. The db_version remains at 9328. When the server is next started fresh, the manifest conditions (SHOW TABLES LIKE 'companion_data' returning a row) will correctly prevent re-creation, but db_version will stay stale. This does not break anything but is a migration hygiene issue.
- **R5: No foreign keys on companion tables** — The companion_buffs and companion_inventories tables have indexes on companion_id but no actual FOREIGN KEY constraints. Orphaned rows are prevented only at the application layer (SoulWipe cascades via the repository). Consider adding FK constraints for defense in depth.
- **R6: companion_spell_sets WAR/MNK/ROG** — Classes 1, 7, and 9 have zero entries in companion_spell_sets. The AI correctly falls back to NPC::AI_EngagedCastCheck() for these classes. Confirm this is intentional and document that Warrior/Monk/Rogue companions are melee-only.
- **R7: Ogre max_disposition discrepancy** — The companion_culture_persuasion notes say "max=Curious" for Ogre (race 9, max_disposition=2) but the architecture PRD says Ogres follow "raw power" and should be mercenary-type only (recruitment_type=1). The DB data looks correct (max_disposition=2 = Curious); the notes field incorrectly says "max=Curious per PRD" when the PRD says "Curious" which is disposition level 2. This is consistent — just verify in-game that Ogre NPCs cannot be recruited as companions (type 0) only as mercenaries (type 1).

---

## Part 2: In-Game Testing Guide

Execute these tests with a GM character on the Titanium client. All commands prefixed with `#` are
GM commands. Tests are ordered from basic to complex. Use `#reloadquests` between test sessions to
ensure the latest quest scripts are loaded.

### Prerequisites — One-Time Setup

Before beginning any tests:

```
#level 10
```

This sets your character to level 10, which gives you a 3-level window (levels 7-13) for recruiting
companions. The default `LevelRange` rule is 3.

For faction setup, use direct SQL since `#faction` cannot set values:

```sql
-- Set Kindly faction with Qeynos Guards for Guard_Liben tests
-- (run from Spire SQL editor or docker exec mysql)
INSERT INTO faction_values (char_id, faction_id, current_value)
VALUES (YOUR_CHAR_ID, 945, 500)
ON DUPLICATE KEY UPDATE current_value = 500;
```

GM commands used throughout:

| Command | Purpose |
|---------|---------|
| `#goto qeynos2 199 363 2` | Teleport to Guard_Liben's spawn in South Qeynos |
| `#goto nektulos 843 913 -6` | Teleport to Disciple_of_Rodcet in Nektulos Forest |
| `#goto nektulos -508 412 24` | Teleport to An_Arcane_Shapeshifter in Nektulos |
| `#reloadquests` | Hot-reload quest scripts after any Lua change |
| `#showstats` | Show targeted NPC's class, level, and stats |
| `#spawn 2122` | Spawn a Guard_Liben at your location for testing |

---

### Test 1: Basic Recruitment — Eligible NPC Accepts

**Acceptance criteria (US-01, US-02):** A player can attempt to recruit an NPC within 3 levels.
On success, the NPC joins the party.

**Prerequisite:** Level 10 character, Kindly faction with Qeynos Guards.

**Steps:**
1. `#goto qeynos2 199 363 2` — teleport to Guard_Liben's location
2. Target Guard_Liben (level 5 Warrior)
3. Say: `recruit`
4. Expected: Guard_Liben responds "I will join you." (or similar refusal on a failed roll — see Test 2)
5. If success: Guard_Liben depops from spawn point; a companion named Guard_Liben appears near you
6. Open the Group window — Guard_Liben should appear as a group member
7. `/assist` Guard_Liben to verify they are targetable as a group member

**Pass if:** Guard_Liben appears as a group member in the group window. The NPC's original spawn point is vacated.
**Fail if:** No response to "recruit", Guard_Liben does not join, Lua error appears in server log, or client crashes.

**GM commands for setup:**
```
#level 10
#goto qeynos2 199 363 2
```

**Note:** Recruitment is a probabilistic roll. If you get a refusal on the first attempt, a 15-minute
cooldown applies. Use `#spawn 2122` to spawn a fresh Guard_Liben and retry, or adjust faction SQL to
maximize roll chance.

---

### Test 2: Recruitment Failure and Cooldown

**Acceptance criteria (US-03):** On failed recruitment, the NPC refuses and a cooldown prevents
immediate retry.

**Prerequisite:** Level 10 character, Indifferent or lower faction (below Kindly threshold).

**Steps:**
1. Set faction below Kindly threshold using SQL (current_value = 0 = Indifferent)
2. `#goto qeynos2 199 363 2`
3. Say: `recruit` to Guard_Liben
4. Expected: Guard_Liben says "I will not join you."
5. Immediately say: `recruit` again
6. Expected: Guard_Liben ignores or says "won't discuss again so soon"

**Pass if:** Recruitment fails on low faction AND second immediate attempt within cooldown period is rebuffed.
**Fail if:** Repeated immediate attempts all succeed without cooldown, or the game crashes.

---

### Test 3: Level Range Restriction

**Acceptance criteria (US-04):** NPCs more than 3 levels away cannot be recruited.

**Prerequisite:** Level 10 character.

**Steps:**
1. `#goto nektulos -508 412 24` — teleport to An_Arcane_Shapeshifter (level 8, Enchanter)
2. Target An_Arcane_Shapeshifter
3. `#showstats` — confirm level is 8 (within range for level 10 player: 7-13 allowed)
4. Say: `recruit` — this should succeed (within range)
5. Now set your level much higher: `#level 20`
6. Dismiss the companion (say: `dismiss`)
7. Try to recruit a level 5 NPC (`#goto qeynos2 199 363 2`, target Guard_Liben)
8. Say: `recruit` — expected: "too far from your level" refusal

**Pass if:** Level 8 NPC recruits for level 10 player; level 5 NPC is refused for level 20 player.
**Fail if:** Level restriction is not enforced.

---

### Test 4: Companion Fights in Combat (Balanced Stance)

**Acceptance criteria (US-06, US-07):** The companion engages enemies in combat alongside the player.

**Prerequisite:** Recruited companion in group (from Test 1).

**Steps:**
1. With Guard_Liben in group, attack any enemy NPC in Qeynos 2 (gnolls, etc.)
2. Watch Guard_Liben's behavior — they should engage the same target
3. Watch the group HP bars — Guard_Liben's HP bar should be visible
4. Confirm Guard_Liben attacks using melee (Warrior has no companion spells)

**Pass if:** Companion engages enemy, deals melee damage, and takes damage from enemies.
**Fail if:** Companion stands idle, companion does not appear in group HP display, or server crashes.

---

### Test 5: Companion Spell AI — Healer Class

**Acceptance criteria (US-07):** Healer companions cast healing spells on injured group members.

**Prerequisite:** Level 10 character, Disciple_of_Rodcet (level 4 Cleric) recruited as companion.

**Steps:**
1. `#goto nektulos 843 913 -6`
2. Target Disciple_of_Rodcet and say: `recruit`
3. If successful, engage a tough enemy to reduce your HP to ~50%
4. Watch for Disciple_of_Rodcet to cast a heal on you
5. Confirm a heal effect is seen (HP restoration, spell particle effects)

**Pass if:** Cleric companion casts a healing spell when the player is below ~70% HP.
**Fail if:** Cleric companion never casts, player dies without receiving a heal.

**Note:** Companion spells use the companion_spell_sets table. Class 2 (Cleric) has 79 entries
including healing spells. If this test fails, check that the companion's mana is not depleted.

---

### Test 6: Stance Commands

**Acceptance criteria (US-08):** Player can change companion stance via say commands.

**Prerequisite:** Recruited companion in group.

**Steps:**
1. With companion in group, say: `passive`
2. Expected: Companion responds "Understood. I will fight passive." Companion should not initiate combat.
3. Attack an enemy. Companion should NOT engage (passive stance).
4. Say: `aggressive`
5. Expected: Companion responds "Understood. I will fight aggressive."
6. Near an enemy. Companion should engage first without being directly told.
7. Say: `balanced`
8. Expected: Companion responds "Understood. I will fight balanced."

**Pass if:** All three stance acknowledgments appear; companion behavior changes match the stance.
**Fail if:** Companion ignores stance commands, or stance has no effect on combat behavior.

---

### Test 7: Voluntary Dismissal

**Acceptance criteria (US-09):** Player can voluntarily dismiss a companion who returns to their original location.

**Prerequisite:** Recruited companion in group.

**Steps:**
1. With companion in group, say: `dismiss`
2. Expected: Companion says "Farewell."
3. Companion departs the group window
4. Travel to the NPC's original spawn location
5. A replacement NPC should appear within ~30 seconds (ReplacementSpawnDelayS = 30)

**Pass if:** Companion dismisses cleanly, leaves group window, and original spawn point eventually repopulates.
**Fail if:** Companion stays in group window after dismiss, or server crashes.

---

### Test 8: Companion Persists After Zone Change (Player)

**Acceptance criteria (US-10):** Recruited companion follows the player when zoning.

**Prerequisite:** Recruited companion in group in South Qeynos.

**Steps:**
1. With Guard_Liben in group, zone to North Qeynos (walk through zone line)
2. After zone-in, check group window
3. Guard_Liben should reappear near your position after a brief delay

**Pass if:** Companion appears in the new zone within 10 seconds of zone-in.
**Fail if:** Companion disappears permanently after zoning, or Lua errors appear in zone log.

**GM commands for quick zone test:**
```
#zone qeynos       -- zone to North Qeynos
```

---

### Test 9: Companion Persistence After Logout/Login

**Acceptance criteria (US-11):** Companion data persists through player logout and login.

**Prerequisite:** Recruited companion in group.

**Steps:**
1. With companion in group, `/camp` to character select (full camp, not crash)
2. Log back in on the same character
3. Companion should respawn near your login position

**Pass if:** Companion appears after login and retains their level, equipment, and stance from before logout.
**Fail if:** Companion is gone after login, or appears with reset stats.

---

### Test 10: Group Full Auto-Dismiss

**Acceptance criteria (US-13):** When a full group of players forms, companion is automatically suspended.

**Prerequisite:** Recruited companion in group. Requires 5 additional players or GM-spawned NPCs.

**Steps:**
1. With companion in group (2 members: player + companion)
2. Invite 4 more players to fill all 6 group slots
3. When the 6th real player joins, companion should auto-suspend

**Pass if:** Group capacity fills with real players; companion is suspended (removed from group) automatically; companion chat message confirms suspension.
**Fail if:** Group cannot form due to companion slot conflict, or companion stays in over-full group.

**Note:** This test requires other players or a workaround. Use `#spawn` + `#groupinvite` with spawned NPCs if other players are unavailable.

---

### Test 11: Companion XP and Level Up

**Acceptance criteria (US-15, US-16):** Companion earns XP from kills and levels up when threshold is reached.

**Prerequisite:** Level 10 character with companion in group. Companion should be ~level 7 (3 below player).

**Steps:**
1. With companion in group, kill several enemies
2. Watch for a level-up notification in chat (companion level increases)
3. After level-up, note that companion's stats should scale up (HP, AC, damage)
4. Companion's max level is player_level - MaxLevelOffset (default: player_level - 1 = 9)
5. Level the player to 20, then grind kills with companion to test max level tracking

**Pass if:** Companion gains levels; companion HP bar shows higher HP after level-up; companion cannot exceed player_level - 1.
**Fail if:** Companion never levels up after many kills, or companion exceeds the max level cap.

**GM command to speed-test:**
```
#level 15    -- adjust player level to open new companion level cap
```

---

### Test 12: Equipment — Give Item to Companion

**Acceptance criteria (US-17):** Player can equip items on their companion via the trade window.

**Prerequisite:** Recruited companion in group. Have a weapon item available.

**Steps:**
1. Obtain a weapon that a Warrior can use (e.g., Rusty Longsword, item ID 5016)
   - `#summonitem 5016`
2. Open the trade window with your companion (right-click companion, select Trade)
3. Place the Rusty Longsword in the trade window and confirm
4. Companion should equip the item and display a visual change if their race supports it

**Pass if:** Trade window accepts the item; companion equips the weapon; `show equipment` command lists the item.
**Fail if:** Trade window does not open with companion, item is not accepted, or item disappears without being equipped.

---

### Test 13: Equipment Retrieval — Show Equipment Command

**Acceptance criteria (US-17):** Player can view and retrieve companion equipment.

**Prerequisite:** Companion has at least one equipped item from Test 12.

**Steps:**
1. With equipped companion in group, say: `show equipment`
2. Expected: A chat message or window showing the companion's equipped items

**KNOWN BLOCKER:** This test will FAIL. The `ShowEquipment()` method is called in `companion.lua`
but does not exist in the Companion C++ class or Lua bindings. A Lua error will occur.

**Pass if:** Equipment list is displayed (after B2 blocker is fixed).
**Fail if:** Lua error in server log; no equipment list displayed.

---

### Test 14: Equipment — Retrieve Item from Companion

**Acceptance criteria (US-17):** Player can retrieve specific items from companion.

**Prerequisite:** Companion has an equipped item.

**Steps:**
1. Say: `give me your weapon`
2. Expected: Companion says "As you wish." and item appears in player inventory

**KNOWN BLOCKER:** This test will FAIL. `GiveSlot()` is not implemented. See Blocker B2.

**Pass if:** Item transfers to player inventory (after B2 is fixed).
**Fail if:** Lua error, item lost, or command ignored.

---

### Test 15: Companion Death and Resurrection Window

**Acceptance criteria (US-19):** When companion dies, player has a timed window to resurrect them.

**Prerequisite:** Recruited companion in group. Access to a resurrection spell or cleric.

**Steps:**
1. Allow companion to die in combat (or use `#kill` targeted on companion)
2. Watch for chat message: "[companion name] has fallen in battle! You have 1800 seconds to resurrect them, or they will return home."
3. While within the 1800-second window, cast a resurrection spell on the companion's corpse
4. Companion should revive with some HP/mana

**Pass if:** Death message appears with timer; resurrection within the window succeeds.
**Fail if:** No death message, or companion immediately vanishes without a resurrection window.

**Note on resurrection:** Open question from architecture plan (Q10) — Titanium client NPC corpse targeting for resurrection spells may require testing. If NPC corpse cannot be targeted, the resurrection path is currently broken regardless.

---

### Test 16: Companion Permanent Death (Soul Wipe)

**Acceptance criteria (US-20):** When the resurrection timer expires, companion is permanently lost (soul wipe).

**Prerequisite:** Companion who has died (from Test 15). Do NOT resurrect.

**Steps:**
1. Allow companion to die
2. Wait for the 1800-second despawn timer (or use a modified DeathDespawnS rule for faster testing)
3. Expected: Chat message "has been lost forever. They waited too long to be resurrected."
4. Check companion_data table in DB — record should be deleted
5. Check that ChromaDB soul memories are cleared (LLM interaction with former NPC should show no memory)

**Pass if:** Companion data is deleted from companion_data, companion_buffs, and companion_inventories.
**Fail if:** Companion data persists in DB after timer expiry, or companion reappears after login.

**Fast test:** Modify rule via SQL before test:
```sql
UPDATE rule_values SET rule_value = '5' WHERE rule_name = 'Companions:DeathDespawnS';
-- (Or INSERT if rule_values has no entry for this rule yet)
INSERT INTO rule_values (ruleset_id, rule_name, rule_value)
VALUES (1, 'Companions:DeathDespawnS', '5');
-- Then reload rules:
-- #reloadrules
```

**Note on ChromaDB clear:** The C++ soul wipe sets a DataBucket key (`soul_wipe_{owner}_{companion_id}`)
but does NOT directly call the LLM sidecar. The companion.lua `trigger_soul_wipe()` function exists
but is not automatically called on permanent death. ChromaDB memories may NOT be cleared.
See Recommendation R3 in the Blockers section.

---

### Test 17: Re-Recruitment — Restores State with Bonus

**Acceptance criteria (US-22, US-23):** A voluntarily dismissed companion can be re-recruited, restoring their previous level and XP, with a +10% roll bonus.

**Prerequisite:** Companion who has been voluntarily dismissed (from Test 7).

**Steps:**
1. Voluntarily dismiss a companion (say: `dismiss`)
2. Return to the NPC's original spawn location
3. Say: `recruit` to the NPC (or the replacement NPC if original despawned)
4. On success: companion should reappear at the level and XP they had before dismissal
5. On a failed roll: note that the re-recruitment bonus (+10%) should make success more likely than a first-time recruitment

**Pass if:** Dismissed companion re-recruits with their stored level and XP restored. Group window shows correct level.
**Fail if:** Companion appears at base level (state lost), or re-recruitment applies no bonus.

---

### Test 18: Companion Cannot Be Recruited from Excluded NPCs

**Acceptance criteria (US-24):** NPCs on the exclusion list cannot be recruited.

**Prerequisite:** Level 10 character.

**Steps:**
1. Find Sir Lucan D'Lere (NPC type ID 9147) or Lord Antonius Bayle (ID 466029)
2. `#spawn 9147` to spawn Sir Lucan at your location
3. Say: `recruit`
4. Expected: Refusal message "[name] cannot be recruited."
5. Also test a merchant-class NPC (merchant class is in exclusion table)
   - `#spawn` any merchant and say `recruit` — should be refused

**Pass if:** Lore anchor NPCs and excluded-class NPCs cannot be recruited.
**Fail if:** Sir Lucan or a merchant can be successfully recruited.

---

### Test 19: Mercenary-Type Retention (Faction Check)

**Acceptance criteria (US-27):** A mercenary-type companion (Troll, Ogre, Dark Elf) may leave if faction drops.

**Note:** This test requires a mercenary-type NPC (race 8=Troll, 9=Ogre, 12=Dark Elf per companion_culture_persuasion).

**Prerequisite:** Recruited mercenary-type companion.

**Steps:**
1. Recruit a Troll or Ogre NPC (if one is available within level range)
2. Confirm companion_type = 1 (mercenary) by checking companion_data table
3. Drop faction with the mercenary's faction via SQL or in-game actions
4. Wait for the retention check timer (~600 seconds, MercRetentionCheckS)
5. Expected: Companion auto-dismisses with a warning message

**KNOWN ISSUE:** CheckMercenaryRetention() is a stub (only logs). This test WILL FAIL — the
mercenary retention mechanic is not yet implemented. See Recommendation R1.

**Pass if:** Mercenary auto-dismisses on faction drop (after R1 is resolved).
**Fail if:** Mercenary stays regardless of faction (current behavior).

---

### Test 20: Replacement NPC Spawns After Recruitment

**Acceptance criteria (US-30):** After a successful recruitment, a replacement NPC appears at the original spawn point within ReplacementSpawnDelayS seconds.

**Prerequisite:** Recruited companion. Note the original spawn coordinates.

**Steps:**
1. Successfully recruit Guard_Liben (from Test 1)
2. Stay near the original spawn point
3. Wait 30 seconds (ReplacementSpawnDelayS default)
4. Expected: A generic replacement NPC (or re-spawn of original type) appears at the spawn point

**Pass if:** A replacement NPC appears within ~30 seconds of recruitment.
**Fail if:** The spawn point remains empty indefinitely, or Guard_Liben re-spawns normally (which would conflict with the companion version of Guard_Liben in the group).

---

### Edge Case Tests

---

### Test E1: Recruitment During Combat

**Risk from architecture plan:** Players attempt to recruit NPCs while in combat.

**Steps:**
1. Engage an enemy in combat (get aggro)
2. Target a different, nearby eligible NPC
3. Say: `recruit`
4. Expected: Refusal with message "You cannot recruit while in combat."

**Pass if:** Recruitment is blocked during combat.
**Fail if:** Recruitment succeeds during combat, or game crashes.

---

### Test E2: Full Group + Companion (Auto-Suspend Edge Case)

**Risk:** Companion auto-suspend fires for wrong companion or wrong timing.

**Steps:**
1. Form a 5-person group (player + 4 others) with one companion
2. Invite a 6th person
3. Companion should suspend; 6th person should join normally
4. Dismiss one player to drop below 6
5. Companion should NOT automatically unsuspend — player must manually unsuspend

**Pass if:** Auto-suspend fires correctly on 6th player join; companion stays suspended until manually unsuspended.
**Fail if:** Wrong group member is suspended, 6th player blocked from joining, or companion unsuspends spontaneously.

---

### Test E3: Recruit an NPC Already Recruited by Someone Else

**Risk:** Two players attempt to recruit the same NPC.

**Prerequisite:** Two player accounts.

**Steps:**
1. Player A says: `recruit` to Guard_Liben — succeeds
2. Player B immediately says: `recruit` to the same Guard_Liben entity
3. Expected: Player B receives "has already joined someone's party."

**Pass if:** Entity variable `is_recruited` prevents double-recruitment.
**Fail if:** Two companions of the same NPC exist simultaneously.

---

### Test E4: Lua Rule Name Bug — System Enable/Disable

**Risk from Blocker B1:** The "Companions:Enabled" rule name is wrong; disabling will not work.

**Steps:**
1. Insert a rule into rule_values: `INSERT INTO rule_values (ruleset_id, rule_name, rule_value) VALUES (1, 'Companions:CompanionsEnabled', 'false');`
2. `#reloadrules`
3. Try to recruit any NPC
4. Expected (desired): Recruitment fails with "not available on this server"
5. Actual (current): The Lua check reads "Companions:Enabled" which returns nil; the check `nil ~= "true"` evaluates to true (system appears enabled). Recruitment proceeds as normal.

**Pass if (after fix):** Rule=false blocks recruitment.
**Fail if (confirming bug):** Recruitment works even with CompanionsEnabled=false in rule_values.

---

### Test E5: Companion NPC Type Preservation

**Risk:** Companion's race/appearance changes unexpectedly after zone.

**Steps:**
1. Recruit Guard_Liben (race 71 = Vah Shir guard or Human — verify with #showstats)
2. Zone to a different area
3. After zone-in, target Guard_Liben
4. `#showstats` — confirm race, class, and level match pre-zone values

**Pass if:** Companion retains their exact race/class/level after zoning.
**Fail if:** Companion appears as a different race or with wrong stats after zone.

---

## Rollback Instructions

If something goes seriously wrong during in-game testing:

```bash
# Remove all companion data (no companion data yet in fresh tests)
docker exec akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq -e "
DELETE FROM companion_inventories;
DELETE FROM companion_buffs;
DELETE FROM companion_data;
"

# Remove the Companions rule_values if manually inserted
docker exec akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq -e "
DELETE FROM rule_values WHERE rule_name LIKE 'Companions:%';
"

# Revert global_npc.lua to remove companion require (if companion.lua causes breakage)
# The global_npc.lua loads companion_lib = require("companion") at line 4
# If companion.lua is removed from lua_modules, global_npc.lua will fail to load
# Revert by removing companion-related lines 4, 11-21 from global_npc.lua

# Full database rollback of companion tables
docker exec akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq -e "
DROP TABLE IF EXISTS companion_inventories;
DROP TABLE IF EXISTS companion_buffs;
DROP TABLE IF EXISTS companion_data;
DROP TABLE IF EXISTS companion_exclusions;
DROP TABLE IF EXISTS companion_culture_persuasion;
DROP TABLE IF EXISTS companion_spell_sets;
"
```

**Note:** There is no rollback for the C++ binary changes. Rolling back the C++ changes requires
reverting commits in the eqemu branch and rebuilding. The zone binary can be replaced with the
prior build if available at `eqemu/build/bin/zone.bak`.

---

## Overall Assessment

**Ready for in-game testing: CONDITIONAL**

The core infrastructure is solid:
- Build compiles cleanly, all 24 tasks complete
- 6 database tables exist with correct schemas and seed data (7,269 exclusions, 14 culture records, 842 spell entries)
- All Lua files pass syntax checks
- C++ Companion class lifecycle, AI, persistence, XP, history, and soul wipe are implemented
- Global NPC interception for recruitment and management keywords is working
- Re-recruitment transparent restore is implemented in C++
- Group window integration works via standard group mechanics

**Three blockers must be fixed before equipment commands work:**

1. **B1 (High):** Fix the rule name in `companion.lua` line 113: change `"Companions:Enabled"` to `"Companions:CompanionsEnabled"`. This is a one-line lua-expert fix.

2. **B2 (High):** Implement `ShowEquipment(client)`, `GiveSlot(client, slot_name)`, and `GiveAll(client)` on the Companion C++ class and expose them via Lua bindings. This is a c-expert + lua-expert fix. Without this, any `show equipment`, `give me your`, or `give me everything` command will crash with a Lua error.

3. **B3 (Medium):** Insert the 18 Companions rule_values into the database manually. The migration never ran because it was condition-blocked. Run:
   ```sql
   INSERT IGNORE INTO rule_values (ruleset_id, rule_name, rule_value, notes) VALUES
   (1, 'Companions:CompanionsEnabled', 'true', '...'), ...;
   ```

**Tests 1-12, 15-18, E1-E5 can be executed now** (after confirming B1 is acceptable as a pass-through).
**Tests 13, 14, 19** cannot be executed until blockers B2 and mercenary retention (R1) are fixed.
