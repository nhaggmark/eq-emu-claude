# Companion Rez Vanish — Architecture & Implementation Plan

> **Feature branch:** `bugfix/companion-rez-vanish`
> **PRD:** `game-designer/prd.md`
> **Author:** architect
> **Date:** 2026-05-03
> **Status:** Approved (Architecture)

---

## Executive Summary

The autonomous companion-rez system in `Companion::ResurrectFromCorpse()`
creates a brand-new `Companion` C++ object for the rezzed companion and
adds it to `companion_list`, but never depops the original dead `Companion`
entity. Both entities coexist in the zone, sharing the same
`m_companion_id`. The dead OLD entity still has its
`m_death_despawn_timer` running and still has `m_suspended=true` and
(eventually) `m_is_dismissed=true`. When the OLD's despawn timer fires,
when the player zones, when the player camps, or when the player goes
linkdead, the OLD entity calls `Save()` and writes its state
(`is_suspended=1` and/or `is_dismissed=1`) to the same DB row that the
LIVE rezzed companion uses for persistence. The next zone-in (or any
restart) reads `is_suspended=1` and/or `is_dismissed=1` and refuses to
spawn the rezzed companion — the player sees the companion "vanish."

The fix is to make `ResurrectFromCorpse()` find the OLD dead `Companion`
entity in `companion_list` and depop it BEFORE creating and spawning the
NEW rezzed entity. With the OLD entity removed, only the NEW entity
exists for that companion_id, only NEW can call Save(), and the DB row
reliably reflects live state. This is a single-file C++ fix with a
matching test in the existing TDD suite. No Lua, SQL, rules, or protocol
changes are required.

## Existing System Analysis

### Current State

#### Companion entity lifecycle (relevant to this bug)

The Companion class (`eqemu/zone/companion.h`, `companion.cpp`) inherits
from `NPC` and is registered in a custom container, `EntityList::companion_list`
(NOT the standard `npc_list`), with a parallel registration in `mob_list`
for tick processing. `Companion` instances persist their state in the
`companion_data` DB table; the in-memory `m_companion_id` is the primary
key used by `Save()` and `Load()`.

When a Companion dies, the following sequence runs in order:

1. `Companion::Death()` (`companion.cpp:609-741`) — applies the XP death
   penalty, calls `NPC::Death()` (which creates the corpse),
   then explicitly resets `p_depop` to `false` (line 630) so the dead
   Companion entity **stays in the world** rather than being reaped on
   the next tick. The intent is to keep the entity around as a dead
   visible body (with `GetHP() <= 0`) for the rez window.
2. The companion's state is persisted: `m_suspended = true`,
   `times_died++`, `Save()` (line 690).
3. `m_death_despawn_timer.Start()` (line 707) — uses
   `RuleI(Companions, DeathDespawnS)` (default 1800s = 30 min). When
   this timer fires, the companion auto-dismisses.
4. The dead companion is removed from `Group::members[i]` AND its name
   slot in `Group::membername[i]` is freed (lines 716-738) so a future
   rez can `AddMember()` cleanly.

#### Rez handler

`Companion::ResurrectFromCorpse()` (`companion.cpp:3592-3772`) is the
static entry point invoked from `Mob::SpellEffect::Revive` when a rez
spell completes on a companion corpse. It:

1. Reads `companion_id` and `owner_char_id` from the corpse.
2. Loads the `companion_data` row.
3. Loads the `npc_types` row.
4. Marks the corpse `IsRezzed(true)` to prevent concurrent rez races.
5. Creates a NEW `Companion` C++ object via `new Companion(...)`
   (line 3699).
6. `new_comp->SetCompanionID(companion_id)` and
   `SetOwnerCharacterID(owner_char_id)` so Load() resolves the right
   row.
7. `new_comp->Load(companion_id)` restores DB state (stance, equipment,
   XP, scaled stats).
8. `new_comp->Spawn(owner)` registers NEW in `companion_list` and
   `mob_list`, joins the owner's group via `CompanionJoinClientGroup()`,
   strips immunities, and starts AI.
9. After Spawn() succeeds: `comp_data.is_suspended = 0`, restores XP,
   commits to DB via `CompanionDataRepository::UpdateOne()`. Then
   `corpse->DepopNPCCorpse()`.
10. Sets HP to rez%, mana=0, fades buffs, syncs in-memory XP, posts
    group announcement.

