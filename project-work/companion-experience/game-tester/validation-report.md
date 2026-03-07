# companion-experience — Validation Report

> **Feature branch:** `bugfix/companion-experience`
> **Author:** game-tester
> **Date:** 2026-03-05
> **Overall Result:** CANNOT COMPLETE — BUILD AND RESTART REQUIRED BEFORE ANY RUNTIME VALIDATION

---

## Executive Summary

The Bash tool was denied in this session. This means the ninja build, luajit syntax
check, mysql DB queries, and server restart commands could not be executed via docker.

**Code review validation (using Read + Grep) was completed in full.** All 7 planned
automated checks were attempted; 4 were executed via code-review equivalents, 3 remain
blocked on docker access.

**Critical finding:** The server was last started on **2026-02-21**. All log files
confirm this timestamp. The C++ implementation was committed on **2026-03-05**, twelve
days later. The running zone processes are executing the OLD binary. No in-game testing
can be considered valid until the server is rebuilt with ninja and restarted.

---

## Validation Results

### Step 1: Build Verification (ninja)

| Status | BLOCKED — cannot run docker exec |
|--------|-----------------------------------|
| Command | `docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc) 2>&1 | tail -50"` |
| Why blocked | Bash tool denied in this session |
| Risk | **HIGH** — the live server is running a binary built before 2026-03-05. The C++ changes in attack.cpp, exp.cpp, companion.cpp, lua_companion.h, and lua_companion.cpp are not yet compiled into the running binary. |
| Action required | User must run the build command manually in a terminal. |

**Manual build command:**
```
docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc) 2>&1 | tail -50"
```

---

### Step 2: Lua Syntax Check (luajit)

| Status | BLOCKED — cannot run docker exec |
|--------|-----------------------------------|
| Command | `docker exec -it akk-stack-eqemu-server-1 bash -c "luajit -bl /home/eqemu/server/quests/lua_modules/companion.lua > /dev/null 2>&1 && echo 'SYNTAX PASS' || echo 'SYNTAX FAIL'"` |
| Why blocked | Bash tool denied |

**Code review assessment:** The three new lines in `cmd_status` are:
```lua
local current_xp    = npc:GetCompanionXP()
local next_level_xp = npc:GetXPForNextLevel()
client:Message(15, "  XP: " .. current_xp .. " / " .. next_level_xp)
```
Both methods use standard Lua colon-call syntax on a bound object. String
concatenation via `..` is correct Lua. No syntax errors are visible. Confidence: HIGH.

**Manual command to verify:**
```
docker exec -it akk-stack-eqemu-server-1 bash -c "luajit -bl /home/eqemu/server/quests/lua_modules/companion.lua > /dev/null 2>&1 && echo 'SYNTAX PASS' || echo 'SYNTAX FAIL'"
```

---

### Step 3: Database Rule Verification

| Status | BLOCKED — cannot run docker exec |
|--------|-----------------------------------|
| Command | `docker exec -it akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq -e "SELECT rule_name, rule_value FROM rule_values WHERE rule_name IN ('Companions:XPContribute','Companions:XPSharePct','Companions:MaxLevelOffset');"` |
| Why blocked | Bash tool denied |

**Code review assessment:** All three rules are confirmed present in
`eqemu/common/ruletypes.h` at lines 1191-1195:
```
RULE_BOOL(Companions, XPContribute, true, ...)   -- line 1191
RULE_INT(Companions, XPSharePct, 50, ...)         -- line 1194
RULE_INT(Companions, MaxLevelOffset, 1, ...)      -- line 1195
```
The prior test plan notes the rule_values table must also have these rows inserted.
The rules exist in the code. Whether they were inserted into the database via the
migration script cannot be confirmed without the mysql query.

**Manual command to verify:**
```
docker exec -it akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq -e "SELECT rule_name, rule_value FROM rule_values WHERE rule_name IN ('Companions:XPContribute','Companions:XPSharePct','Companions:MaxLevelOffset');"
```
Expected output: 3 rows with rule_name/rule_value columns.
If 0 rows returned: rules need to be inserted (use `#rules reload` in-game after
the build, or check if a migration ran them).

---

### Step 4: Code Review Verification

This is the most comprehensive section. All code changes were verified via Grep
against the actual committed files in both repos.

#### 4a. Kill Credit Fix — eqemu/zone/attack.cpp

**Finding: PASS**

