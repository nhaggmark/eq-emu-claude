# companion-ai-stances — Architecture & Implementation Plan

> **Feature branch:** `feature/companion-ai-stances`
> **PRD:** `game-designer/prd.md`
> **Author:** architect
> **Date:** 2026-03-08
> **Status:** Approved

---

## Executive Summary

The companion stance system (`!passive`, `!balanced`, `!aggressive`) currently stores a stance value via `SetStance()` but the underlying AI processing never reads it to control combat engagement behavior. The C++ `Companion::Process()` method delegates to `NPC::Process()` which calls `Mob::AI_Process()` — both of which use standard NPC aggro logic (faction-based scanning, assist calls, patrol waypoints) that companions should NOT use. This architecture plan modifies `Companion::Process()` to implement stance-aware AI behavior, suppresses inherited NPC aggro behaviors, and adds two new rule values for tuning. The changes are concentrated in a single C++ file (`companion.cpp`) with minor touches to `aggro.cpp` and `ruletypes.h`, plus a small Lua update to companion stance commands.

## Existing System Analysis

### Current State

**The Companion class** (`zone/companion.h:67`, `zone/companion.cpp`) inherits from `NPC` which inherits from `Mob`. The entity hierarchy is:

```
Entity → Mob → NPC → Companion
```

**AI processing chain** (per tick, every ~100ms):

1. `Companion::Process()` (companion.cpp:468) — runs companion-specific timers and assist logic
2. Calls `NPC::Process()` (npc.cpp:572) — runs NPC timers, HP/mana regen, spell processing
3. `NPC::Process()` calls `AI_Process()` at line 799
4. `Mob::AI_Process()` (mob_ai.cpp:966) — the core AI loop:
   - If **engaged**: attack target, run engaged cast checks, pursue
   - If **not engaged**: idle cast checks, NPC-to-NPC aggro scan, movement (pet follow / follow ID / patrol waypoints)

**Key issue — what happens today:**