**There is no step that depops the OLD dead `Companion` entity** that
gave rise to the corpse. That entity is still in `companion_list`, still
has `m_companion_id == companion_id`, still has `m_owner_char_id ==
owner_char_id`, still ticks in `Process()`, and still has its
`m_death_despawn_timer` running.

#### Companion::Process() tick on the dead OLD entity

`Companion::Process()` (`companion.cpp:1907-2350`) runs every tick for
every entity in `companion_list`. The relevant blocks for a dead entity:

- **BUG-028 safety net** (lines 1909-1929): if `GetHP() <= 0 && !m_suspended
  && m_companion_id > 0`, force a synthetic suspend + DB write. For an
  already-suspended dead companion this is a no-op.
- **Heartbeat / ping timer** (lines 1940-1949): runs unconditionally for
  every alive companion (and was hoisted by 84ac6a204 to also run for
  dead companions so the corpse stays visible to the Titanium client).
  This is good — the dead body stays rendered. BUT: this also means the
  OLD entity keeps emitting position packets on the SAME entity ID it
  was assigned at Death(), which is independent of the NEW rezzed
  entity's ID.
- **Death despawn timer fire** (lines 1962-1988):
  ```cpp
  if (m_death_despawn_timer.Enabled() && m_death_despawn_timer.Check()) {
      ...
      SetDismissed(true);
      SetSuspended(true);
      Save();
      return false;
  }
  ```
  When this fires, **the OLD entity writes `is_dismissed=1, is_suspended=1`
  to the SAME companion_data row that the NEW rezzed entity is using
  for persistence**, then returns false from Process() so the entity is
  reaped. That DB write is the load-bearing corruption.

#### State that crosses between OLD and NEW entities

Both OLD and NEW share the same row in `companion_data`. They have
DIFFERENT entity IDs (Spawn() calls `entity_list.AddCompanion` which
calls `GetFreeID()` so NEW gets a fresh ID), but the same
`m_companion_id`, the same `m_owner_char_id`, the same `cd.name`, etc.

`EntityList::companion_list` is a `std::unordered_map<uint16, Companion*>`
keyed by entity_id. iteration order is non-deterministic (depends on
hash bucket layout). The relevant scan
`EntityList::GetCompanionsByOwnerCharacterID()` (`companion.cpp:4116-4125`)
walks the whole map and returns BOTH OLD and NEW for the same owner.

#### Save() callers that are reachable on either entity

`Companion::Save()` (`companion.cpp:2859-2913`) writes
`is_suspended = m_suspended ? 1 : 0` and
`is_dismissed = m_is_dismissed ? 1 : 0` along with all live state, into
the row keyed by `m_companion_id`. Save() is called from:

- `Death()` (line 690) — already happened on OLD before rez.
- `Process()` death-timer-fire (line 1986) — runs on OLD post-rez.
- `Suspend()` (line 2511) — manual suspend.
- `Zone()` (line 2572) — runs on **every entity in companion_list with
  matching owner_char_id** when the player zones.
- `Dismiss()` (line 2635) — voluntary.
- `CheckMercenaryRetention()` (line 3538) — only for COMPANION_TYPE_MERCENARY.

The two paths that fire post-rez on the OLD entity are:
1. **OLD's death-timer-fire** (Repro A — time-only, no zoning).
2. **Player zones with both OLD and NEW alive in companion_list** (Repro B
   and Repro D — zone path). `Handle_OP_ZoneChange` (`zoning.cpp:48-53`)
   iterates ALL companions for the owner and calls `Zone()` on each,
   which calls `Save()` on each. Whichever Save() runs LAST wins. If
   OLD iterates after NEW, OLD's `m_suspended=true` wins → DB row says
   `is_suspended=1` → next zone's `SpawnCompanionsOnZone` (filters
   `is_dismissed = 0` then skips rows with `is_suspended=1`, see
   `companion.cpp:4225-4229`) → **rezzed companion vanishes on zone-in**.

#### Spawn-on-zone filter

`Client::SpawnCompanionsOnZone()` (`companion.cpp:4205-4287`):

```cpp
auto companion_records = CompanionDataRepository::GetWhere(
    database,
    fmt::format("owner_id = {} AND is_dismissed = 0", char_id)
);
...
for (auto& cd : companion_records) {
    if (cd.is_suspended) {
        continue;
    }
    ...spawn...
}
```

So a row with EITHER `is_dismissed=1` OR `is_suspended=1` is silently
skipped. Both flags are the load-bearing flags that OLD can corrupt.

#### Lua re-recruitment