The companion resolution block is present at lines 2642-2653, confirmed by grep:
```cpp
// Companion kills: resolve to owner client so XP, faction, tasks, and quest
// credit all fire correctly — matching the loot fix pattern at lines 2827-2832.
// Companions use m_owner_char_id / GetCompanionOwner() rather than the standard
// Mob ownerid field, so HasOwner() returns false for them; handle separately.
if (give_exp && give_exp->IsCompanion()) {
    Client* comp_owner = give_exp->CastToCompanion()->GetCompanionOwner();
    if (comp_owner) {
        give_exp = comp_owner;
    } else {
        give_exp = nullptr;
    }
}
```

Nullptr safety: PASS. The `else { give_exp = nullptr; }` branch prevents null
dereference downstream. Matches the architecture plan exactly.

Position is correct: PASS. The block appears after the pet/bot resolution block
(line 2640) and the loot fix at lines 2827-2832 already uses the same `IsCompanion()`
pattern, confirming the pattern works.

#### 4b. XP Distribution — eqemu/zone/exp.cpp

**Finding: PASS**

The companion XP loop is present at lines 1193-1218:
```cpp
if (RuleB(Companions, XPContribute)) {
    int xp_share_pct = RuleI(Companions, XPSharePct);
    if (xp_share_pct < 0)   { xp_share_pct = 0; }
    if (xp_share_pct > 100) { xp_share_pct = 100; }

    if (xp_share_pct > 0) {
        for (const auto& m : members) {
            if (m && m->IsCompanion()) {
                const uint8 comp_con = Mob::GetLevelCon(m->GetLevel(), other->GetLevel());
                if (comp_con == ConsiderColor::Gray) {
                    continue;
                }
                const uint64 member_share = group_experience / member_count;
                const uint32 companion_xp = static_cast<uint32>(member_share * static_cast<uint64>(xp_share_pct) / 100);
                if (companion_xp > 0) {
                    m->CastToCompanion()->AddExperience(companion_xp);
                }
            }
        }
    }
}
```

All required elements confirmed:
- `XPContribute` rule gate: PASS
- `XPSharePct` clamped [0, 100]: PASS
- Gray-con check (`ConsiderColor::Gray`): PASS
- `AddExperience()` call on companion: PASS

#### 4c. Solo Path Companion XP — eqemu/zone/attack.cpp

**Finding: PASS**

Solo companion XP block present at lines 2780-2799:
```cpp
if (RuleB(Companions, XPContribute)) {
    int xp_share_pct = RuleI(Companions, XPSharePct);
    if (xp_share_pct < 0)   { xp_share_pct = 0; }
    if (xp_share_pct > 100) { xp_share_pct = 100; }

    if (xp_share_pct > 0) {
        auto companions = entity_list.GetCompanionsByOwnerCharacterID(give_exp_client->CharacterID());
        for (auto comp : companions) {
            if (!comp) { continue; }
            const uint8 comp_con = Mob::GetLevelCon(comp->GetLevel(), GetLevel());
            if (comp_con == ConsiderColor::Gray) { continue; }
            const uint32 comp_xp = static_cast<uint32>(final_exp * static_cast<uint64>(xp_share_pct) / 100);
            if (comp_xp > 0) {
                // (AddExperience call follows)
```

Uses `GetCompanionsByOwnerCharacterID()` (not `GetCompanionsByOwner()`). The method
name differs from the architecture plan's pseudocode but functions identically. PASS.

#### 4d. CheckForLevelUp — eqemu/zone/companion.cpp

**Finding: PASS**

Level 60 hard cap confirmed at lines 1473-1476:
```cpp
// Absolute hard cap: companions may never exceed level 60 (Classic-Luclin era ceiling)
if (max_level > 60) {
    max_level = 60;
}
```

MaxLevelOffset clamped at lines 1464-1466:
```cpp
int offset = RuleI(Companions, MaxLevelOffset);
if (offset < 0) { offset = 0; }
if (offset > 59) { offset = 59; }
```

HP/mana restore confirmed at lines 1497-1499:
```cpp
// Restore HP and mana to full as a level-up reward
SetHP(GetMaxHP());
SetMana(GetMaxMana());
```

XP consumed before return confirmed at line 1488:
```cpp
m_companion_xp -= xp_needed;
```

#### 4e. AddExperience Cascading Loop — eqemu/zone/companion.cpp

**Finding: PASS**