- `Companion::Process()` at line 499-531 does owner-assist logic: if the owner has a target and the companion isn't passive, it adds the owner's target to its hate list. This is the ONLY place stance is checked.
- After that, it calls `NPC::Process()` which calls `Mob::AI_Process()`, and ALL standard NPC AI runs unchecked:
  - **NPC-to-NPC aggro scan** (mob_ai.cpp:1393-1394): `DoNpcToNpcAggroScan()` runs for NPCs with `GetNPCAggro()`. This scans for hostile NPCs and adds them to the hate list based on faction. Companions would be subject to this if their NPC type has the aggro flag set.
  - **Assist calls** (npc.cpp:775-784): `AIYellForHelp()` runs when engaged, calling nearby same-faction NPCs to assist. Companions would respond to assist calls from other NPCs.
  - **Patrol waypoints** (mob_ai.cpp:1529): `AI_DoMovement()` runs guard position / grid patrol logic for idle NPCs. Companions follow their owner via `GetFollowID()` (set during recruitment), so this particular behavior is already suppressed by the follow logic.
  - **Faction-based aggro on players** (aggro.cpp:371, `CheckWillAggro`): NPCs scan nearby players and aggro based on faction. However, `CheckWillAggro` returns false at line 400 if `GetOwner()` is set. Companions do NOT set `ownerid` (they use `m_owner_char_id` instead), so this check does NOT protect companions from faction-based scanning — but companions are the target of other NPCs' aggro scans, not the initiator, because companions don't call `CheckWillAggro` on their own (they're not wild NPCs).

**Companion stance storage:**

- `m_current_stance` (companion.h:330): `uint8`, default `COMPANION_STANCE_BALANCED` (1)
- `GetStance()` / `SetStance()` (companion.h:255-256): simple getter/setter
- Lua bindings exist (lua_npc.cpp:965-1001, via `lua_companion.cpp`): `SetStance(int)`, `GetStance()`
- Lua command handlers (companion.lua:447-467): `cmd_passive`, `cmd_balanced`, `cmd_aggressive` all call `npc:SetStance(N)` and print acknowledgment
- Database persistence: `companion_data.stance` column exists and is saved/restored

**Companion spell AI:**

- `companion_ai.cpp` already checks stance in every class-specific AI handler
- Passive stance returns `false` from all melee class handlers (Tank, Rogue, Monk, Ranger, Beastlord, Wizard, Magician, Necromancer, Enchanter, Bard)
- Passive healer classes (Cleric, Druid, Shaman) still heal the critically-injured owner even in passive stance
- The spell AI stance checking is functional — the problem is at the AI engagement level, not the spell selection level

**Merc stance system** (zone/merc.cpp):

- `Merc::AI_Process()` (merc.cpp:930) is completely independent from `Mob::AI_Process()` — mercs override `AI_Process` entirely
- `Merc::CheckHateList()` (merc.cpp:2053) actively scans for group members being attacked and adds aggressors to the merc's hate list — this is the "balanced" behavior
- Mercs use `GetOwner()` / `SetOwnerID()` (the base NPC owner system), so `CheckWillAggro` excludes them from NPC aggro scanning

### Gap Analysis

| PRD Requirement | Current State | Gap |
|-----------------|---------------|-----|
| Recruitment is a clean break from NPC AI | Companions inherit all NPC AI via `NPC::Process()` → `Mob::AI_Process()`. NPC aggro flags, assist behavior, and movement patterns persist. | **Major gap.** Need to suppress inherited NPC AI behaviors for companions. |
| Passive stance: no combat, absorb damage silently | `SetStance(0)` stores the value but `Mob::AI_Process()` still engages if hate list is non-empty. Only `Companion::Process()` assist logic checks stance. | **Major gap.** Need passive to clear hate list and prevent engagement. |
| Balanced stance: only fight when group is attacked | Companion assist logic (companion.cpp:499-531) adds owner's target to hate list. But `Mob::AI_Process()` can also add targets via NPC aggro scanning. | **Partial.** Assist logic exists but isn't exclusive — need to suppress other aggro sources. |
| Aggressive stance: actively scan for hostiles | No scan-for-hostiles logic exists. Aggressive stance currently behaves identically to Balanced. | **Major gap.** Need new active scanning logic. |
| Stance changes take effect within one AI tick | `SetStance()` is immediate. But disengagement (clearing hate list, stopping combat) doesn't happen on stance change. | **Gap.** Need on-change actions for passive transition. |
| Stance persists across sessions | `companion_data.stance` column exists and is saved/restored in `Save()`/`Load()`. | **No gap.** Already working. |

## Technical Approach

### Architecture Decision

This feature requires C++ changes. The core AI processing loop in `Mob::AI_Process()` is compiled C++ code that cannot be overridden from Lua or configured via rules. The companion needs to:

1. **Suppress** inherited NPC behaviors (NPC-to-NPC aggro scanning, assist calls)
2. **Override** the engagement decision logic based on stance
3. **Add** aggressive scanning behavior

These are all internal to the C++ AI loop.

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| `zone/companion.cpp` | **C++ — Major** | Override `Process()` to implement stance-aware AI: suppress NPC aggro on passive, add group-assist on balanced, add hostile scanning on aggressive |
| `zone/companion.h` | **C++ — Minor** | Add private helper method declarations |
| `zone/aggro.cpp` | **C++ — Minor** | Add `IsCompanion()` check to `CheckWillAggro()` to prevent NPCs from treating companions as valid aggro scan subjects |
| `common/ruletypes.h` | **Config** | Add 2 new rule values: `AggressiveScanRadius`, `CompanionFleeEnabled` |
| `zone/npc.cpp` | **C++ — Minor** | Add `IsCompanion()` guard in assist call section to prevent companions from yelling for help to nearby NPCs |
| `companion.lua` | **Lua — Minor** | Add hate list clear on passive transition; already mostly correct |

### Data Model

No new tables or columns required. The `companion_data.stance` column already exists and is used for persistence. No SQL changes needed.

### Code Changes

#### C++ Changes

**1. `zone/companion.cpp` — `Companion::Process()` rewrite**

The current `Process()` (line 468-535) will be restructured. Key changes:

```
Companion::Process() {
    // [KEEP] Death despawn timer check (lines 471-483)
    // [KEEP] Mercenary retention check (lines 486-488)
    // [KEEP] Replacement NPC spawn timer (lines 491-495)

    // [NEW] Flee behavior suppression
    if (!RuleB(Companions, CompanionFleeEnabled)) {
        currently_fleeing = false;  // suppress NPC flee behavior
    }

    // [NEW] PASSIVE STANCE: clear hate list, stop all combat
    if (m_current_stance == COMPANION_STANCE_PASSIVE) {
        if (IsEngaged()) {
            WipeHateList();
            SetTarget(nullptr);
            if (IsCasting() && IsOffensiveSpell(casting_spell_id)) {
                InterruptSpell();
            }
        }
        // Skip owner-assist logic entirely
        // Fall through to NPC::Process() for regen, buffs, movement
        return NPC::Process();
    }

    // [MODIFIED] BALANCED STANCE: assist when group is attacked
    Client* owner = GetCompanionOwner();
    if (owner && m_current_stance == COMPANION_STANCE_BALANCED) {
        // Check if any group member is being attacked
        Group* grp = GetGroup();
        if (grp && !IsEngaged()) {
            for (int i = 0; i < MAX_GROUP_MEMBERS; i++) {
                Mob* member = grp->members[i];
                if (!member || member == this) continue;

                // Scan NPCs that have this group member on their hate list
                // Use close mob list for efficiency
                for (auto& close_mob : GetCloseMobList(200.0f)) {
                    Mob* nearby = close_mob.second;
                    if (!nearby || !nearby->IsNPC() || nearby->IsCompanion()) continue;
                    if (nearby->IsOnHatelist(member) && IsAttackAllowed(nearby)) {
                        AddToHateList(nearby, 1);
                        SetTarget(nearby);
                        break;
                    }
                }
                if (IsEngaged()) break;  // found a target, stop scanning
            }
        }
        // Also [KEEP] existing owner-target assist logic (lines 503-531)
    }

    // [NEW] AGGRESSIVE STANCE: scan for hostile targets
    if (owner && m_current_stance == COMPANION_STANCE_AGGRESSIVE) {
        // [KEEP] existing owner-target assist logic

        // Active scanning: find hostile NPCs near the owner
        if (!IsEngaged()) {
            float scan_range = static_cast<float>(RuleI(Companions, AggressiveScanRadius));
            Mob* closest_hostile = nullptr;
            float closest_dist = scan_range * scan_range;

            for (auto& close_mob : GetCloseMobList(scan_range)) {
                NPC* npc = close_mob.second ? close_mob.second->CastToNPC() : nullptr;
                if (!npc || npc->IsCompanion() || !npc->IsNPC()) continue;
                if (!IsAttackAllowed(npc)) continue;

                // "Hostile" = KOS to the player (owner's faction perspective)
                FACTION_VALUE fv = owner->GetReverseFactionCon(npc);
                if (fv != FACTION_SCOWLS && fv != FACTION_THREATENS) continue;

                float dist = DistanceSquaredNoZ(GetPosition(), npc->GetPosition());
                if (dist < closest_dist) {
                    closest_dist = dist;
                    closest_hostile = npc;
                }
            }

            if (closest_hostile) {
                AddToHateList(closest_hostile, 1);
                SetTarget(closest_hostile);
            }
        }
    }

    return NPC::Process();
}
```

**2. `zone/companion.h` — Add helper method**

Add a new method `SuppressNPCAggroBehaviors()` or handle inline. Minimal header changes.

**3. `zone/aggro.cpp` — `Mob::CheckWillAggro()` guard**

At line 400 (after the `GetOwner()` check), add:

```cpp
// Companions don't do faction-based aggro scanning
if (IsCompanion()) {
    return false;
}
```

This prevents companions from being the *initiator* of faction-based aggro. They are NPC subclasses, so without this guard, `DoNpcToNpcAggroScan()` (called from `Mob::AI_Process()` at line 1393-1394) would cause them to aggro based on their original NPC faction.

**4. `zone/npc.cpp` — Suppress assist calls for companions**

At line 775 (the assist timer block), add a companion guard:

```cpp
if (assist_timer.Check() && IsEngaged() && !Charmed() && !HasAssistAggro() &&
    !IsCompanion() &&  // <-- NEW: companions don't call for help
    NPCAssistCap() < RuleI(Combat, NPCAssistCap)) {
```

This prevents companions from yelling for help to nearby same-faction NPCs, which would cause those NPCs to aggro the companion's target — breaking the "clean break" from NPC behavior.

**5. `common/ruletypes.h` — New rule values**

Add to the `Companions` category (after line 1208):

```cpp
RULE_INT(Companions, AggressiveScanRadius, 75, "Distance in game units that Aggressive stance scans for hostile targets")
RULE_BOOL(Companions, CompanionFleeEnabled, true, "Whether companions retain NPC flee behavior after recruitment")
```

#### Lua/Script Changes

**`akk-stack/server/quests/lua_modules/companion.lua` — Stance transition actions**

The `cmd_passive` handler (line 447-449) should also clear the companion's hate list:

```lua
function companion.cmd_passive(npc, client, args)
    npc:SetStance(0)
    -- Wipe hate list to immediately disengage from combat
    npc:WipeHateList()
    npc:Say("I will stand down.")
end
```

Note: `WipeHateList()` is already exposed via the `Lua_Mob` bindings (`lua_mob.cpp`). This provides the immediate Lua-side disengagement. The C++ `Companion::Process()` also handles this, providing a belt-and-suspenders guarantee.

#### Database Changes

No database changes required. The `companion_data.stance` column already exists and is saved/restored during `Companion::Save()` and `Companion::Load()`.

#### Configuration Changes

Two new rules added to `common/ruletypes.h` (see above). Default values:

| Rule | Type | Default | Description |
|------|------|---------|-------------|
| `Companions:AggressiveScanRadius` | INT | 75 | Game units scan range for aggressive stance hostile detection |
| `Companions:CompanionFleeEnabled` | BOOL | true | Whether companions retain NPC flee behavior |

These can be tuned at runtime via `#rules set Companions:AggressiveScanRadius 100` without a server restart.

## Implementation Sequence

| # | Task | Agent | Depends On | Scope |
|---|------|-------|------------|-------|
| 1 | Add `AggressiveScanRadius` and `CompanionFleeEnabled` rules to `common/ruletypes.h` | **config-expert** | — | 2 lines in ruletypes.h |
| 2 | Add `IsCompanion()` guard to `Mob::CheckWillAggro()` in `zone/aggro.cpp` to prevent companions from initiating faction-based aggro | **c-expert** | — | 4 lines |
| 3 | Add `IsCompanion()` guard to assist timer block in `zone/npc.cpp` to prevent companions from calling for help | **c-expert** | — | 1 line |
| 4 | Rewrite `Companion::Process()` in `zone/companion.cpp` to implement stance-aware AI: passive (clear hate list, suppress combat), balanced (group-assist scanning), aggressive (hostile NPC scanning using owner's faction) | **c-expert** | 1, 2, 3 | ~100 lines |
| 5 | Add flee suppression check in `Companion::Process()` using `CompanionFleeEnabled` rule | **c-expert** | 1, 4 | 3 lines |
| 6 | Update `cmd_passive` in `companion.lua` to call `npc:WipeHateList()` on passive transition | **lua-expert** | — | 1 line |
| 7 | Build, restart, and run manual validation of all stance behaviors | **c-expert** | 1-6 | Build + test |

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `GetCloseMobList()` returns stale data for aggressive scanning | Low | Low | `ScanCloseMobs` already runs on timer (npc.cpp:598). Aggressive scanning uses the same cached list, which is refreshed every few seconds. |
| Companion in aggressive stance pulls too many mobs simultaneously | Medium | Medium | Only engages one target at a time (closest hostile). Group adds via hate list happen naturally from combat, not from the scan. Scan radius is tunable via rule. |
| `owner->GetReverseFactionCon(npc)` is expensive in aggressive scan loop | Low | Low | Only runs for NPCs within scan radius (pre-filtered by `GetCloseMobList`), and only when not already engaged. |
| Companion responds to being damaged even in passive stance | Medium | Low | This is by design per the PRD: passive companions absorb damage without retaliating. However, the `Companion::Damage()` override (companion.cpp:372-386) has self-preservation logic that switches aggressive to balanced when HP is low — this does not trigger for passive stance. Verified: the check only runs for `COMPANION_STANCE_AGGRESSIVE`. |

### Compatibility Risks

- **Existing companions:** All existing companions in the database have `stance=1` (Balanced). After this change, Balanced behavior will be more restrictive (no faction-based aggro), which is strictly better than current behavior. No regression risk.
- **NPC `Process()` chain:** We continue calling `NPC::Process()` at the end of `Companion::Process()`, so all NPC timers, regen, spell processing, and movement continue to work. The only suppressed behaviors are explicit (aggro scanning, assist calls).
- **Companion spell AI:** `companion_ai.cpp` already checks stance. No changes needed there.
- **Lua bindings:** `SetStance()`, `GetStance()`, `WipeHateList()` all already exist. No new bindings needed.

### Performance Risks

- **Aggressive scanning:** The scan loop iterates the close mob list (typically 10-50 entries for a zone) once per `Process()` tick (~100ms) but ONLY when the companion is not already engaged and is in aggressive stance. This is equivalent to what every NPC already does via `DoNpcToNpcAggroScan()`. No performance concern.
- **Balanced group-assist scanning:** Iterates group members (max 6) and for each, scans close mobs. This is O(6 * close_mobs) but only runs when not engaged. Similar to `Merc::CheckHateList()` which does the same thing. No performance concern.

## Review Passes

### Pass 1: Feasibility

**Can we build this?** Yes. All required extension points exist:

- `Companion::Process()` is a virtual override that already calls `NPC::Process()` — we just add logic before that call.
- `CheckWillAggro()` is a method on `Mob` that can be guarded with `IsCompanion()`.
- `IsCompanion()` virtual method exists on `Entity` base class and returns true for `Companion` instances.
- `GetCloseMobList()` provides efficient spatial queries for nearby mobs.
- `GetReverseFactionCon()` on `Client` evaluates faction from the player's perspective.
- `WipeHateList()`, `AddToHateList()`, `SetTarget()`, `IsEngaged()` all exist and work correctly.

**Hardest part:** Getting the balanced stance group-assist logic right. It needs to detect when ANY group member is being attacked (not just the owner), which requires scanning nearby NPCs' hate lists. The `Merc::CheckHateList()` code (merc.cpp:2053-2100) provides an exact template for this — it does the same thing for mercenaries.

**Protocol-agent confirmed:** No client-side constraints. All aggro/targeting behavior is server-side. The Titanium client does not need to know about stances.

### Pass 2: Simplicity

**Is this the simplest approach?** Yes.

- Alternative considered: override `AI_Process()` entirely in `Companion` (like `Merc::AI_Process()`). This would give full control but requires reimplementing the entire AI loop (~580 lines of melee combat, spellcasting, movement, fear pathing, etc.). The merc system took this approach and the result is 5,900 lines of code with significant duplication.
- **Chosen approach:** Keep `NPC::Process()` → `Mob::AI_Process()` chain intact, but add stance-based guards BEFORE that call. Suppress unwanted behaviors with targeted guards in `aggro.cpp` and `npc.cpp`. This is 3 small surgical changes vs. a 500+ line rewrite.
- **What can be deferred:** Nothing. All three stance behaviors (passive, balanced, aggressive) are core to the PRD. The flee toggle and scan radius are already simple rule values that add < 5 lines each.

### Pass 3: Antagonistic

**Edge cases and risks:**

1. **Race condition: stance change mid-spell cast.** If the companion is casting a nuke and the player sets passive, what happens? Answer: `Companion::Process()` checks for casting and interrupts offensive spells. The spell system has `InterruptSpell()` which handles mid-cast interruption cleanly.

2. **Companion targets another companion or the owner.** Already handled. `Companion::Attack()` (companion.cpp:388-415) has safety nets that scrub the owner and group members from the hate list. This is belt-and-suspenders protection.

3. **Aggressive companion in a city pulls guards.** Guards are typically not KOS to players (positive faction), so `GetReverseFactionCon()` would not return `FACTION_SCOWLS`. The aggressive scan only targets NPCs hostile to the PLAYER, not to the companion's original NPC faction. This is correct per the PRD.

4. **What if owner logs off while companion is in aggressive stance?** `GetCompanionOwner()` returns nullptr. The aggressive scan requires a valid owner (for faction checks), so it becomes a no-op. The companion stops scanning and follows normal idle behavior. Eventually the companion despawns via the existing disconnect handling.

5. **Companion in passive stance being damaged by DoT.** The companion takes damage without retaliating. The `Companion::Damage()` override has self-preservation logic that could switch stance — verified: it only triggers for `COMPANION_STANCE_AGGRESSIVE`, not passive. Passive companions will absorb damage and potentially die without fighting back, which is the intended behavior.

6. **Multiple companions in aggressive stance in same zone.** Each scans independently. Two aggressive companions could both target the same NPC, which would cause both to attack it. This is fine — it's the expected behavior of aggressive companions.

7. **`currently_fleeing` suppression on stance change.** When `CompanionFleeEnabled` is false, we set `currently_fleeing = false` in `Process()`. This is checked every tick, so even if the NPC flee logic sets it to true in the middle of combat, the next `Process()` tick clears it. This is safe.

### Pass 4: Integration

**Task dependencies:**

```
Task 1 (rules) ──┐
                  ├── Task 4 (Process rewrite) ── Task 5 (flee) ── Task 7 (build/test)
Task 2 (aggro) ──┘
Task 3 (assist) ─┘

Task 6 (Lua) ── independent, can run in parallel
```

- Tasks 1, 2, 3, 6 are independent and can be done in parallel.
- Task 4 depends on Task 1 (needs the rule values) and benefits from 2, 3 being done (so that testing shows correct behavior).
- Task 5 is a small addition to Task 4.
- Task 7 (build/test) is the final validation step.

**Context each expert needs:**

- **c-expert** needs: the PRD, this architecture doc, and access to `companion.cpp`, `companion.h`, `aggro.cpp`, `npc.cpp`, `merc.cpp` (as reference for the CheckHateList pattern).
- **config-expert** needs: just the rule definitions from this doc.
- **lua-expert** needs: just the `cmd_passive` update from this doc plus the companion.lua file.

**Build order:** Rules first (so the code compiles), then C++ changes, then Lua. Lua doesn't require a rebuild.

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| **c-expert** | 2, 3, 4, 5, 7 | Core C++ AI changes: aggro guard, assist guard, Process() rewrite, flee suppression, build/test |
| **config-expert** | 1 | Add 2 new rule values to ruletypes.h |
| **lua-expert** | 6 | Add WipeHateList() call to cmd_passive handler |

## Validation Plan

The game-tester agent should verify:

- [ ] Recruit a Qeynos guard NPC. The guard does NOT auto-aggro nearby dark elves or hostile NPCs after recruitment.
- [ ] Recruit a guard NPC. The guard does NOT patrol its original waypoint route. It follows the player.
- [ ] Set companion to **Passive** (`!passive`). Attack a mob. The companion does NOT engage even when the player is taking damage.
- [ ] Set companion to **Passive** while the companion is in combat. The companion immediately stops attacking and returns to following.
- [ ] Set companion to **Balanced** (default). Walk past hostile NPCs. The companion does NOT initiate combat.
- [ ] In **Balanced** stance, get attacked by a mob. The companion engages the attacker.
- [ ] In **Balanced** stance, have another group member (companion or player) get attacked. The companion assists.
- [ ] Set companion to **Aggressive** (`!aggressive`). Walk near hostile NPCs. The companion actively seeks and engages them.
- [ ] In **Aggressive** stance in a friendly city. The companion does NOT attack friendly NPCs (uses player's faction perspective).
- [ ] Switch from **Passive** to **Balanced** while being attacked. The companion begins fighting back immediately.
- [ ] Switch from **Passive** to **Aggressive** while being attacked. The companion fights back AND starts seeking additional targets.
- [ ] Verify stance persists: dismiss companion, re-recruit. Stance is restored from database.
- [ ] Verify `!status` reports the current stance correctly.
- [ ] Verify stance changes acknowledged: each `!passive`, `!balanced`, `!aggressive` produces a chat response.
- [ ] Verify `#rules set Companions:AggressiveScanRadius 150` changes the scan range at runtime.
- [ ] Verify `#rules set Companions:CompanionFleeEnabled false` prevents companion from fleeing at low HP.

---

> **Next step:** Spawn the implementation team with ONLY the agents listed
> in "Required Implementation Agents" above: **c-expert**, **config-expert**, **lua-expert**.