`companion.lua:check_existing_companion_record` (`lua_modules/companion.lua:405-420`)
finds rows where `(is_dismissed = 1 OR is_suspended = 1)`. This is how
the "you can re-recruit your dismissed companion" flow works. So if the
DB row gets corrupted to `is_dismissed=1`, the player can go re-recruit
the same NPC and the system restores the row — which matches the user's
report ("Player had to re-recruit the Wizard"). This is a survivable
outcome but it loses the flow promise of "kill, rez, keep playing."

### Gap Analysis

What the PRD requires that the current system does not provide:

| Requirement | Current Behavior | Gap |
|---|---|---|
| Rezzed companion remains in group indefinitely | OLD entity persists alongside NEW; OLD's later `Save()` corrupts the shared DB row to `is_suspended=1` and/or `is_dismissed=1` | Rez handler must depop OLD before spawning NEW |
| Rez restores companion identically to never-died | Identity (`m_companion_id`, `name`, equipment, XP) is correctly carried via Load(); NEW's runtime is correct in isolation | NONE for the live-zone behavior — gap is purely the persistence-corruption window |
| 30-min time persistence (AC-1) | OLD's `m_death_despawn_timer` fires at T_death + 1800s and writes is_dismissed=1, is_suspended=1 to DB | Depopping OLD on rez removes this timer entirely |
| Zone persistence ≥ 3 zones (AC-2) | At zone, BOTH OLD and NEW save; non-deterministic order — OLD's `m_suspended=true` may win and skip spawn in next zone | Depopping OLD on rez means only NEW saves → DB always reflects live state |
| Sustained-play resilience (AC-5) | Each rez creates a new OLD-leak; further rez attempts on the same companion compound | Same fix |
| AC-6 logging | No log line confirms despawn-timer-cleared on rez | Add a log line at the point we depop OLD |

## Technical Approach

### Architecture Decision

Least-invasive-first analysis:

| Layer | Could it own this? | Verdict |
|---|---|---|
| Rule values | A rule like `RezDepopOldEntity` could gate the new behavior | NO — this is correctness, not tunable behavior. Always-on. No rule needed. |
| Server config | N/A — config can't add a depop call | N/A |
| Lua | The rez chain is fully in C++. There is no Lua hook between corpse-target and `ResurrectFromCorpse`. | N/A |
| SQL | Could a periodic DB cleanup job catch corrupted rows? | NO — that hides the bug, doesn't fix it, and won't repair the player's in-zone session. |
| **C++** | The bug is in `Companion::ResurrectFromCorpse()` and the OLD-entity-Process loop. Fix here. | **YES — this is a C++-only fix** |

| Component | Change Type | Justification |
|---|---|---|
| `Companion::ResurrectFromCorpse()` | Modify | Add OLD-entity lookup + depop before NEW Spawn(). Single load-bearing change. |
| `cli_companion_tests.cpp` | Add tests | TDD: add failing tests in Suite 38 (new) for time-only and zone-only repros. |
| Companion lua module | No change | Lua re-recruitment path is correct; bug is upstream in C++. |
| `companion_data` schema | No change | Schema is fine; the column write is the bug. |
| `ruletypes.h` | No change | Always-on correctness fix. |

### Data Model

No DB schema changes. The fix is entirely runtime entity management.

After the fix, the `companion_data` row continues to be the single source
of truth, written by exactly one entity at a time per companion_id.

### Code Changes

#### C++ Changes (eqemu/)

##### Primary fix: `Companion::ResurrectFromCorpse()` (eqemu/zone/companion.cpp)

Before line 3699 (`auto* new_comp = new Companion(...)`), add a block
that finds and depops the OLD dead Companion entity for this
`companion_id`:

```cpp
// FIX (BUG-001 rez-vanish): find and depop the OLD dead Companion entity
// for this companion_id before creating the NEW rezzed entity. The OLD
// entity has m_death_despawn_timer running and m_suspended=true; if it
// remains in companion_list it will eventually fire its despawn timer
// (writes is_dismissed=1, is_suspended=1 to companion_data) and/or be
// iterated by Handle_OP_ZoneChange (writes is_suspended=1 to
// companion_data). Either path corrupts the SHARED companion_data row
// keyed by companion_id and silently vanishes the rezzed companion on
// the next zone-in or restart.
//
// We scan companion_list once to locate the OLD entity by companion_id,
// then call Depop() to remove it from companion_list and stop its
// Process() tick. Save() is intentionally NOT called on OLD — the rez
// path will commit the correct live state to DB after Spawn() succeeds.
// We also guard against the unlikely case where the OLD entity has the
// same Lua hooks queued; Depop() already handles WipeHateList,
// InterruptSpell, group removal, and entity-list removal.
{
    Companion* old_dead = nullptr;
    for (auto& [id, comp] : entity_list.GetCompanionList()) {
        if (comp && comp != nullptr
            && comp->GetCompanionID() == companion_id
            && comp->GetOwnerCharacterID() == owner_char_id) {
            old_dead = comp;
            break;
        }
    }
    if (old_dead) {
        LogInfo("Companion::ResurrectFromCorpse: depopping OLD dead entity "
                "(entity_id={}, companion_id={}) before spawning rezzed entity",
                old_dead->GetID(), companion_id);
        // Disable death-despawn timer FIRST so the Process() tick that
        // could happen between here and entity reaper cannot fire the
        // dismiss path.
        // Cleanest invariant: OLD's m_death_despawn_timer is the only
        // timer whose fire path writes is_dismissed=1; killing it before
        // Depop() ensures even a tick race cannot poison the row.
        // We achieve this by clearing m_suspended/m_is_dismissed on OLD
        // so any incidental Save() on OLD (defensive) is a no-op write
        // of the live-alive state. But the cleaner pattern is: just
        // call Depop() — it removes OLD from companion_list and from
        // mob_list, so Process() will not be called on OLD again.
        old_dead->Depop(false);
    }
}
```

The exact placement: insert this block **after** the corpse position
(`corpse_pos`) is captured at line 3662 and **before** `new_comp` is
allocated at line 3699. This ordering is critical — we must capture
`corpse_pos` from the live corpse before any cleanup, but we must depop
OLD before NEW spawns so there is no window where both exist.

##### Test scaffolding addition: `eqemu/zone/cli/tests/cli_companion_tests.cpp`

Add a new Suite 38 (BUG-001 rez-vanish) with at least 3 failing-first
TDD tests:

- **Test 38.1 — OLD entity depopped on rez success.** Set up a Companion,
  Death() it, ResurrectFromCorpse() on the corpse. Assert the OLD
  entity is removed from `companion_list` immediately after rez.
  Pre-fix: FAIL (OLD remains). Post-fix: PASS.
- **Test 38.2 — OLD's death-timer cannot fire after rez.** Set up a
  Companion, Death() it, capture `m_death_despawn_timer` enabled state,
  ResurrectFromCorpse(), then advance the rules clock by
  `DeathDespawnS + 1` seconds (or trigger via `TriggerDeathDespawnTimer`
  test hook on OLD if a reference still exists). Assert the
  companion_data row in DB has `is_dismissed=0` AND `is_suspended=0`
  after the would-be timer fire window. Pre-fix: FAIL (DB shows
  is_dismissed=1). Post-fix: PASS (OLD was depopped so timer never
  fires).
- **Test 38.3 — Concurrent Save() race resolved.** Set up a Companion,
  Death() it, ResurrectFromCorpse(). Iterate `companion_list` for the
  owner and call `Save()` on every entry. Assert the resulting DB row
  has `is_suspended=0` AND `is_dismissed=0`. Pre-fix: FAIL (race
  outcome non-deterministic; in test environment with single-companion
  iteration order OLD may go second). Post-fix: PASS (only NEW exists
  in companion_list).

These tests should be added BEFORE the fix and prove they FAIL on
master, then PASS on the fix branch — this is the standard TDD discipline
the prior companion-rez/rerecruit fixes followed (Suites 35-37).

##### Optional defensive belt: clear OLD's flags before Depop

To be belt-and-suspenders against any corner case where Depop() is later
refactored, the engineer can also clear OLD's identity tie before depop
so even a mis-routed Save() is harmless:

```cpp
old_dead->SetCompanionID(0);   // sever DB tie — Save() becomes a fresh-insert no-op (early-returns when m_owner_char_id != 0 and m_companion_id == 0 falls into INSERT branch, which is undesirable; alternative: SetSuspended(false); SetDismissed(false); — flags now match the alive state)
```

Actually — `Save()` on OLD with `m_companion_id==0` would take the
INSERT branch and create a phantom DB row. **DO NOT do this.** The
correct defensive reset is:

```cpp
old_dead->SetSuspended(false);   // cosmetic; Depop() makes it irrelevant
old_dead->SetDismissed(false);   // cosmetic; Depop() makes it irrelevant
```

But these are belt-and-suspenders only. The Depop() call is the
load-bearing change. The engineer can add or omit the cosmetic resets
at their discretion.

#### Lua/Script Changes (akk-stack/)

None.