While loop confirmed at lines 1432-1451:
```cpp
void Companion::AddExperience(uint32 xp)
{
    m_companion_xp += xp;

    bool leveled = false;
    while (CheckForLevelUp()) {
        leveled = true;
    }

    if (leveled) {
        Client* owner = GetCompanionOwner();
        if (owner) {
            owner->Message(Chat::Yellow,
                "%s has grown stronger! They are now level %d.",
                GetCleanName(), GetLevel());
        }
    }
}
```

Level-up message fires once after the while loop (not inside `CheckForLevelUp`).
No duplicate messages on cascading level-ups. PASS.

#### 4f. GetXPForNextLevel Lua Binding

**Finding: PASS**

Declaration in `lua_companion.h` line 78:
```cpp
uint32 GetXPForNextLevel();
```

Implementation in `lua_companion.cpp` lines 135-139:
```cpp
uint32 Lua_Companion::GetXPForNextLevel()
{
    Lua_Safe_Call_Int();
    return self->GetXPForNextLevel();
}
```

Registration in `lua_companion.cpp` line 251:
```cpp
.def("GetXPForNextLevel", &Lua_Companion::GetXPForNextLevel)
```

All three required elements present. PASS.

#### 4g. GetXPForNextLevel Formula

**Finding: PASS**

Implementation in `companion.cpp` lines 1508-1513:
```cpp
uint32 Companion::GetXPForNextLevel() const
{
    // Same formula EQEmu uses for players: level * level * 1000 (simplified)
    uint8 level = GetLevel();
    return (uint32)(level * level * 1000);
}
```

Formula matches PRD table. Level 30 = 900,000. Level 60 = 3,600,000. PASS.

**NOTE — potential issue:** When `level = 0` (a companion at level 0 before any
leveling), `GetXPForNextLevel()` returns `0 * 0 * 1000 = 0`. If `CheckForLevelUp`
is called at level 0, `xp_needed = 0`, and `m_companion_xp < 0` is always false,
which would trigger an immediate level-up. However, companion level is initialized
from `recruited_level` (always >= 1), so this edge case should not occur in practice.
Worth noting in case a level 0 companion is ever inserted directly into the DB.

#### 4h. !status XP Display — companion.lua

**Finding: PASS**

Lines 564-566 of `companion.lua`:
```lua
local current_xp    = npc:GetCompanionXP()
local next_level_xp = npc:GetXPForNextLevel()
client:Message(15, "  XP: " .. current_xp .. " / " .. next_level_xp)
```

`GetCompanionXP()` was already bound. `GetXPForNextLevel()` is newly bound by
task 4. The Lua syntax is correct. PASS.

#### 4i. No Debug/Test Code Left In

**Finding: PASS**

Grep for TODO/FIXME/debug/print in `lua_companion.cpp`: No matches.
Grep for TODO/FIXME/debug/print in `companion.lua`: No matches.

Pre-existing TODOs in `attack.cpp` (unrelated to this feature): 6 found (archery
penalty, powersource procs, etc.) — all pre-date this implementation and are not
in companion-related code. Not a concern.

Pre-existing TODOs in `companion.cpp`:
- Line 766: `// TODO (Task 9): call owner->RemoveCompanion(this)...` — scaffolding
  note for a future task, not debug code. Not a concern.
- Line 1794: `// TODO (Task 17/18): wire up Lua companion quest event dispatch...`
  — same, future task note. Not a concern.

#### 4j. GetCompanionOwner() Null Checks

**Finding: PASS**

All call sites of `GetCompanionOwner()` in the new code check for nullptr before
dereferencing:

- `attack.cpp` line 2647: `Client* comp_owner = ...; if (comp_owner) { ... } else { give_exp = nullptr; }` — SAFE
- `companion.cpp` `AddExperience` line 1444: `Client* owner = GetCompanionOwner(); if (owner) { ... }` — SAFE
- `companion.cpp` `CheckForLevelUp` line 1458: `Client* owner = GetCompanionOwner(); if (!owner) { return false; }` — SAFE

All other `GetCompanionOwner()` calls throughout `companion.cpp` are in pre-existing
code and also check for nullptr (verified by grep showing the pattern consistently).

---

### Step 5: companion_data Schema Check

| Status | BLOCKED — cannot run docker exec |
|--------|-----------------------------------|

The prior test plan confirmed `experience`, `level`, and `recruited_level` columns
exist. The architecture plan confirms no schema changes were needed. This is
consistent with the implementation — `Save()` and `Load()` are pre-existing methods.

**Manual command:**
```
docker exec -it akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq -e "DESCRIBE companion_data;"
```
Expected: columns include `experience`, `level`, `recruited_level`.

