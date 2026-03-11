# Companion Test Scaffolding — Implementation Plan

> **Feature:** npc-companion-realistic-stats
> **Author:** architect
> **Date:** 2026-03-10
> **Purpose:** Provide a comprehensive, TDD-ready test infrastructure for
> all companion subsystems BEFORE any Phase 1 implementation begins.
> **Status:** Plan (no code changes — handed to engineers for implementation)

---

## Table of Contents

1. [Part 1: Test Framework Foundation](#part-1-test-framework-foundation)
2. [Part 2: Test Suites for 8 Companion Subsystems](#part-2-test-suites-for-8-companion-subsystems)
3. [Part 3: Test Execution and Reporting](#part-3-test-execution-and-reporting)
4. [Part 4: Phased Test Addition Strategy](#part-4-phased-test-addition-strategy)
5. [Part 5: Task Breakdown for Implementation](#part-5-task-breakdown-for-implementation)

---

## Architecture Decision: CLI Integration Tests

### Why CLI Tests, Not CppUnit

The codebase has two test patterns:

1. **CppUnit tests** in `eqemu/tests/` — linked to `common` library only.
   The `tests/CMakeLists.txt` does NOT link to zone, so these tests have
   no access to Companion, NPC, Mob, Entity, Zone, or any zone-layer class.
   These tests are appropriate for common utilities (strings, serialization,
   task state parsing) but cannot test companion behavior.

2. **CLI integration tests** in `eqemu/zone/cli/tests/` — compiled into the
   `zone` binary itself and run via `zone tests:<name>` on the command line.
   These tests boot a real zone (`Zone::Bootup()`), have full database
   access, can create NPCs from `npc_types`, manipulate the entity list,
   and run assertions. This is the ONLY pattern that can construct and
   test `Companion` objects.

**Decision:** All companion tests use the CLI integration test pattern.

### Existing Infrastructure to Build On

**cli_test_util.cpp** provides:
- `RunTest(name, expected, actual)` — overloaded for string, bool, int.
  Prints pass/fail with emoji markers, calls `std::exit(1)` on failure.
- `SetupZone(zone_short_name, instance_id)` — boots a real zone with DB,
  silences logging, stops shutdown timer, processes entity list.
- `extern Zone *zone` — gives tests access to the booted zone.

**cli_zone_state.cpp** demonstrates:
- Multiple test functions called from a single entry point
- NPC creation from `content_db.LoadNPCTypesData()` and `new NPC(npc_type, ...)`
- State verification via entity_list queries
- DB cleanup before and after tests
- Timer manipulation (`Timer::RollForward()`)
- Kill simulation (`npc->Death(...)`)

**zone_cli.h** declares test entry points as static methods:
```cpp
static void TestZoneState(int argc, char **argv, argh::parser &cmd, std::string &description);
```

**zone_cli.cpp** registers them:
```cpp
function_map["tests:zone-state"] = &ZoneCLI::TestZoneState;
```

**zone/CMakeLists.txt** includes test files directly in `zone_sources`:
```
cli/tests/cli_test_util.cpp
cli/tests/cli_zone_state.cpp
```

**main.cpp** routes test commands:
```cpp
if (ZoneCLI::RanTestCommand(argc, argv)) {
    EQEmuLogSys::Instance()->SilenceConsoleLogging();
}
```
Then later calls `ZoneCLI::CommandHandler(argc, argv)` which dispatches
to the registered function.

---

## Part 1: Test Framework Foundation

### 1.1 New Files to Create

#### File: `eqemu/zone/cli/tests/cli_companion_test_util.h`

A header-only helper library for companion test construction and assertion.
This file provides the reusable building blocks that all 8 test suites use.

**Purpose:** Centralize companion construction, equipment helpers, stat
reading, and extended assertion macros so test suites focus on what they
test, not on setup boilerplate.

**Contents:**

```
#pragma once

#include "zone/companion.h"
#include "zone/zone.h"
#include "zone/entity.h"
#include "common/item_data.h"
#include "common/repositories/companion_data_repository.h"
#include "common/repositories/companion_inventories_repository.h"
#include "common/repositories/companion_buffs_repository.h"

// Forward declarations from cli_test_util.cpp
extern Zone *zone;
void RunTest(const std::string &test_name, const std::string &expected, const std::string &actual);
void RunTest(const std::string &test_name, bool expected, bool actual);
void RunTest(const std::string &test_name, int expected, int actual);
void SetupZone(std::string zone_short_name, uint32 instance_id);
```

**Helper functions to declare (all `inline` since header-only):**

##### 1.1.1 `SetupCompanionTestZone()`

```cpp
inline void SetupCompanionTestZone()
```

Boots a minimal zone suitable for companion tests. Uses a small, fast-loading
zone. Candidates: `arena` (small, few spawns), `bazaar` (empty), or
`freportw` (small). The zone must have:
- Valid zone ID (required for Zone::Bootup)
- Few or no spawns (to minimize boot time and entity noise)
- Valid zone geometry (for position calculations)

**Implementation pattern:**
```cpp
inline void SetupCompanionTestZone()
{
    SetupZone("arena");  // small zone, fast boot
    zone->Process();
    // Depop the zone controller if present
    auto controller = entity_list.GetNPCByNPCTypeID(ZONE_CONTROLLER_NPC_ID);
    if (controller != nullptr) {
        controller->Depop();
    }
    entity_list.MobProcess(); // process the depop
}
```

This mirrors `SetupStateZone()` from cli_zone_state.cpp.

##### 1.1.2 `CreateTestCompanion()`

```cpp
inline Companion* CreateTestCompanion(
    uint32 npc_type_id,
    uint32 owner_char_id = 0,
    uint8 companion_type = COMPANION_TYPE_COMPANION)
```

Factory function that creates a Companion for testing. Steps:
1. Load NPCType from DB via `content_db.LoadNPCTypesData(npc_type_id)`
2. Construct `new Companion(npc_type, 0, 0, 0, 0, owner_char_id, companion_type)`
3. Add to entity list via `entity_list.AddNPC(companion)` (Companion IS-A NPC)
4. Return the Companion pointer

**Critical detail:** The constructor calls `CalcBonuses()`, initializes the
inventory profile (`GetInv().SetInventoryVersion()`), stores base stats,
applies `StatScalePct`, and determines combat role. All of these are testable
immediately after construction.

**NPC type ID selection:** Tests should use well-known NPC type IDs from the
database. Good candidates:
- A warrior NPC (class=1) at a known level
- A rogue NPC (class=9) at a known level
- A cleric NPC (class=2) at a known level
- A wizard NPC (class=12) at a known level

The test suite should discover suitable NPC type IDs at runtime by querying
`npc_types` for specific class/level combinations, rather than hardcoding
IDs that may not exist in every database. Example:

```cpp
inline uint32 FindNPCTypeIDForClassLevel(uint8 npc_class, uint8 min_level, uint8 max_level)
{
    auto results = content_db.QueryDatabase(
        fmt::format(
            "SELECT `id` FROM `npc_types` "
            "WHERE `class` = {} AND `level` BETWEEN {} AND {} "
            "AND `bodytype` != 11 "  // skip untargetable
            "ORDER BY `level` DESC LIMIT 1",
            static_cast<uint32>(npc_class),
            static_cast<uint32>(min_level),
            static_cast<uint32>(max_level)
        )
    );
    if (results.Success() && results.RowCount() > 0) {
        auto row = results.begin();
        return static_cast<uint32>(atoi(row[0]));
    }
    return 0; // Not found — test should skip or fail gracefully
}
```

##### 1.1.3 `CreateTestCompanionByClass()`

Convenience wrapper that finds an NPC of the desired class and creates a Companion.

```cpp
inline Companion* CreateTestCompanionByClass(
    uint8 npc_class,
    uint8 desired_level = 50,
    uint32 owner_char_id = 0)
{
    uint32 npc_id = FindNPCTypeIDForClassLevel(npc_class, desired_level - 5, desired_level + 5);
    if (npc_id == 0) {
        std::cerr << "[SKIP] No NPC of class " << (int)npc_class
                  << " near level " << (int)desired_level << " found in DB\n";
        return nullptr;
    }
    return CreateTestCompanion(npc_id, owner_char_id);
}
```

##### 1.1.4 `EquipCompanionItem()`

```cpp
inline bool EquipCompanionItem(Companion* comp, uint32 item_id, int16 slot)
```

Wraps `Companion::GiveItem()` and verifies the item was placed correctly.
Returns success/failure. Checks:
- `GiveItem()` returned true
- `comp->GetEquipment(slot) == item_id` (m_equipment array)
- `comp->GetInv().GetItem(slot)` is non-null and has matching item ID

##### 1.1.5 `CleanupTestCompanions()`

```cpp
inline void CleanupTestCompanions()
```

Removes all Companion entities from the entity list and cleans up any test
DB rows. This prevents test pollution between suites.

**Implementation:**
```cpp
inline void CleanupTestCompanions()
{
    std::vector<NPC*> to_remove;
    for (auto& e : entity_list.GetNPCList()) {
        if (e.second && e.second->IsCompanion()) {
            to_remove.push_back(e.second);
        }
    }
    for (auto* npc : to_remove) {
        npc->Depop();
    }
    entity_list.MobProcess(); // process depops
}
```

##### 1.1.6 Extended Assertion Helpers

Beyond the base `RunTest()` overloads, companion tests need numeric comparison
with tolerance (for floating point stats) and range checks:

```cpp
inline void RunTestFloat(const std::string& test_name, float expected, float actual, float tolerance = 0.01f)
{
    if (std::abs(expected - actual) <= tolerance) {
        std::cout << "[PASS] " << test_name << " PASSED\n";
    } else {
        std::cerr << "[FAIL] " << test_name << " FAILED\n";
        std::cerr << "   Expected: " << expected << "\n";
        std::cerr << "   Got:      " << actual << "\n";
        std::cerr << "   Tolerance: " << tolerance << "\n";
        std::exit(1);
    }
}

inline void RunTestRange(const std::string& test_name, int actual, int min_val, int max_val)
{
    if (actual >= min_val && actual <= max_val) {
        std::cout << "[PASS] " << test_name << " PASSED (value=" << actual << ")\n";
    } else {
        std::cerr << "[FAIL] " << test_name << " FAILED\n";
        std::cerr << "   Value: " << actual << "\n";
        std::cerr << "   Expected range: [" << min_val << ", " << max_val << "]\n";
        std::exit(1);
    }
}

inline void RunTestGreaterThan(const std::string& test_name, int actual, int threshold)
{
    if (actual > threshold) {
        std::cout << "[PASS] " << test_name << " PASSED (value=" << actual << " > " << threshold << ")\n";
    } else {
        std::cerr << "[FAIL] " << test_name << " FAILED\n";
        std::cerr << "   Value: " << actual << "\n";
        std::cerr << "   Expected: > " << threshold << "\n";
        std::exit(1);
    }
}

inline void RunTestNotNull(const std::string& test_name, const void* ptr)
{
    if (ptr != nullptr) {
        std::cout << "[PASS] " << test_name << " PASSED\n";
    } else {
        std::cerr << "[FAIL] " << test_name << " FAILED (was null)\n";
        std::exit(1);
    }
}
```

##### 1.1.7 Known Item IDs for Testing

Tests need specific items from the `items` table. Rather than hardcoding item
IDs (which vary by database), define a lookup function:

```cpp
inline uint32 FindItemByName(const std::string& partial_name)
{
    auto results = content_db.QueryDatabase(
        fmt::format(
            "SELECT `id` FROM `items` WHERE `name` LIKE '%{}%' LIMIT 1",
            Strings::Escape(partial_name)
        )
    );
    if (results.Success() && results.RowCount() > 0) {
        auto row = results.begin();
        return static_cast<uint32>(atoi(row[0]));
    }
    return 0;
}

// Structured weapon lookup: find a weapon with specific characteristics
inline uint32 FindWeapon(int min_damage, int max_damage, int min_delay, int max_delay, int item_type = -1)
{
    std::string type_filter = "";
    if (item_type >= 0) {
        type_filter = fmt::format(" AND `itemtype` = {}", item_type);
    }
    auto results = content_db.QueryDatabase(
        fmt::format(
            "SELECT `id` FROM `items` "
            "WHERE `damage` BETWEEN {} AND {} "
            "AND `delay` BETWEEN {} AND {} "
            "{} "
            "ORDER BY `damage` ASC LIMIT 1",
            min_damage, max_damage, min_delay, max_delay, type_filter
        )
    );
    if (results.Success() && results.RowCount() > 0) {
        auto row = results.begin();
        return static_cast<uint32>(atoi(row[0]));
    }
    return 0;
}
```

#### File: `eqemu/zone/cli/tests/cli_companion_tests.cpp`

The main test file containing all 8 test suites. This is a large file
(~1500-2000 lines expected) organized into clearly-separated test functions.

**Structure:**

```cpp
#include "zone/zone_cli.h"
#include "zone/companion.h"
#include "cli_companion_test_util.h"
// ... other includes

// ============ TEST SUITE 1: Construction =============
inline void TestCompanionConstruction() { ... }

// ============ TEST SUITE 2: Equipment =============
inline void TestCompanionEquipment() { ... }

// ============ TEST SUITE 3: Melee Combat =============
inline void TestCompanionMeleeCombat() { ... }

// ============ TEST SUITE 4: Defense =============
inline void TestCompanionDefense() { ... }

// ============ TEST SUITE 5: Stats =============
inline void TestCompanionStats() { ... }

// ============ TEST SUITE 6: Spells =============
inline void TestCompanionSpells() { ... }

// ============ TEST SUITE 7: Group Integration =============
inline void TestCompanionGroupIntegration() { ... }

// ============ TEST SUITE 8: Stance/Positioning =============
inline void TestCompanionStancePositioning() { ... }

// ============ ENTRY POINT =============
void ZoneCLI::TestCompanion(int argc, char **argv, argh::parser &cmd, std::string &description)
{
    description = "Run companion system integration tests";

    if (cmd[{"-h", "--help"}]) {
        return;
    }

    SetupCompanionTestZone();

    std::cout << "===========================================\n";
    std::cout << "Running Companion Tests...\n";
    std::cout << "===========================================\n\n";

    TestCompanionConstruction();
    CleanupTestCompanions();

    TestCompanionEquipment();
    CleanupTestCompanions();

    TestCompanionMeleeCombat();
    CleanupTestCompanions();

    TestCompanionDefense();
    CleanupTestCompanions();

    TestCompanionStats();
    CleanupTestCompanions();

    TestCompanionSpells();
    CleanupTestCompanions();

    TestCompanionGroupIntegration();
    CleanupTestCompanions();

    TestCompanionStancePositioning();
    CleanupTestCompanions();

    std::cout << "\n===========================================\n";
    std::cout << "All Companion Tests Completed!\n";
    std::cout << "===========================================\n";
}
```

### 1.2 Registration Changes

#### File: `eqemu/zone/zone_cli.h`

Add declaration:

```cpp
static void TestCompanion(int argc, char **argv, argh::parser &cmd, std::string &description);
```

Add this line in the public section of `ZoneCLI`, after the existing test
declarations (after line 19 in current file).

#### File: `eqemu/zone/zone_cli.cpp`

Add registration:

```cpp
function_map["tests:companion"] = &ZoneCLI::TestCompanion;
```

Add this line in `ZoneCLI::CommandHandler()`, after line 39 in the current
file (after the `tests:zone-state` registration).

#### File: `eqemu/zone/CMakeLists.txt`

Add the new test files to `zone_sources`:

```cmake
cli/tests/cli_companion_tests.cpp
```

Add after `cli/tests/cli_zone_state.cpp` (after line 26 in current file).

The header file `cli_companion_test_util.h` does NOT need to be listed
in CMakeLists.txt — CMake picks up headers via includes.

### 1.3 Execution Method

To run the tests:

```bash
docker exec -it akk-stack-eqemu-server-1 bash -c \
  "cd ~/server && ~/code/build/bin/zone tests:companion"
```

**Important:** Must run from the `~/server` directory (not `~/code/build/bin/`)
because the zone binary reads `eqemu_config.json` from the current directory
for database connection. The CLI test path boots a real zone with DB access.

**Important:** No zone processes should be running when tests execute. The
test boots its own zone instance, which conflicts with running zone servers
binding the same ports. Alternatively, tests can be run on a different port
or with the world server stopped.

---

## Part 2: Test Suites for 8 Companion Subsystems

### Suite 1: Construction Tests

**Purpose:** Verify that `Companion` objects are correctly constructed from
`NPCType` data, including inheritance chain, identity flags, stat
initialization, and combat role assignment.

**Prerequisites:** A valid NPC type ID in the database.

#### Test 1.1: Basic Construction from NPCType

```
Test: "Construction > Companion created from valid NPC type"
Action: Load NPCType for a warrior NPC, construct Companion
Assert: Companion pointer is non-null
```

**Implementation sketch:**
```cpp
auto npc_type = content_db.LoadNPCTypesData(warrior_npc_id);
RunTestNotNull("Construction > NPCType loaded", npc_type);
auto comp = new Companion(npc_type, 0, 0, 0, 0, 1);
RunTestNotNull("Construction > Companion created from valid NPC type", comp);
entity_list.AddNPC(comp);
```

#### Test 1.2: Identity Flags

```
Test: "Construction > IsCompanion() returns true"
Action: Create companion
Assert: comp->IsCompanion() == true

Test: "Construction > IsNPC() returns true"
Assert: comp->IsNPC() == true

Test: "Construction > IsOfClientBot() returns true"
Assert: comp->IsOfClientBot() == true

Test: "Construction > IsOfClientBotMerc() returns true"
Assert: comp->IsOfClientBotMerc() == true

Test: "Construction > IsClient() returns false"
Assert: comp->IsClient() == false

Test: "Construction > IsBot() returns false"
Assert: comp->IsBot() == false
```

**Why these matter:** The dual identity (IsNPC=true AND IsOfClientBot=true)
drives which code paths the companion takes for combat, avoidance, bonuses,
and AC calculation. If any of these are wrong, multiple systems break silently.

#### Test 1.3: Base Stat Initialization

```
Test: "Construction > Base STR matches NPCType"
Assert: comp->GetSTR() == npc_type->STR (adjusted by StatScalePct)

Test: "Construction > Base STA matches NPCType"
Assert: comp->GetSTA() == npc_type->STA (adjusted by StatScalePct)

Test: "Construction > Base DEX matches NPCType"
Assert: comp->GetDEX() == npc_type->DEX (adjusted by StatScalePct)

[... repeat for AGI, INT, WIS, CHA]

Test: "Construction > Max HP matches NPCType"
Assert: comp->GetMaxHP() == npc_type->max_hp (adjusted by StatScalePct)

Test: "Construction > Level matches NPCType"
Assert: comp->GetLevel() == npc_type->level
```

**Note on StatScalePct:** If `Companions::StatScalePct` is 100 (default), the
values match directly. If non-100, the test must account for scaling:
`expected = (int)(npc_type->STR * RuleI(Companions, StatScalePct) / 100)`.
The test should read the rule value and compute expected accordingly.

#### Test 1.4: Combat Role Assignment

```
Test: "Construction > Warrior gets COMBAT_ROLE_MELEE_TANK"
Action: Create warrior companion (class=1)
Assert: comp->GetCombatRole() == COMBAT_ROLE_MELEE_TANK

Test: "Construction > Rogue gets COMBAT_ROLE_ROGUE"
Action: Create rogue companion (class=9)
Assert: comp->GetCombatRole() == COMBAT_ROLE_ROGUE

Test: "Construction > Cleric gets COMBAT_ROLE_HEALER"
Action: Create cleric companion (class=2)
Assert: comp->GetCombatRole() == COMBAT_ROLE_HEALER

Test: "Construction > Wizard gets COMBAT_ROLE_CASTER_DPS"
Action: Create wizard companion (class=12)
Assert: comp->GetCombatRole() == COMBAT_ROLE_CASTER_DPS

Test: "Construction > Monk gets COMBAT_ROLE_MELEE_DPS"
Action: Create monk companion (class=7)
Assert: comp->GetCombatRole() == COMBAT_ROLE_MELEE_DPS
```

#### Test 1.5: Default Stance and State

```
Test: "Construction > Default stance is BALANCED"
Assert: comp->GetStance() == COMPANION_STANCE_BALANCED

Test: "Construction > Not suspended by default"
Assert: comp->IsSuspended() == false

Test: "Construction > Not dismissed by default"
Assert: comp->IsDismissed() == false

Test: "Construction > Companion ID is 0 before save"
Assert: comp->GetCompanionID() == 0

Test: "Construction > Owner char ID matches constructor arg"
Assert: comp->GetOwnerCharacterID() == owner_char_id

Test: "Construction > Recruited NPC type ID matches source"
Assert: comp->GetRecruitedNPCTypeID() == npc_type->npc_id

Test: "Construction > Recruited level matches NPCType level"
Assert: comp->GetRecruitedLevel() == npc_type->level
```

#### Test 1.6: Inventory Profile Initialization

```
Test: "Construction > Inventory version is MobVersion::NPC"
Action: Check that GetInv() is initialized (non-crash when accessed)
Assert: (Access does not segfault — verified by calling GetInv().GetItem(0))

Test: "Construction > Equipment slots are all zero"
Assert: For each slot in [0..EQUIPMENT_END], comp->GetEquipment(slot) == 0
```

#### Test 1.7: Flee Immunity

```
Test: "Construction > Flee immunity set when rule is off"
Action: Read RuleB(Companions, CompanionFleeEnabled)
Assert: If false, comp->GetSpecialAbilityParam(SpecialAbility::FleeingImmunity, 0) == 1
```

**Total tests in Suite 1: ~25**

---

### Suite 2: Equipment Tests

**Purpose:** Verify the GiveItem/RemoveItem/LoadEquipment/SaveEquipment
pipeline works correctly, including inventory profile population, CalcBonuses
integration, and wear change messaging.

#### Test 2.1: GiveItem Basic

```
Test: "Equipment > GiveItem returns true for valid slot"
Action: Create companion, call GiveItem(weapon_id, slotPrimary)
Assert: Returns true

Test: "Equipment > GiveItem populates m_equipment array"
Assert: comp->GetEquipment(slotPrimary) == weapon_id

Test: "Equipment > GiveItem populates inventory profile"
Assert: comp->GetInv().GetItem(slotPrimary) != nullptr
Assert: comp->GetInv().GetItem(slotPrimary)->GetID() == weapon_id
```

#### Test 2.2: GiveItem Weapon Data Accessible

```
Test: "Equipment > Equipped weapon has valid item data"
Action: Equip a known weapon (e.g., Fine Steel Long Sword)
Assert: auto inst = comp->GetInv().GetItem(slotPrimary);
        inst->GetItem() != nullptr
        inst->GetItem()->Damage > 0
        inst->GetItem()->Delay > 0
```

**Why this matters:** The Phase 1 Attack() override will call
`GetInv().GetItem(Hand)` and read `GetItem()->Damage`. If this chain returns
null or zero, the weapon damage path fails. This test catches that problem
at the scaffolding stage.

#### Test 2.3: GiveItem Invalid Slot

```
Test: "Equipment > GiveItem returns false for invalid slot (negative)"
Assert: comp->GiveItem(weapon_id, -1) == false

Test: "Equipment > GiveItem returns false for invalid slot (too high)"
Assert: comp->GiveItem(weapon_id, EQ::invslot::EQUIPMENT_END + 1) == false
```

#### Test 2.4: RemoveItemFromSlot

```
Test: "Equipment > RemoveItemFromSlot clears m_equipment"
Action: Equip weapon, then remove
Assert: comp->GetEquipment(slotPrimary) == 0

Test: "Equipment > RemoveItemFromSlot clears inventory profile"
Assert: comp->GetInv().GetItem(slotPrimary) == nullptr
```

#### Test 2.5: CalcBonuses After Equipment Change

```
Test: "Equipment > Stats change after equipping stat item"
Action: Record comp->GetSTR() before. Equip an item with +STR.
        Record comp->GetSTR() after.
Assert: STR_after > STR_before

Test: "Equipment > Stats revert after removing stat item"
Action: Remove the STR item.
Assert: comp->GetSTR() == STR_before (back to original)
```

**Item selection:** Find an item with known stat bonuses:
```cpp
// Find an item with astr > 0 (adds STR)
auto results = content_db.QueryDatabase(
    "SELECT id, astr FROM items WHERE astr > 5 AND itemtype IN (0,1,2,3,4,5,10,23,24,25,26,27,28,33,34,35,45) LIMIT 1"
);
```

#### Test 2.6: Multiple Equipment Slots

```
Test: "Equipment > Equipping multiple slots all register"
Action: Equip primary weapon, secondary weapon, head armor, chest armor
Assert: All four GetEquipment() calls return correct IDs
Assert: All four GetInv().GetItem() calls return non-null
```

#### Test 2.7: Equipment Overwrite

```
Test: "Equipment > Equipping to occupied slot replaces item"
Action: Equip weapon A in primary, then equip weapon B in primary
Assert: comp->GetEquipment(slotPrimary) == weapon_B_id
Assert: comp->GetInv().GetItem(slotPrimary)->GetID() == weapon_B_id
```

#### Test 2.8: Bow/Arrow Flags

```
Test: "Equipment > Equipping bow sets BowEquipped flag"
Action: Find a bow item (itemtype=27/ItemTypeBow), equip in slotRange
Assert: comp->HasBowEquipped() == true

Test: "Equipment > Equipping arrows sets ArrowEquipped flag"
Action: Find an arrow item (itemtype=29/ItemTypeArrow), equip in slotAmmo
Assert: comp->HasArrowEquipped() == true

Test: "Equipment > HasBowAndArrowEquipped true when both present"
Assert: comp->HasBowAndArrowEquipped() == true (after equipping both)
```

#### Test 2.9: SaveEquipment / LoadEquipment Round-Trip

```
Test: "Equipment > SaveEquipment + LoadEquipment round-trip preserves items"
Action:
  1. Create companion, save to DB (comp->Save()), note companion_id
  2. Equip 3 items via GiveItem (which calls SaveEquipment internally)
  3. Clear all m_equipment entries and inventory manually
  4. Call LoadEquipment()
  5. Verify all 3 items restored
Assert: All 3 slots have correct item IDs
Assert: GetInv().GetItem() returns non-null for all 3 slots
```

**Note:** This requires the companion to have been saved (companion_id > 0)
since LoadEquipment queries `companion_inventories WHERE companion_id = X`.

**Total tests in Suite 2: ~20**

---

### Suite 3: Melee Combat Tests

**Purpose:** Verify the melee attack pipeline for companions, both the
CURRENT behavior (delegates to NPC::Attack) and the FUTURE behavior
(Phase 1: weapon damage). This suite establishes baseline tests that will
FAIL after Phase 1 implementation (proving the change works) alongside
tests that should ALWAYS pass.

#### Test 3.1: Attack Method Exists and Is Callable

```
Test: "Combat > Companion::Attack does not crash with valid target"
Action: Create warrior companion and a target NPC, call comp->Attack(target)
Assert: Does not crash (test passes if we reach the next line)
```

**Target NPC creation:**
```cpp
auto target_type = content_db.LoadNPCTypesData(some_npc_id);
auto target = new NPC(target_type, nullptr, glm::vec4(5, 5, 0, 0), GravityBehavior::Water);
entity_list.AddNPC(target);
```

#### Test 3.2: Attack Safety — No Attacking Owner

```
Test: "Combat > Attack returns false when target is owner"
Action: This test is conceptual — we cannot create a real Client in CLI tests.
        Instead, test the null-owner path.
Assert: comp->Attack(nullptr) returns false
```

**Note:** Full owner/group safety tests require a Client object, which cannot
be constructed in CLI tests (requires network connection). The null-target
test verifies the safety check exists. Full owner-safety testing requires
the game-tester running in a live server.

#### Test 3.3: Current Damage Source (Pre-Phase 1 Baseline)

```
Test: "Combat > [BASELINE] Unarmed companion uses GetBaseDamage()"
Action: Create unarmed warrior companion
Assert: comp->GetBaseDamage() > 0 (damage comes from npc_types)
Assert: comp->GetMinDamage() >= 0
```

This test establishes the CURRENT behavior. After Phase 1, these values
still exist but may not be the damage source when a weapon is equipped.

#### Test 3.4: Weapon Data Access for Future Damage Path

```
Test: "Combat > GetInv().GetItem(slotPrimary)->GetItem()->Damage readable"
Action: Equip a weapon, read its Damage field
Assert: weapon->Damage > 0

Test: "Combat > GetInv().GetItem(slotPrimary)->GetItem()->Delay readable"
Assert: weapon->Delay > 0
```

These tests verify the data chain that Phase 1 Attack() override will use.

#### Test 3.5: GetWeaponDamage Callable on Companion

```
Test: "Combat > Mob::GetWeaponDamage callable with companion weapon"
Action: Create companion, equip weapon, create target NPC
        Call comp->GetWeaponDamage(target, weapon_inst)
Assert: Return value > 0 (weapon can damage the target)
```

**Why this matters:** `GetWeaponDamage()` is a Mob method that Phase 1 will
call. If it returns 0 for companion-held weapons (due to some NPC-specific
check), the entire weapon damage path breaks. This test catches that.

#### Test 3.6: GetWeaponDamageBonus Callable on Companion

```
Test: "Combat > Mob::GetWeaponDamageBonus callable on companion"
Action: Create level 30 warrior companion (above level 28 threshold)
        Equip a weapon with delay 35
        Call comp->GetWeaponDamageBonus(weapon_data)
Assert: Return value > 0 (level 30 warrior with delay 35 gets bonus)

Test: "Combat > GetWeaponDamageBonus returns 0 below level 28"
Action: Create level 20 companion
        Call comp->GetWeaponDamageBonus(weapon_data)
Assert: Return value == 0
```

#### Test 3.7: Attack Animation Works with Inventory Weapon

```
Test: "Combat > AttackAnimation callable with companion weapon"
Action: Create companion, equip slashing weapon
        Call comp->AttackAnimation(slotPrimary, weapon_inst) or equivalent
Assert: Does not crash, returns a valid skill type
```

#### Test 3.8: SetAttackTimer Callable

```
Test: "Combat > NPC::SetAttackTimer does not crash on companion"
Action: Create companion, call comp->SetAttackTimer() (via CalcBonuses)
Assert: Primary attack timer is enabled
Assert: Timer duration > 0
```

**Note:** `SetAttackTimer()` is virtual. Before Phase 1, the NPC version
runs. After Phase 1, the Companion override runs. Both should work.

#### Test 3.9: Double Attack Check

```
Test: "Combat > CheckDoubleAttack callable on companion"
Action: Create level 50 warrior companion
        This test verifies the function exists and doesn't crash.
Assert: Result is bool (true or false, not crash)
```

#### Test 3.10: DoDamageCaps Callable

```
Test: "Combat > DoDamageCaps callable on companion"
Action: Call comp->DoDamageCaps(1000)
Assert: Return value <= 1000 and > 0 (caps applied or value passed through)
```

**Total tests in Suite 3: ~15**

---

### Suite 4: Defense Tests

**Purpose:** Verify the defensive combat pipeline — avoidance skills, AC
calculation, and the IsOfClientBot avoidance path selection.

#### Test 4.1: Avoidance Skills Present

```
Test: "Defense > Warrior has dodge skill > 0"
Action: Create level 50 warrior companion
Assert: comp->GetSkill(EQ::skills::SkillDodge) > 0

Test: "Defense > Warrior has parry skill > 0"
Assert: comp->GetSkill(EQ::skills::SkillParry) > 0

Test: "Defense > Warrior has riposte skill > 0"
Assert: comp->GetSkill(EQ::skills::SkillRiposte) > 0

Test: "Defense > Warrior has defense skill > 0"
Assert: comp->GetSkill(EQ::skills::SkillDefense) > 0

Test: "Defense > Warrior has block skill > 0"
Assert: comp->GetSkill(EQ::skills::SkillBlock) > 0
```

**Why these matter:** NPC constructor (npc.cpp:368-369) populates skills
from `SkillCaps`. If the skill_caps table lacks entries for the companion's
class, these will be zero. Zero skills = zero avoidance despite IsOfClientBot
routing to the skill-based path. This test detects that silent failure.

#### Test 4.2: Rogue Has Class-Appropriate Skills

```
Test: "Defense > Rogue has dodge skill > 0"
Assert: comp->GetSkill(EQ::skills::SkillDodge) > 0

Test: "Defense > Rogue has parry skill > 0 (gets at level 12)"
Action: Create level 50 rogue
Assert: comp->GetSkill(EQ::skills::SkillParry) > 0

Test: "Defense > Rogue has riposte skill > 0 (gets at level 30)"
Assert: comp->GetSkill(EQ::skills::SkillRiposte) > 0
```

#### Test 4.3: Caster Has Low/No Combat Avoidance

```
Test: "Defense > Wizard has no parry skill"
Action: Create level 50 wizard
Assert: comp->GetSkill(EQ::skills::SkillParry) == 0

Test: "Defense > Wizard has no riposte skill"
Assert: comp->GetSkill(EQ::skills::SkillRiposte) == 0

Test: "Defense > Wizard has no block skill"
Assert: comp->GetSkill(EQ::skills::SkillBlock) == 0

Test: "Defense > Wizard has defense skill > 0"
Assert: comp->GetSkill(EQ::skills::SkillDefense) > 0 (all classes get some defense)
```

#### Test 4.4: Skill Scale with Level

```
Test: "Defense > Level 10 warrior has lower defense than level 50"
Action: Create a level 10 warrior and a level 50 warrior
Assert: warrior_10->GetSkill(SkillDefense) < warrior_50->GetSkill(SkillDefense)
```

**Note:** Requires two different NPC types at different levels, or a single
type + ScaleStatsToLevel. If using ScaleStatsToLevel, note that it does not
currently re-assign skills (it only scales stats). The NPC constructor sets
skills based on the NPC's level at construction time.

#### Test 4.5: AC Calculation

```
Test: "Defense > Companion has non-zero AC"
Action: Create warrior companion
Assert: comp->GetAC() > 0

Test: "Defense > Companion AC increases with equipment"
Action: Record AC before. Equip an armor item with AC stat.
        Record AC after.
Assert: AC_after > AC_before
```

#### Test 4.6: IsOfClientBot Avoidance Path

```
Test: "Defense > IsOfClientBot returns true for avoidance path"
Action: Verify the flag that routes AvoidDamage to Client/Bot path
Assert: comp->IsOfClientBot() == true
```

This is already covered in Suite 1, but explicitly tested here in the
defense context to document that the avoidance path is correct.

#### Test 4.7: Offense Skill

```
Test: "Defense > Warrior has offense skill > 0"
Assert: comp->GetSkill(EQ::skills::SkillOffense) > 0

Test: "Defense > Wizard has lower offense than warrior"
Action: Create both
Assert: wizard->GetSkill(SkillOffense) < warrior->GetSkill(SkillOffense)
```

**Total tests in Suite 4: ~18**

---

### Suite 5: Stats Tests

**Purpose:** Verify stat computation, item bonuses, spell bonuses, stat
scaling, and the CalcBonuses pipeline.

#### Test 5.1: CalcBonuses Does Not Crash

```
Test: "Stats > CalcBonuses completes without crash"
Action: Create companion, call CalcBonuses()
Assert: Reaches next line (no crash)
```

#### Test 5.2: Item Bonuses Apply

```
Test: "Stats > Item STR bonus applies"
Action: Record GetSTR(). Equip item with +STR. Read GetSTR() again.
Assert: New STR = old STR + item's astr value

Test: "Stats > Item AC bonus applies"
Action: Record GetAC(). Equip item with +AC. Read GetAC() again.
Assert: New AC > old AC
```

#### Test 5.3: Item Haste Applies

```
Test: "Stats > Item haste bonus applies"
Action: Equip an item with haste% > 0
Assert: comp->GetHaste() > 100 (100 = no haste, higher = faster)
```

**Item selection:** Find an item with haste: `SELECT id FROM items WHERE haste > 0 LIMIT 1`

#### Test 5.4: Mana Regen

```
Test: "Stats > CalcManaRegen returns > 0 for caster companion"
Action: Create cleric companion (mana user)
Assert: comp->CalcManaRegen() > 0

Test: "Stats > CalcManaRegen returns 0 for warrior companion"
Action: Create warrior (no mana)
Assert: comp->CalcManaRegen() == 0
```

#### Test 5.5: HP Regen

```
Test: "Stats > CalcHPRegen returns >= HPRegenPerTic rule floor"
Action: Create companion
Assert: comp->CalcHPRegen() >= RuleI(Companions, HPRegenPerTic)
```

#### Test 5.6: ScaleStatsToLevel

```
Test: "Stats > ScaleStatsToLevel increases stats proportionally"
Action: Create level 30 companion. Record STR. Scale to level 45.
Assert: New STR approximately = old STR * (45.0 / 30.0)

Test: "Stats > ScaleStatsToLevel increases HP proportionally"
Assert: New MaxHP approximately = old MaxHP * (45.0 / 30.0)
```

#### Test 5.7: ApplyStatScalePct

```
Test: "Stats > StatScalePct at 100 leaves stats unchanged"
Action: When StatScalePct rule == 100, stats match NPCType directly
Assert: Stats unchanged (this is the default case)
```

**Note:** Testing StatScalePct != 100 requires changing the rule at runtime,
which is possible via `RuleManager::Instance()->SetRule()` in C++.

#### Test 5.8: Base Stat Storage

```
Test: "Stats > Base stats stored correctly at construction"
Action: Create companion from NPCType with known STR
Assert: comp->GetRecruitedLevel() == npc_type->level
        (m_base_str is private; verify indirectly via ScaleStatsToLevel)
```

**Total tests in Suite 5: ~15**

---

### Suite 6: Spells Tests

**Purpose:** Verify the companion spell AI infrastructure: spell loading,
class-specific spell assignment, spell type filtering, stance matching,
and recast timer management.

#### Test 6.1: LoadCompanionSpells Loads Spells

```
Test: "Spells > LoadCompanionSpells returns true for cleric"
Action: Create cleric companion, call LoadCompanionSpells()
Assert: Returns true (if companion_spell_sets has cleric entries)
Assert: comp->GetCompanionSpells().size() > 0

Test: "Spells > LoadCompanionSpells returns true for warrior"
Action: Create warrior companion
Assert: May return false if warriors have no spells in companion_spell_sets
        (warriors are melee-only). Test documents actual behavior.
```

**Note:** These tests depend on the `companion_spell_sets` table being
populated for the tested classes. If the table is empty, these tests will
skip or document that as a finding.

#### Test 6.2: Spell Stance Filtering

```
Test: "Spells > StanceMatch returns true for stance=0 (all stances)"
Test: "Spells > StanceMatch returns true for matching positive stance"
Test: "Spells > StanceMatch returns false for non-matching positive stance"
Test: "Spells > StanceMatch returns true for negative stance (all except)"
Test: "Spells > StanceMatch returns false for negative stance matching exception"
```

**Note:** `StanceMatch()` is a static function in companion_ai.cpp. These
tests cannot call it directly unless it is exposed. Options:
1. Test it indirectly via AICastSpell behavior
2. Move it to the header (simple refactor)
3. Replicate the logic in the test for verification

Recommended: Test indirectly via observable behavior (spell selection
changes with stance).

#### Test 6.3: Spell Type Filtering

```
Test: "Spells > Cleric companion has SpellType_Heal spells"
Action: Create cleric, load spells, iterate GetCompanionSpells()
Assert: At least one spell with type containing SpellType_Heal bit
```

#### Test 6.4: Recast Timer Management

```
Test: "Spells > SetSpellTimeCanCast sets future timestamp"
Action: Call comp->SetSpellTimeCanCast(spell_id, 5000)
Assert: comp->CheckSpellRecastTimers(spell_id) returns false (on cooldown)

Test: "Spells > CheckSpellRecastTimers returns true when not on cooldown"
Action: Call with a spell that has not been cast
Assert: Returns true
```

#### Test 6.5: GetChanceToCastBySpellType

```
Test: "Spells > Heal chance > 0 for cleric"
Action: Create cleric companion
Assert: comp->GetChanceToCastBySpellType(SpellType_Heal) > 0
```

**Total tests in Suite 6: ~12**

---

### Suite 7: Group Integration Tests

**Purpose:** Verify companion group membership, HasGroup/HasRaid returns,
and GetGroup behavior.

#### Test 7.1: HasRaid Returns False

```
Test: "Group > HasRaid always returns false"
Assert: comp->HasRaid() == false
```

#### Test 7.2: HasGroup Without Group

```
Test: "Group > HasGroup returns false when not in a group"
Action: Create companion, do not add to any group
Assert: comp->HasGroup() == false
```

#### Test 7.3: GetGroup Returns Null Without Group

```
Test: "Group > GetGroup returns nullptr when not in a group"
Assert: comp->GetGroup() == nullptr
```

#### Test 7.4: GetRaid Returns Null

```
Test: "Group > GetRaid always returns nullptr"
Assert: comp->GetRaid() == nullptr
```

**Note:** Full group integration tests (adding companion to a group, verifying
group membership) require a Client object to form the group. Client cannot
be constructed in CLI tests. These tests verify the no-group case. Full
group tests require the game-tester in a live environment.

**Total tests in Suite 7: ~5**

---

### Suite 8: Stance and Positioning Tests

**Purpose:** Verify stance assignment, stance changes, combat role
determination, and the DetermineRoleFromClass static method.

#### Test 8.1: Default Stance

```
Test: "Stance > Default stance is BALANCED"
Assert: comp->GetStance() == COMPANION_STANCE_BALANCED
```

#### Test 8.2: Stance Changes

```
Test: "Stance > SetStance changes to AGGRESSIVE"
Action: comp->SetStance(COMPANION_STANCE_AGGRESSIVE)
Assert: comp->GetStance() == COMPANION_STANCE_AGGRESSIVE

Test: "Stance > SetStance changes to PASSIVE"
Action: comp->SetStance(COMPANION_STANCE_PASSIVE)
Assert: comp->GetStance() == COMPANION_STANCE_PASSIVE

Test: "Stance > SetStance changes back to BALANCED"
Action: comp->SetStance(COMPANION_STANCE_BALANCED)
Assert: comp->GetStance() == COMPANION_STANCE_BALANCED
```

#### Test 8.3: DetermineRoleFromClass — All Classes

```
Test: "Stance > DetermineRoleFromClass(Warrior) == MELEE_TANK"
Assert: Companion::DetermineRoleFromClass(1) == COMBAT_ROLE_MELEE_TANK

Test: "Stance > DetermineRoleFromClass(Cleric) == HEALER"
Assert: Companion::DetermineRoleFromClass(2) == COMBAT_ROLE_HEALER

Test: "Stance > DetermineRoleFromClass(Paladin) == MELEE_TANK"
Assert: Companion::DetermineRoleFromClass(3) == COMBAT_ROLE_MELEE_TANK

Test: "Stance > DetermineRoleFromClass(Ranger) == MELEE_DPS"
Assert: Companion::DetermineRoleFromClass(4) == COMBAT_ROLE_MELEE_DPS

Test: "Stance > DetermineRoleFromClass(ShadowKnight) == MELEE_TANK"
Assert: Companion::DetermineRoleFromClass(5) == COMBAT_ROLE_MELEE_TANK

Test: "Stance > DetermineRoleFromClass(Druid) == HEALER"
Assert: Companion::DetermineRoleFromClass(6) == COMBAT_ROLE_HEALER

Test: "Stance > DetermineRoleFromClass(Monk) == MELEE_DPS"
Assert: Companion::DetermineRoleFromClass(7) == COMBAT_ROLE_MELEE_DPS

Test: "Stance > DetermineRoleFromClass(Bard) == MELEE_DPS"
Assert: Companion::DetermineRoleFromClass(8) == COMBAT_ROLE_MELEE_DPS

Test: "Stance > DetermineRoleFromClass(Rogue) == ROGUE"
Assert: Companion::DetermineRoleFromClass(9) == COMBAT_ROLE_ROGUE

Test: "Stance > DetermineRoleFromClass(Shaman) == HEALER"
Assert: Companion::DetermineRoleFromClass(10) == COMBAT_ROLE_HEALER

Test: "Stance > DetermineRoleFromClass(Necromancer) == CASTER_DPS"
Assert: Companion::DetermineRoleFromClass(11) == COMBAT_ROLE_CASTER_DPS

Test: "Stance > DetermineRoleFromClass(Wizard) == CASTER_DPS"
Assert: Companion::DetermineRoleFromClass(12) == COMBAT_ROLE_CASTER_DPS

Test: "Stance > DetermineRoleFromClass(Magician) == CASTER_DPS"
Assert: Companion::DetermineRoleFromClass(13) == COMBAT_ROLE_CASTER_DPS

Test: "Stance > DetermineRoleFromClass(Enchanter) == CASTER_DPS"
Assert: Companion::DetermineRoleFromClass(14) == COMBAT_ROLE_CASTER_DPS

Test: "Stance > DetermineRoleFromClass(Beastlord) == MELEE_DPS"
Assert: Companion::DetermineRoleFromClass(15) == COMBAT_ROLE_MELEE_DPS
```

#### Test 8.4: Sit/Stand

```
Test: "Stance > Sit sets sitting state"
Action: comp->Sit()
Assert: comp->IsSitting() == true

Test: "Stance > Stand clears sitting state"
Action: comp->Stand()
Assert: comp->IsSitting() == false
Assert: comp->IsStanding() == true
```

**Total tests in Suite 8: ~22**

---

## Part 3: Test Execution and Reporting

### 3.1 Execution Command

```bash
# Build the zone binary with test code included
docker exec -it akk-stack-eqemu-server-1 bash -c \
  "cd ~/code/build && ninja -j\$(nproc)"

# Stop any running zone processes (they conflict with test zone boot)
docker exec -it akk-stack-eqemu-server-1 bash -c \
  "pkill -f 'zone dynamic' || true"

# Run the companion tests
docker exec -it akk-stack-eqemu-server-1 bash -c \
  "cd ~/server && ~/code/build/bin/zone tests:companion"
```

### 3.2 Output Format

The test output follows the existing pattern from `cli_test_util.cpp`:

```
===========================================
Running Companion Tests...
===========================================

[PASS] Construction > Companion created from valid NPC type PASSED
[PASS] Construction > IsCompanion() returns true PASSED
[PASS] Construction > IsNPC() returns true PASSED
...
[PASS] Equipment > GiveItem returns true for valid slot PASSED
...
[FAIL] Combat > GetWeaponDamage returns > 0 for companion weapon FAILED
   Expected: > 0
   Got: 0
```

On first failure, `std::exit(1)` terminates the test run. This matches the
existing behavior: fail-fast, no continuing after a broken test.

### 3.3 Exit Codes

- **Exit 0:** All tests passed
- **Exit 1:** A test failed (RunTest called std::exit(1))
- **Non-zero other:** Zone boot failure, DB connection failure, etc.

### 3.4 Environment Requirements

1. **Database access:** The zone binary must be able to connect to MariaDB.
   Running from `~/server/` ensures `eqemu_config.json` is found.

2. **No running zone processes:** The test boots its own zone instance.
   Running zone servers will conflict on shared resources (entity IDs,
   zone slots, etc.). Stop all zone processes before testing.

3. **npc_types data:** Tests query `npc_types` for warriors, rogues, clerics,
   wizards. The PEQ database has thousands of NPCs, so finding test
   candidates should always succeed.

4. **items data:** Tests query `items` for weapons and stat items. The PEQ
   database has ~100,000 items. Finding test items will always succeed.

5. **companion_spell_sets data:** Spell tests require this custom table to
   be populated. If empty, spell tests should skip gracefully (print SKIP,
   not FAIL).

6. **DEBUG mode:** Set `DEBUG=1` environment variable for verbose zone boot
   logging during test development:
   ```bash
   DEBUG=1 ~/code/build/bin/zone tests:companion
   ```

### 3.5 Test Isolation

Each test suite calls `CleanupTestCompanions()` after completing. This
removes all Companion entities from the entity list.

DB state: Tests that persist companions to the database (Save/Load round-trip
tests) should clean up their DB rows. A `CleanupTestDB()` function should
delete rows from:
- `companion_data WHERE owner_id = 0` (test companions have owner_id=0)
- `companion_inventories WHERE companion_id IN (cleaned companions)`
- `companion_buffs WHERE companion_id IN (cleaned companions)`

This function should be called at the START of the test run (not just the
end) to clean up leftover data from crashed previous runs.

---

## Part 4: Phased Test Addition Strategy

### TDD Approach

The test scaffolding is built FIRST, before any Phase 1 code. Tests are
organized so that:

1. **Scaffolding tests** (Suites 1-8 as described above) verify CURRENT
   behavior. They should all pass on the unmodified codebase.

2. **Phase 1 tests** are ADDED to the existing suites when Phase 1
   implementation begins. They test the NEW behavior (weapon damage, weapon
   delay). Some of these tests will be written to FAIL initially (red),
   then the code is written to make them pass (green).

3. **Regression tests** are existing tests that must CONTINUE to pass after
   Phase 1 changes. If a Phase 1 change breaks a scaffolding test, it
   indicates a regression.

### Phase 1: Tests to Add (Weapons Come Alive)

When Phase 1 implementation begins, add these tests to the existing suites:

**Suite 3 (Melee Combat) — new tests:**

```
Test: "Combat > [P1] Equipped weapon damage > NPC base damage when weapon is better"
Action: Create companion. Equip high-damage weapon.
        Read weapon->Damage. Compare to GetBaseDamage().
Assert: weapon->Damage > GetBaseDamage() (test only passes with weapon-focused NPC)

Test: "Combat > [P1] SetAttackTimer uses weapon delay when UseWeaponDamage=true"
Action: Create companion. Equip weapon with delay=20. Call SetAttackTimer().
Assert: Primary attack timer period reflects delay 20 (approximately 2000ms / haste)

Test: "Combat > [P1] SetAttackTimer uses weapon delay for offhand"
Action: Dual-wield eligible class. Equip secondary weapon.
Assert: DW attack timer enabled and reflects offhand weapon delay

Test: "Combat > [P1] SetAttackTimer falls back to NPC delay when rule=false"
Action: Set UseWeaponDamage rule to false. Call SetAttackTimer().
Assert: Timer matches npc_types.attack_delay behavior

Test: "Combat > [P1] Damage bonus applied at level 28+ warrior"
Action: Level 30 warrior with weapon. Call GetWeaponDamageBonus().
Assert: Returns > 0

Test: "Combat > [P1] Damage bonus NOT applied below level 28"
Action: Level 20 warrior with weapon. Call GetWeaponDamageBonus().
Assert: Returns 0

Test: "Combat > [P1] Damage bonus NOT applied to casters"
Action: Level 40 wizard. Call IsWarriorClass().
Assert: Returns false (wizards don't get damage bonus)

Test: "Combat > [P1] Unarmed fallback uses GetBaseDamage"
Action: Create companion with NO weapon. UseWeaponDamage=true.
Assert: Attack path uses GetBaseDamage() (NPC path)

Test: "Combat > [P1] Two-hander disables dual wield timer"
Action: Equip two-handed weapon in primary. Call SetAttackTimer().
Assert: DW attack timer is disabled

Test: "Combat > [P1] Weapon change updates timer via CalcBonuses"
Action: Equip slow weapon (delay=40). Record timer.
        Remove and equip fast weapon (delay=20). Record timer.
Assert: Timer shortened after faster weapon equipped
```

**Suite 2 (Equipment) — new tests:**

```
Test: "Equipment > [P1] GetInv().GetItem(slotPrimary)->IsWeapon() for weapon"
Action: Equip a weapon
Assert: GetItem(slotPrimary)->IsWeapon() == true

Test: "Equipment > [P1] GetInv().GetItem(slotPrimary)->IsWeapon() false for armor"
Action: Equip armor in a non-weapon slot, check weapon slots
Assert: Non-weapon items return false for IsWeapon()
```

### Phase 2: Tests to Add (Combat Skills)

```
Test: "Defense > [P2] Skills scale with level proportionally"
Action: Create level 20 and level 50 warriors
Assert: Level 50 defense > level 20 defense
Assert: Level 50 parry > level 20 parry

Test: "Defense > [P2] Warrior skills >= Rogue skills at same level"
Assert: Warrior parry >= Rogue parry
Assert: Warrior riposte >= Rogue riposte

Test: "Combat > [P2] Triple attack available for level 56+ warrior"
Test: "Combat > [P2] Triple attack NOT available for level 55 warrior"
Test: "Combat > [P2] Triple attack available for level 60+ monk"
```

### Phase 3: Tests to Add (Stats Drive Survivability)

```
Test: "Stats > [P3] STA from items increases max HP"
Action: Equip +30 STA item on warrior
Assert: MaxHP increased by approximately 30 * (HP-per-STA factor)

Test: "Stats > [P3] Sitting HP regen > standing HP regen"
Action: Record CalcHPRegen while standing, then while sitting
Assert: Sitting regen > standing regen

Test: "Stats > [P3] Defense skill AC divisor is /3 for melee, not /5"
(This is harder to test directly — may require reading ACSum output)
```

### Phase 4: Tests to Add (Spell System Tuning)

```
Test: "Spells > [P4] Cleric heal threshold is 80% (not 90%)"
Test: "Spells > [P4] Shaman slow priority is first action"
Test: "Spells > [P4] Mana cutoff at 20% for DPS casters"
Test: "Spells > [P4] No standard buffs during combat"
```

These are harder to test via CLI since they require simulating combat
AI decision loops. They may be better suited for game-tester validation
in a live environment. However, threshold values that are exposed as
constants or rule values can be tested directly.

### Phase 5: Tests to Add (Polish)

```
Test: "Stats > [P5] Resist capped at level-appropriate value"
Action: Create companion with very high base resist + item resists
Assert: Final resist value <= cap

Test: "Stats > [P5] Focus effects apply to companion spell casts"
(Requires simulating a spell cast with focus item equipped)
```

---

## Part 5: Task Breakdown for Implementation

### Task 1: Create Test Utility Header

**File to create:** `eqemu/zone/cli/tests/cli_companion_test_util.h`
**Agent:** c-expert
**Dependencies:** None
**Scope:** ~200 lines

**Exact actions:**
1. Create the header file with `#pragma once`
2. Add includes for: `companion.h`, `zone.h`, `entity.h`, `item_data.h`,
   companion repository headers
3. Declare `extern Zone *zone` and forward-declare `RunTest()` overloads
   and `SetupZone()`
4. Implement `SetupCompanionTestZone()` (inline)
5. Implement `CreateTestCompanion()` (inline)
6. Implement `CreateTestCompanionByClass()` (inline)
7. Implement `FindNPCTypeIDForClassLevel()` (inline)
8. Implement `EquipCompanionItem()` (inline)
9. Implement `CleanupTestCompanions()` (inline)
10. Implement extended assertion functions: `RunTestFloat()`, `RunTestRange()`,
    `RunTestGreaterThan()`, `RunTestNotNull()` (all inline)
11. Implement `FindItemByName()` and `FindWeapon()` (inline)

**Acceptance criteria:**
- Header compiles without errors when included
- All helper functions are self-contained (no external .cpp needed)
- Uses `content_db.QueryDatabase()` for NPC and item lookups
- Uses `content_db.LoadNPCTypesData()` for NPCType loading

---

### Task 2: Create Test Entry Point and Registration

**Files to modify:**
- `eqemu/zone/zone_cli.h` — add `TestCompanion` declaration
- `eqemu/zone/zone_cli.cpp` — add `tests:companion` registration
- `eqemu/zone/CMakeLists.txt` — add `cli/tests/cli_companion_tests.cpp`

**File to create:** `eqemu/zone/cli/tests/cli_companion_tests.cpp` (skeleton only)

**Agent:** c-expert
**Dependencies:** Task 1
**Scope:** ~50 lines (skeleton + includes + minimal entry point)

**Exact actions:**
1. In `zone_cli.h`, add after line 19:
   ```cpp
   static void TestCompanion(int argc, char **argv, argh::parser &cmd, std::string &description);
   ```

2. In `zone_cli.cpp`, add after line 39 (in CommandHandler):
   ```cpp
   function_map["tests:companion"] = &ZoneCLI::TestCompanion;
   ```

3. In `CMakeLists.txt`, add after `cli/tests/cli_zone_state.cpp`:
   ```cmake
   cli/tests/cli_companion_tests.cpp
   ```

4. Create `cli_companion_tests.cpp` with:
   ```cpp
   #include "zone/zone_cli.h"
   #include "cli_companion_test_util.h"

   // Forward declarations
   extern Zone *zone;
   void RunTest(const std::string& test_name, const std::string& expected, const std::string& actual);
   void RunTest(const std::string& test_name, bool expected, bool actual);
   void RunTest(const std::string& test_name, int expected, int actual);

   void ZoneCLI::TestCompanion(int argc, char **argv, argh::parser &cmd, std::string &description)
   {
       description = "Run companion system integration tests";
       if (cmd[{"-h", "--help"}]) { return; }

       SetupCompanionTestZone();

       std::cout << "===========================================\n";
       std::cout << "Running Companion Tests...\n";
       std::cout << "===========================================\n\n";

       // Test suites will be added in subsequent tasks

       std::cout << "\n===========================================\n";
       std::cout << "All Companion Tests Completed!\n";
       std::cout << "===========================================\n";
   }
   ```

**Acceptance criteria:**
- `ninja` build succeeds
- `zone tests:companion` runs, prints banner, exits 0
- `zone --help` or `zone tests:companion --help` lists the test

---

### Task 3: Implement Suite 1 — Construction Tests

**File to modify:** `eqemu/zone/cli/tests/cli_companion_tests.cpp`
**Agent:** c-expert
**Dependencies:** Task 1, Task 2
**Scope:** ~200 lines

**Exact actions:**
1. Add `inline void TestCompanionConstruction()` function
2. Implement all ~25 tests from Suite 1 specification above
3. Call `TestCompanionConstruction()` from `TestCompanion()` entry point
4. Call `CleanupTestCompanions()` after the suite

**Key implementation notes:**
- Use `CreateTestCompanionByClass()` to create test companions
- Test at least 4 different classes: warrior (1), rogue (9), cleric (2), wizard (12)
- Account for `StatScalePct` rule when asserting stat values
- Test combat role assignment for all 15 classes if feasible (or at least
  one per role category)

**Acceptance criteria:**
- All construction tests pass on unmodified codebase
- Tests cover: identity flags, stats, combat role, stance, inventory init

---

### Task 4: Implement Suite 2 — Equipment Tests

**File to modify:** `eqemu/zone/cli/tests/cli_companion_tests.cpp`
**Agent:** c-expert
**Dependencies:** Task 3 (for the shared helpers, but can be developed in parallel)
**Scope:** ~250 lines

**Exact actions:**
1. Add `inline void TestCompanionEquipment()` function
2. Implement all ~20 tests from Suite 2 specification
3. Add to the entry point with cleanup between suites

**Key implementation notes:**
- Use `FindWeapon()` to locate test weapons dynamically
- Use DB queries to find items with specific stat bonuses
- The Save/Load round-trip test (Test 2.9) requires calling `comp->Save()`
  first to get a companion_id, then manipulating equipment and reloading.
  Ensure cleanup deletes the test companion_data row.

**Acceptance criteria:**
- All equipment tests pass
- Tests verify both m_equipment[] and GetInv() consistency
- Round-trip persistence test cleans up DB rows

---

### Task 5: Implement Suite 3 — Melee Combat Tests

**File to modify:** `eqemu/zone/cli/tests/cli_companion_tests.cpp`
**Agent:** c-expert
**Dependencies:** Task 4
**Scope:** ~200 lines

**Exact actions:**
1. Add `inline void TestCompanionMeleeCombat()` function
2. Implement all ~15 tests from Suite 3 specification
3. Create target NPCs for attack tests

**Key implementation notes:**
- For `Attack()` tests, create a target NPC and call `comp->Attack(target)`.
  The attack may or may not hit (RNG-dependent). The test verifies the call
  does not crash, not that it hits.
- `GetWeaponDamage()` is `Mob::GetWeaponDamage()`. Call it on the companion
  with a weapon equipped. It takes (Mob* target, const EQ::ItemInstance* weapon)
  or (Mob* target, const EQ::ItemData* weapon). Verify which overload to use.
- `GetWeaponDamageBonus()` takes `const EQ::ItemData*`. Access via
  `GetInv().GetItem(slot)->GetItem()`.
- Tests marked `[BASELINE]` document current behavior. They will NOT be
  removed after Phase 1 — they will be updated to test the new behavior.

**Acceptance criteria:**
- All combat baseline tests pass on unmodified codebase
- GetWeaponDamage/GetWeaponDamageBonus callable without crash
- Attack can be invoked without crash

---

### Task 6: Implement Suite 4 — Defense Tests

**File to modify:** `eqemu/zone/cli/tests/cli_companion_tests.cpp`
**Agent:** c-expert
**Dependencies:** Task 3
**Scope:** ~150 lines

**Exact actions:**
1. Add `inline void TestCompanionDefense()` function
2. Implement all ~18 tests from Suite 4 specification

**Key implementation notes:**
- `GetSkill()` returns the current skill value for the companion. Since the
  NPC constructor populates skills from SkillCaps, these should be > 0 for
  classes that have those skills at the tested level.
- If a skill test FAILS (value is 0), that is valuable information: it means
  the skill_caps table lacks entries for that class/skill combination. This
  finding should be documented as it affects Phase 2 planning.
- Compare skills across classes and levels to verify relative ordering.

**Acceptance criteria:**
- Defense tests pass or produce actionable diagnostic output
- Skill presence/absence matches class expectations
- AC tests verify non-zero values and equipment impact

---

### Task 7: Implement Suite 5 — Stats Tests

**File to modify:** `eqemu/zone/cli/tests/cli_companion_tests.cpp`
**Agent:** c-expert
**Dependencies:** Task 4
**Scope:** ~150 lines

**Exact actions:**
1. Add `inline void TestCompanionStats()` function
2. Implement all ~15 tests from Suite 5 specification

**Key implementation notes:**
- For item bonus tests, find items with specific stat bonuses via DB query.
  The item must be equippable in a valid slot (e.g., ring with +STR for
  slotFinger1).
- For ScaleStatsToLevel, the companion must have been constructed at one
  level, then ScaleStatsToLevel called with a different level. Use
  `RunTestRange()` for approximate checks since float scaling introduces
  rounding.
- CalcManaRegen depends on class. Warriors return 0, casters return > 0.
- CalcHPRegen should return >= HPRegenPerTic rule value.

**Acceptance criteria:**
- All stat tests pass
- Item bonuses demonstrably change stats
- Level scaling produces proportional changes

---

### Task 8: Implement Suite 6 — Spells Tests

**File to modify:** `eqemu/zone/cli/tests/cli_companion_tests.cpp`
**Agent:** c-expert
**Dependencies:** Task 3
**Scope:** ~100 lines

**Exact actions:**
1. Add `inline void TestCompanionSpells()` function
2. Implement all ~12 tests from Suite 6 specification

**Key implementation notes:**
- Spell tests depend on `companion_spell_sets` table having data. If the
  table is empty for a class, tests should print `[SKIP]` and not fail.
  Implement a `SkipTest()` helper:
  ```cpp
  inline void SkipTest(const std::string& name, const std::string& reason) {
      std::cout << "[SKIP] " << name << " (" << reason << ")\n";
  }
  ```
- StanceMatch is a static function in companion_ai.cpp. To test it, either:
  (a) Change stance, load spells, verify different spell sets available
  (b) Replicate the logic in the test (not ideal but functional)
  (c) Expose StanceMatch via a public header (small refactor)

**Acceptance criteria:**
- Spell loading tests pass (or skip gracefully) for cleric and warrior
- Recast timer tests verify cooldown tracking
- Tests handle empty companion_spell_sets gracefully

---

### Task 9: Implement Suite 7 — Group Integration Tests

**File to modify:** `eqemu/zone/cli/tests/cli_companion_tests.cpp`
**Agent:** c-expert
**Dependencies:** Task 3
**Scope:** ~50 lines

**Exact actions:**
1. Add `inline void TestCompanionGroupIntegration()` function
2. Implement all ~5 tests from Suite 7 specification

**Key implementation notes:**
- These are the simplest tests. Verify HasRaid=false, HasGroup=false (when
  not in group), GetRaid=nullptr, GetGroup=nullptr.
- Full group membership tests require a Client object which cannot be
  constructed in CLI tests. Document this limitation.

**Acceptance criteria:**
- All group tests pass
- Tests document that full group testing requires live environment

---

### Task 10: Implement Suite 8 — Stance/Positioning Tests

**File to modify:** `eqemu/zone/cli/tests/cli_companion_tests.cpp`
**Agent:** c-expert
**Dependencies:** Task 3
**Scope:** ~200 lines

**Exact actions:**
1. Add `inline void TestCompanionStancePositioning()` function
2. Implement all ~22 tests from Suite 8 specification
3. Test DetermineRoleFromClass for all 15 classes

**Key implementation notes:**
- `DetermineRoleFromClass()` is a static method on Companion. It can be
  called without a companion instance: `Companion::DetermineRoleFromClass(1)`.
- Sit/Stand tests call `comp->Sit()` and `comp->Stand()`. These should
  toggle the sitting state flag without crashing.

**Acceptance criteria:**
- All stance and combat role tests pass
- All 15 classes mapped to correct combat roles
- Sit/stand toggle works correctly

---

### Task 11: Build and Run Full Test Suite

**Agent:** c-expert
**Dependencies:** Tasks 1-10
**Scope:** Build + run + fix any compilation issues

**Exact actions:**
1. Build: `docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`
2. Stop zone processes: `pkill -f 'zone dynamic'`
3. Run tests: `cd ~/server && ~/code/build/bin/zone tests:companion`
4. Fix any compilation errors or test failures
5. Document results: record which tests pass, which fail, and any
   unexpected findings (e.g., skills at 0 for certain classes)

**Acceptance criteria:**
- Build succeeds with no errors
- `zone tests:companion` runs to completion
- All tests pass or produce documented, expected failures
- Test output is saved to `claude/project-work/feature/npc-companion-realistic-stats/architect/context/test-results-baseline.md`

---

### Task Summary Table

| # | Task | Agent | Depends On | Scope | Description |
|---|------|-------|------------|-------|-------------|
| 1 | Create test utility header | c-expert | — | ~200 lines | Companion construction helpers, assertion macros, item/NPC finders |
| 2 | Create entry point and registration | c-expert | 1 | ~50 lines | zone_cli.h, zone_cli.cpp, CMakeLists.txt, skeleton test file |
| 3 | Suite 1: Construction tests | c-expert | 1, 2 | ~200 lines | Identity flags, stats, combat role, stance, inventory init |
| 4 | Suite 2: Equipment tests | c-expert | 1, 2 | ~250 lines | GiveItem, RemoveItem, CalcBonuses, Save/Load round-trip |
| 5 | Suite 3: Melee combat tests | c-expert | 1, 2, 4 | ~200 lines | Attack callable, weapon data access, damage functions |
| 6 | Suite 4: Defense tests | c-expert | 1, 2, 3 | ~150 lines | Avoidance skills, AC, IsOfClientBot path |
| 7 | Suite 5: Stats tests | c-expert | 1, 2, 4 | ~150 lines | CalcBonuses, item bonuses, haste, regen, scaling |
| 8 | Suite 6: Spells tests | c-expert | 1, 2, 3 | ~100 lines | LoadCompanionSpells, stance filtering, recast timers |
| 9 | Suite 7: Group integration tests | c-expert | 1, 2, 3 | ~50 lines | HasRaid, HasGroup, GetGroup, GetRaid |
| 10 | Suite 8: Stance/positioning tests | c-expert | 1, 2, 3 | ~200 lines | Stances, DetermineRoleFromClass, sit/stand |
| 11 | Build and run full suite | c-expert | 1-10 | Build+run | Compile, execute, document results |

**Total estimated code: ~1550 lines across 2 files**
- `cli_companion_test_util.h`: ~200 lines
- `cli_companion_tests.cpp`: ~1350 lines

**Total estimated tests: ~130**

---

## Appendix A: Reference Code Patterns

### Pattern 1: Zone State Test Structure (cli_zone_state.cpp)

```cpp
// Entry point pattern
void ZoneCLI::TestZoneState(int argc, char **argv, argh::parser &cmd, std::string &description)
{
    if (cmd[{"-h", "--help"}]) { return; }
    ClearState(); // clean slate
    SetupStateZone();
    zone->Repop(true);
    // ... banner ...
    TestZoneVariables();
    TestHpManaEnd();
    TestBuffs();
    // ... cleanup ...
}
```

### Pattern 2: NPC Construction in Tests (cli_npc_handins.cpp)

```cpp
auto npc_type = content_db.LoadNPCTypesData(754008);
if (npc_type) {
    auto npc = new NPC(npc_type, nullptr, glm::vec4(0, 0, 0, 0), GravityBehavior::Water);
    entity_list.AddNPC(npc);
}
```

### Pattern 3: Companion Construction (companion.cpp)

```cpp
Companion::Companion(const NPCType* d, float x, float y, float z, float heading,
                     uint32 owner_char_id, uint8 companion_type)
    : NPC(d, nullptr, glm::vec4(x, y, z, heading), GravityBehavior::Water, false),
      m_evade_timer(500),
      m_retention_check_timer(RuleI(Companions, MercRetentionCheckS) * 1000),
      m_death_despawn_timer(RuleI(Companions, DeathDespawnS) * 1000),
      m_replacement_spawn_timer(RuleI(Companions, ReplacementSpawnDelayS) * 1000),
      m_ping_timer(5000),
      m_mana_report_timer(15000)
```

### Pattern 4: Equipment Pipeline (companion.cpp)

```cpp
// GiveItem: item_id -> equipment[] + GetInv().PutItem() + CalcBonuses()
bool Companion::GiveItem(uint32 item_id, int16 slot)
{
    m_equipment[slot] = item_id;
    equipment[slot] = item_id;  // sync to NPC::equipment[]
    EQ::ItemInstance* inst = database.CreateItem(item_id);
    if (inst) {
        GetInv().PutItem(slot, *inst);
        // ... wear change, bow/arrow flags ...
        delete inst;
    }
    SaveEquipment();
    CalcBonuses();
    return true;
}
```

### Pattern 5: CLI Command Registration

```
zone_cli.h:  static void TestCompanion(int argc, char **argv, argh::parser &cmd, std::string &description);
zone_cli.cpp: function_map["tests:companion"] = &ZoneCLI::TestCompanion;
CMakeLists.txt: cli/tests/cli_companion_tests.cpp
```

---

## Appendix B: Known Risk Areas

### Risk 1: NPC Type IDs Vary by Database

Tests use `FindNPCTypeIDForClassLevel()` to dynamically discover NPCs.
If the PEQ database lacks NPCs of certain classes at certain levels, some
tests will skip. This is expected and acceptable — the tests degrade
gracefully rather than failing on data they cannot control.

### Risk 2: companion_spell_sets May Be Empty

Spell tests depend on this custom table. If it has no data for a class,
spell loading tests will return false/empty. Tests should detect this and
print `[SKIP]` rather than `[FAIL]`.

### Risk 3: entity_list.AddNPC for Companions

Companions are added to the entity list via `entity_list.AddNPC()` (since
Companion IS-A NPC). This may not trigger all the side effects that
`Companion::Spawn()` does. Tests should note that they are testing the
Companion object in a "constructed but not fully spawned" state. This is
appropriate for unit-style verification but may miss spawn-time
initialization.

### Risk 4: CalcBonuses Side Effects

CalcBonuses touches many systems (item bonuses, spell bonuses, haste,
attack timer, skill bonuses). Calling it in a test environment with no
buffs and minimal equipment should be safe. Adding items may trigger
additional calculations. Watch for null pointer dereferences in bonus
calculation paths that assume a Client owner exists.

### Risk 5: Timer Dependencies

Some companion timers (evade_timer, retention_check_timer) are started
in the constructor. In a test environment without a running process loop,
timer expiration may behave differently. Tests should not rely on timer
timing — only verify timer state (enabled/disabled, duration).