#### Database Changes

None.

#### Configuration Changes

None.

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | Add Suite 38 failing-first TDD tests (38.1, 38.2, 38.3) for the rez-vanish bug | c-expert | -- | Small (~3 tests, ~150 lines) |
| 2 | Add OLD-entity depop block to `Companion::ResurrectFromCorpse()` | c-expert | 1 | Small (~25 lines + comment) |
| 3 | Verify Suite 38 GREEN, all prior suites (Suite 36 V2 rez, Suite 37 heartbeat, Suite 35 rerecruit) still GREEN | c-expert | 2 | Small (build + test run) |
| 4 | Build the binary in the dev container and confirm clean compile | c-expert | 2 | Trivial |
| 5 | Validate via game-tester against Repro A, B, C, D from the PRD | game-tester | 4 | Medium (4 sustained-play repros, log capture) |

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Depop() on OLD has side effects we haven't enumerated (group state, follow target on owner, AI cleanup) | Medium | Medium | OLD is already dead and excluded from group via `Death()` (lines 716-738). Depop() runs `WipeHateList`, `InterruptSpell`, `RemoveFromHateLists`, and (no-op-if-no-group) `RemoveCompanionFromGroup` — none of which can affect NEW because NEW does not exist yet at this point. Verified by reading Depop() at companion.cpp:2583-2615. |
| Iteration during depop invalidates the iterator | Low | High | We capture `old_dead` as a pointer in a single scan, break on first match, then call `Depop()` outside the loop. Depop() calls `RemoveCompanion(GetID())` which erases by entity_id — safe because we are no longer iterating. |
| Multiple OLD entities (somehow) for same companion_id | Very Low | Low | The scan iterates the full map and would only find the first via `break`. Pathological case where two OLDs exist would require a prior bug; if that ever surfaces we can convert the scan to a vector + drain loop. Not worth coding for now. |
| OLD entity's pet has been preserved and depops on rez | Low | Low | `Companion::Depop()` calls `GetPet()->Depop()` which depops any pet. NEW will recreate its pet on next AI tick if applicable. Acceptable behavior. |
| Depop() triggers `ReassignFormationSlots` which might race with NEW's formation assignment | Low | Low | NEW is assigned a slot when CompanionJoinClientGroup runs in Spawn(). NEW does not exist yet when OLD's Depop() reassigns slots (which excludes OLD). When NEW spawns, it joins and reassigns again — final state is correct. |
| Heartbeat block on OLD ran one more tick before depop and emitted a position packet | Negligible | Cosmetic | The packet uses OLD's entity_id. NEW has a different entity_id and is rendered separately. The OLD's last position packet is stale but the OLD is being depopped → the entity reaper sends OP_DeleteSpawn for OLD. |

### Compatibility Risks

- **Adjacent fix preservation.** All five prior companion-rez/rerecruit
  fixes operate on different code paths and remain unaffected:
  - 84ac6a204 (heartbeat hoist) — modifies heartbeat ordering in
    Process(); we do not touch Process().
  - 17662d4ba (rez V2 — group slot, alive guard, Spawn routing,
    atomicity) — modified Death() and ResurrectFromCorpse() in the
    spawn/group-join chain. Our fix adds a step BEFORE the existing
    rez V2 chain; the rez V2 chain itself is untouched.
  - 478d154bf (rerecruit V2 — name-based lookup) — modified
    `CreateFromNPC()` query. We do not touch `CreateFromNPC()`.
  - 035d33348 (Fix V Option A + Fix W α) — modified Process() heartbeat
    + dead-state handling. Our fix doesn't change Process().
  - cb95baa41 (original rez feature) — entire feature; we extend it,
    don't replace.
- **Test suite stability.** Suites 35, 36, 37 must remain GREEN. The fix
  adds Suite 38 and does not modify earlier suites.

### Performance Risks

- **One extra map walk per rez** — `companion_list.size()` per zone is
  O(N companions per owner per zone) = O(1-6) in practice. Negligible.
- **One extra Depop() call per rez** — same path runs on dismiss /
  voluntary depop today. No new heavy work.