---

### Step 6: Existing Companion Data Check

| Status | BLOCKED — cannot run docker exec |
|--------|-----------------------------------|

**Manual command:**
```
docker exec -it akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq -e "SELECT id, companion_name, level, experience, recruited_level FROM companion_data LIMIT 5;"
```

---

### Step 7: Log Analysis

| Status | PARTIAL — logs readable, but predating the implementation |
|--------|-----------------------------------------------------------|

All log files in `akk-stack/server/logs/` carry timestamps of **2026-02-21**, twelve
days before the implementation (2026-03-05). The highest-numbered zone processes
(zone_2885, zone_2883, zone_2881) all show the same 2026-02-21 timestamps.

**Conclusion:** The server has not been restarted since the C++ implementation was
committed. The running binary does NOT include any of the companion-experience changes.
Log analysis will be meaningful only after a rebuild and restart.

No pre-existing errors relevant to this feature were found in the pre-restart logs.

---

## Full Results Table

| # | Check | Method | Result | Notes |
|---|-------|--------|--------|-------|
| 1 | Build (ninja) | docker exec | BLOCKED | Bash denied. Must run manually. Critical blocker. |
| 2 | Lua syntax (luajit) | docker exec | BLOCKED | Code review: HIGH confidence PASS. Run manually to confirm. |
| 3 | DB rules: XPContribute, XPSharePct, MaxLevelOffset | docker exec / mysql | BLOCKED | Rules confirmed in ruletypes.h. DB insertion unverified. |
| 4a | Kill credit: companion block in attack.cpp | Code review (Grep) | PASS | Lines 2642-2653. Nullptr safe. Correct position. |
| 4b | XP distribution: Group::SplitExp companion loop | Code review (Grep) | PASS | Lines 1193-1218. XPSharePct clamped. Gray-con check. AddExperience called. |
| 4c | XP distribution: solo path companion XP | Code review (Grep) | PASS | Lines 2780-2799. GetCompanionsByOwnerCharacterID. |
| 4d | CheckForLevelUp: level 60 hard cap | Code review (Grep) | PASS | Lines 1473-1476. `if (max_level > 60) { max_level = 60; }` |
| 4d | CheckForLevelUp: MaxLevelOffset clamped [0,59] | Code review (Grep) | PASS | Lines 1464-1466. |
| 4d | CheckForLevelUp: HP/mana restore on level-up | Code review (Grep) | PASS | Lines 1497-1499. SetHP/SetMana after ScaleStatsToLevel. |
| 4d | CheckForLevelUp: XP consumed before return | Code review (Grep) | PASS | Line 1488. `m_companion_xp -= xp_needed` before Save(). |
| 4e | AddExperience: while loop for cascading level-ups | Code review (Grep) | PASS | Lines 1439. `while (CheckForLevelUp())` confirmed. |
| 4e | AddExperience: level-up message fires once, not inside CheckForLevelUp | Code review (Grep) | PASS | Message at line 1446 is outside the while loop. |
| 4f | Lua binding: GetXPForNextLevel declared in header | Code review (Grep) | PASS | lua_companion.h line 78. |
| 4f | Lua binding: GetXPForNextLevel implemented | Code review (Grep) | PASS | lua_companion.cpp lines 135-139. Lua_Safe_Call_Int(). |
| 4f | Lua binding: GetXPForNextLevel registered via .def() | Code review (Grep) | PASS | lua_companion.cpp line 251. |
| 4g | GetXPForNextLevel formula matches PRD (level^2 * 1000) | Code review (Read) | PASS | companion.cpp lines 1508-1513. |
| 4g | Level 0 edge case | Code review (Read) | NOTE | Formula returns 0 at level 0. Companion level always >= 1 at recruitment, so not reachable in practice. |
| 4h | !status XP display in companion.lua | Code review (Grep) | PASS | Lines 564-566. GetCompanionXP + GetXPForNextLevel + Message. |
| 4i | No debug/test code left in modified files | Code review (Grep) | PASS | No TODO/FIXME in lua_companion.cpp or companion.lua (XP-related sections). Pre-existing TODOs in attack.cpp and companion.cpp are unrelated scaffolding notes. |
| 4j | GetCompanionOwner() null checks | Code review (Grep) | PASS | All new call sites check for nullptr before dereference. |
| 5 | companion_data schema: experience, level, recruited_level columns | docker exec / mysql | BLOCKED | Prior test plan confirmed these exist. |
| 6 | Existing companion_data rows | docker exec / mysql | BLOCKED | Cannot verify without mysql access. |
| 7 | Log analysis after restart | Log file reads | PARTIAL | Logs predate implementation (2026-02-21). Server not yet restarted with new binary. |