- **No new DB writes** — fix actually *prevents* a spurious DB write
  (the OLD's death-timer-fire UPDATE).

### Antagonistic / Adjacent System Enumeration

Per the architect-discipline section in the architect agent definition,
the customized-system consumers that touch the OLD entity post-Death()
and post-rez are:

1. **Visibility / position-update heartbeat** (Process line 1940-1949)
   — OLD's ping_timer keeps the dead body rendered for the rez window.
   After our fix, OLD is gone immediately on rez. The dead body is no
   longer rendered AFTER rez — but that is correct because the corpse
   is also depopped (line 3737 in current code) AND a NEW live entity
   is spawned at the same coordinates. The player sees: dead body →
   live rezzed companion. Same observable result as today, just
   without the lingering hidden OLD entity.
2. **Group-bonus calculation, group XP share, group-buff propagation**
   — OLD was already removed from `Group::members[]` at Death() time
   (companion.cpp:716-738). Group-side iteration cannot see OLD.
   Unaffected.
3. **AoE friend/foe filter** — OLD's `IsCompanion()` returns true and
   would be skipped by `IsFriendlyTarget`. After our fix, OLD is gone,
   so it can't be a target at all. Strictly better.
4. **Pet/charm exclusion** (`AreYouMyPet`, `IsPetOwner`, `GetOwner`) —
   OLD's pet was already depopped at Death() (NPC::Death). After fix,
   OLD entity itself is depopped. No pet ownership cycles can exist.
5. **Spell target validation** (`ST_Corpse`, `ST_Pet`) — OLD entity is
   not the corpse object (corpse is a separate `Corpse*` registered in
   `corpse_list`). OLD was the dead Mob entity. After fix it's gone
   from mob_list and from companion_list. Spells targeting it would
   fail because it can't be selected.
6. **Faction / aggro inheritance from owner** — OLD has no aggro
   (Death() emptied it via NPC::Death). N/A.
7. **Save / load / zone-in reentry** — THIS is the heart of the bug.
   After fix, OLD cannot Save() because OLD doesn't exist. Resolved.
8. **`GetCompanionByOwnerCharacterID()` returns the wrong entity** —
   pre-fix, with iteration order non-deterministic, callers could get
   OLD instead of NEW. After fix, only NEW is in companion_list.
   Strictly correct.
9. **`GetCompanionsByOwnerCharacterID()`** — same as above. Resolved.
10. **`ReassignFormationSlots()`** — OLD's Depop() triggers a reassign
    excluding OLD. NEW's Spawn() triggers another reassign including
    NEW. Final state correct.
11. **`Handle_OP_ZoneChange` companion iteration** (zoning.cpp:48-53) —
    only NEW remains, only NEW saves. Resolved.
12. **`OnDisconnect`/`Camp` companion iteration** (client_process.cpp:214,
    715) — same as zone path. Resolved.

All 12 enumerated consumers are either unaffected, or strictly improved
by the fix.

## Review Passes

### Pass 1: Feasibility

The fix is a 25-line addition in a single function in a single file.
The lookup pattern (`for (auto& [id, comp] : companion_list)`) already
exists in the same translation unit (`GetCompanionsByOwnerCharacterID`,
`GetCompanionByOwnerCharacterID`). Depop() exists and is called from
multiple paths today (Suspend, Zone, Dismiss, replacement-spawn-timer).
There is no new API surface, no new struct, no new method. **Highly
feasible.**

protocol-agent consultation result (advisory pre-write per the
architect's planning team protocol): no client packet changes are
required. The Titanium client sees:
- A `OP_Death` for OLD's entity_id (already emitted at Death time).
- A position-update for OLD until depop, then `OP_DeleteSpawn` for
  OLD (already emitted at the death-timer-fire today; with our fix it
  emits earlier — at rez time instead). This is benign.
- A `OP_NewSpawn` for NEW's entity_id (emitted by Spawn()).
- A `OP_GroupUpdate` (groupActJoin) for NEW (emitted by AddMember()).
The client model already handles all of this; we are not adding new
opcodes or modifying packet structs.

config-expert consultation result (advisory pre-write): no rule
changes. `RuleI(Companions, DeathDespawnS)` is still consulted by OLD's
constructor at the time Death() runs, but our fix makes the timer
moot for the rezzed-and-restored-companion path. The rule continues to
gate the auto-dismiss path for un-rezzed companions, which is correct
and unchanged.

### Pass 2: Simplicity

Could anything be removed or deferred?

- **Could we skip the depop and instead clear OLD's `m_death_despawn_timer`
  and `m_suspended`?** Tempting but wrong. Even if we disable the timer,
  OLD's Process() still ticks — heartbeats, position updates, and (more
  importantly) `Save()` calls from `Zone()`, `OnDisconnect`, `Camp`. The
  shared `m_companion_id` means OLD's Save() corrupts the DB row no
  matter how many flags we clear. The only sound fix is removing OLD
  from companion_list entirely. Depop is the simplest way to do that.
- **Could we use Save() on OLD with `m_suspended=false, m_is_dismissed=false`
  before Depop?** Unnecessary — NEW's Save() at zone-time already
  writes the correct state, and we depop OLD before any Save() chance.
  Adding a Save() on OLD here is one more DB roundtrip with no benefit.
- **Could we only fix the time-only path (death-timer disable) and accept
  the zone-only path being broken?** No — PRD AC-2 and AC-7 both
  require zone persistence, and the zone-only path is the
  Save()-race path that survives even if we fix the time-only path.
  Both paths share a root cause and a single fix.
- **Could we skip the test scaffolding for speed?** Strongly no — the
  prior rez/rerecruit fixes that lacked tests are exactly the ones that
  required follow-up V2 / V3 fixes. The TDD discipline in
  `feedback_refactor_regression_discipline.md` is mandatory for this
  feature surface.

### Pass 3: Antagonistic

Steel-man case against this fix:

1. **What if the player rez's a companion, the rez succeeds, then the
   player's session crashes BEFORE NEW Save()s? Does the dead OLD's
   pre-rez Save() (which set is_suspended=1) leave the row in a worse
   state than before?**
   - Pre-fix: pre-rez OLD set is_suspended=1, then NEW set
     is_suspended=0 in ResurrectFromCorpse() at line 3735. So if NEW
     spawns successfully, DB is is_suspended=0. If NEW fails, OLD's
     is_suspended=1 remains and corpse is preserved (Fix C atomicity
     from V2). Fine.
   - Post-fix: SAME — OLD's pre-rez Save() ran in Death() before our
     fix runs. Our fix adds the OLD depop AFTER that pre-rez state is
     already in DB. Then ResurrectFromCorpse() Updates is_suspended=0
     after NEW spawns. The crash window is unchanged from the V2
     atomicity contract. **No regression on V2 atomicity.**
2. **What if there are MULTIPLE rez attempts on the same corpse from
   two Cleric companions?**
   - Pre-fix: `corpse->IsRezzed(true)` is set early as a race guard
     (line 3632). The second rez would skip because IsRezzed is true.
   - Post-fix: SAME race guard. Our depop runs AFTER the IsRezzed guard
     so it can never run twice for the same corpse. **No new race.**
3. **What if the player has dispelled the rez before Spawn()
   completes?** The current rez path can't be canceled mid-flight.
   Our fix doesn't change that. **N/A.**
4. **What if the OLD entity is being processed in another iteration
   loop when Depop runs?** Depop is a synchronous in-zone call from
   `ResurrectFromCorpse`, which is called from `SpellEffect::Revive`,
   which is called from the spell-tick processing in the main zone
   thread. Zone is single-threaded. There is no other iteration in
   flight. **No race.**
5. **What if OLD has equipment items rendered via `m_equipment` that
   should be returned to the player?** Death() already handles
   equipment-on-death per the EquipmentPersistsThroughDeath rule
   (lines 632-649). Our fix runs after Death() has already settled the
   equipment policy. **N/A.**
6. **What if the DB row was somehow already deleted between Death() and
   rez (e.g., admin SoulWipe)?** ResurrectFromCorpse line 3608 already
   guards: `if (comp_data.id == 0) { return; }`. Our depop block runs
   only after that guard passes, so a stale corpse with no DB row is
   already rejected before our code runs. **Correct gate ordering.**
7. **Could the corpse-rezzed flag race with corpse decay?** No — corpse
   decay is independent of OLD entity decay. The corpse object is
   `Corpse*` in `corpse_list`. ResurrectFromCorpse depops the corpse
   AFTER NEW Spawn() succeeds. Our fix only touches OLD entity, not
   the corpse. **Independent systems.**

### Pass 4: Integration

Sequence the implementation team needs to follow:

1. **c-expert: Suite 38 (TDD red).** Add 3 failing tests against
   master (or against the fix branch BEFORE the fix). Verify each
   FAILS for the documented reason.
2. **c-expert: implement the fix.** Add the OLD-entity depop block to
   `ResurrectFromCorpse()`.
3. **c-expert: verify all suites GREEN.** Suite 38 must pass; Suites
   35, 36, 37, and all earlier (1-34) must remain unchanged.
4. **c-expert: build in container.** `docker exec
   akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`.
5. **c-expert: commit and push** to `bugfix/companion-rez-vanish` in
   eqemu/ — one commit for the test suite, one for the fix (TDD
   discipline).
6. **infra-expert (if needed): restart server processes** so the new
   binary takes effect. Standard restart: shared_memory, loginserver,
   world, zones (per MEMORY).
7. **game-tester: run all four repros (A, B, C, D)** from the PRD.
   Capture zone server logs and confirm AC-1 through AC-7 pass. The
   Suite 38 tests cover the unit invariants; the repros cover the
   end-to-end player-facing behavior.

No Lua deploy is required. No SQL migration is required. No
configuration is required.

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|---|---|---|
| **c-expert** | Tasks 1-5 (Suite 38 TDD red, implement fix, verify all suites GREEN, build, commit/push to `bugfix/companion-rez-vanish` in `eqemu/`) | The fix is a single-function addition in `eqemu/zone/companion.cpp` plus 3 new TDD tests in `eqemu/zone/cli/tests/cli_companion_tests.cpp`. No other language is involved. |
| **infra-expert** (only if server restart is needed during validation) | Restart server processes after the new binary is built so game-tester can run live repros | Standard post-build restart. May not be needed if game-tester self-services per the runbook. |
| **game-tester** | Validation of all four repros (A, B, C, D) and AC-1 through AC-7 | Final verification phase. |

NOT spawned for this fix:
- lua-expert — no Lua change
- data-expert — no SQL change
- config-expert — no rule change (already consulted in Pass 1; advisory only)
- protocol-agent — no packet change (already consulted in Pass 1; advisory only)
- perl-expert — no Perl change

## Validation Plan

The PRD's seven acceptance criteria map to game-tester scenarios as
follows. game-tester must run ALL of these and confirm each passes
before sign-off:

- [ ] **AC-1: Time persistence (Repro A — time-only).** 30 minutes
  continuous play in same zone after rez. Wizard companion still in
  group window, still responds to `/stats`, `/help`, `/assist`,
  `/hold` at the 30-minute mark. Capture zone log.
- [ ] **AC-2: Zone persistence (Repro B — zone-only).** 3 zone
  transitions immediately after rez. Wizard companion present and
  responsive in each destination zone. Capture zone log + group window
  snapshot.
- [ ] **AC-3: Command parity.** Run all rez'd-companion commands
  (`/assist`, `/hold`, `/follow`, `/tome`, `/stats`, `/help`) and
  compare each response 1:1 with a never-died companion in the same
  zone. No silent no-ops, no error messages, no failures.
- [ ] **AC-4: No regression on prior fixes.**
  - Heartbeat fires above all early-returns. Verify by checking that
    a passive-stance dead companion still emits its 5-second
    keep-alive. (Suite 37 V.3 covers the unit; game-tester just needs
    to not see culling.)
  - Re-recruit invariant V2: dismiss the rezzed Wizard, then re-recruit
    the same Wizard NPC. State (level, XP, equipment) restores from
    the same companion_data row.
  - Companion-rez V2 invariants: rez succeeds with correct group slot,
    alive guard, Spawn routing, and atomicity. (Suite 36 covers
    units.)
- [ ] **AC-5: Sustained-play resilience (Repro C).** 30-minute combat
  session: death → rez → death → rez → continue. Wizard still in
  group at end of session.
- [ ] **AC-6: Logging.** Verify the new log line
  `Companion::ResurrectFromCorpse: depopping OLD dead entity ...`
  appears in zone log on every rez success. This is the positive
  signal that the fix path executed.
- [ ] **AC-7: All four repros pass independently (A + B + C + D).** Each
  repro is run in isolation (fresh login, fresh recruit, fresh rez)
  and the rezzed companion never vanishes. game-tester records the
  exact `T_REZ + N` for each repro and confirms NO vanish event in any.

### Suite 38 — Unit-test scenarios (c-expert deliverable)

- **38.1**: After ResurrectFromCorpse, the dead OLD Companion entity
  is no longer in `companion_list`.
- **38.2**: After ResurrectFromCorpse, no Save() call on any entity for
  the rezzed companion_id can write `is_dismissed=1` or
  `is_suspended=1` to the row (because OLD is gone and NEW has
  m_suspended=false, m_is_dismissed=false).
- **38.3**: Iterating `companion_list` for the owner after rez and
  calling `Save()` on every entry produces the expected DB state
  (is_suspended=0, is_dismissed=0).

---

> **Next step:** Spawn the implementation team with `c-expert` as the
> primary agent (and `infra-expert` for restart support if the
> game-tester does not self-service the server lifecycle). Do not spawn
> lua-expert, data-expert, perl-expert, config-expert, or protocol-agent
> — they have no tasks.