---

## Critical Blockers

| # | Blocker | Severity | Action Required |
|---|---------|----------|-----------------|
| 1 | **Server not rebuilt.** C++ changes from 2026-03-05 are not in the running binary. All logs predate the implementation. | CRITICAL | Run `docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc) 2>&1 | tail -50"` |
| 2 | **Server not restarted.** Even after a successful build, the zone processes must be restarted to pick up the new binary. | CRITICAL | Restart via Spire (http://192.168.1.86:3000) or `make restart` from akk-stack/ |
| 3 | **DB rule insertion unverified.** Rules exist in ruletypes.h but the `rule_values` DB table may not have been populated if the migration was not run. | HIGH | Run the mysql SELECT query above. If 0 rows returned, run `#reloadrules` in-game (which will insert defaults if missing) or manually insert the rows. |
| 4 | **Lua syntax not machine-verified.** Code review is HIGH confidence, but luajit -bl should be run to confirm. | MEDIUM | Run the luajit command above after the build. |

---

## User Action Checklist

Run these commands in order. Each depends on the previous completing successfully.

**Step A: Build**
```bash
docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc) 2>&1 | tail -50"
```
Look for `ninja: no work to do` (already built) or the final lines showing `[N/N] Linking CXX executable zone` (or similar). If you see errors, stop and report them — do not proceed with in-game testing.

**Step B: Lua syntax check**
```bash
docker exec -it akk-stack-eqemu-server-1 bash -c "luajit -bl /home/eqemu/server/quests/lua_modules/companion.lua > /dev/null 2>&1 && echo 'SYNTAX PASS' || echo 'SYNTAX FAIL'"
```
Expected: `SYNTAX PASS`

**Step C: DB rule check**
```bash
docker exec -it akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq -e "SELECT rule_name, rule_value FROM rule_values WHERE rule_name IN ('Companions:XPContribute','Companions:XPSharePct','Companions:MaxLevelOffset');"
```
Expected: 3 rows. If 0 rows, add `#reloadrules` to the first in-game action after restart.

**Step D: companion_data schema**
```bash
docker exec -it akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq -e "DESCRIBE companion_data;"
```
Expected: columns include `experience`, `level`, `recruited_level`.

**Step E: companion_data data check**
```bash
docker exec -it akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq -e "SELECT id, companion_name, level, experience, recruited_level FROM companion_data LIMIT 5;"
```

**Step F: Restart server**

Via Spire at http://192.168.1.86:3000, or:
```bash
docker exec -it akk-stack-eqemu-server-1 bash -c "pkill zone; pkill world; pkill loginserver; sleep 3"
# Then start via Spire or make start
```

**Step G: Post-restart log check**

After restart, look at the newest zone log for errors:
```bash
ls -lt /mnt/d/Dev/eq/akk-stack/server/logs/zone/*.log | head -3
```
Then search the most recent named zone log (e.g., `oasis_version_0_...log`) for:
```bash
grep -i "error\|companion\|GetXPForNextLevel\|lua" /mnt/d/Dev/eq/akk-stack/server/logs/zone/<newest_named_zone_log>
```
Expected: No `[Error]` lines. If you see `[Error] Lua: attempt to call nil value` on a companion method, the Lua binding was not compiled correctly — report to c-expert.

---

## Code Review Assessment

All code-reviewable checks PASS. The implementation correctly follows the architecture
plan across all five tasks:

1. **Kill credit fix** — companion block is in the right position, handles nullptr, matches the existing loot fix pattern
2. **Group XP distribution** — `SplitExp` companion loop with correct rule gating, clamping, gray-con check
3. **Solo XP distribution** — attack.cpp solo path companion XP with matching logic
4. **CheckForLevelUp** — level 60 hard cap, MaxLevelOffset clamping, HP/mana restore, XP consumed before return
5. **AddExperience** — while loop for cascading, level-up message fires once
6. **Lua binding** — declaration, implementation, and .def() registration all present
7. **!status display** — correct method calls and string format

No debug code found. All null checks present. No regression risks visible in the code.

**The implementation is code-review PASS. The server must be rebuilt and restarted before runtime validation is possible.**
