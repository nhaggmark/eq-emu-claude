# Companion Rez — Dev Notes: c-expert

> **Feature branch:** `bugfix/companion-rez`
> **Agent:** c-expert
> **Task(s):** Triage C++ rez code path (architecture phase)
> **Date started:** 2026-04-27
> **Current stage:** v2 Investigation (Production debug findings — three deeper bugs)

---

## Task Assignment

Architecture phase triage: trace the rez code path, identify root cause, surface risks, map TDD test attachment points.

---

## Stage 1: Triage Findings

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `zone/spells.cpp` | 2049–2063 | **ROOT CAUSE** — `ST_Corpse` target type check requires `IsPlayerCorpse()` |
| `zone/spell_effects.cpp` | 1707–1729 | `SpellEffect::Revive` handler correctly branches on `IsCompanionCorpse()` → calls `Companion::ResurrectFromCorpse()` |
| `zone/companion.cpp` | 3547–3700 | `Companion::ResurrectFromCorpse()` — full rez implementation exists and is complete |
| `zone/companion_ai.cpp` | 1849–2011 | `AI_ResurrectDeadGroupMember()` + `FindDeadGroupMemberCorpse()` — complete rez AI pipeline exists |
| `zone/companion.cpp` | 1939–1953 | Post-combat delay timer logic in `Companion::Process()` |
| `zone/corpse.h` | 102–110 | `IsPlayerCorpse()`, `IsNPCCorpse()`, `IsCompanionCorpse()` semantics |
| `zone/corpse.cpp` | 2305–2374 | `Corpse::CastRezz()` — sends rez request to world for player confirmation |
| `zone/corpse.cpp` | 178–181 | `Corpse::SetCompanionData()` — sets companion metadata on NPC corpse |
| `zone/attack.cpp` | 2905–2912 | `SetCompanionData()` called on companion death — companion metadata IS set correctly |
| `zone/worldserver.cpp` | 909–960 | `ServerOP_RezzPlayer` handler — routes rez request to the player's zone |
| `zone/client_process.cpp` | 1053–1145 | `Client::OPRezzAnswer()` — player rez acceptance logic |
| `zone/entity.cpp` | 2052–2069 | `GetCompanionCorpseByOwnerWithinRange()` — companion corpse search (used by FindDeadGroupMemberCorpse) |
| `common/ruletypes.h` | 1250–1254 | Rez rules: `RezEnabled`, `RezPostCombatDelayS`, `RezRange`, `RezWaiveReagents` |
| `zone/cli/tests/cli_companion_tests.cpp` | 6494–6765 | Suite 29: existing rez tests — rules, XP penalty, corpse metadata, AI gates |

---

### ROOT CAUSE (CONFIRMED)

**`zone/spells.cpp:2051` — `ST_Corpse` target type validation rejects companion corpses.**

```cpp
case ST_Corpse:
{
    if(!spell_target || !spell_target->IsPlayerCorpse())
    {
        // Returns CORPSE_NOT_VALID — rez spell canceled before SpellEffect::Revive fires
```

All Cleric rez spells use target type `ST_Corpse`. The server's `SpellFinished()` validates the target BEFORE applying spell effects. For NPC companion corpses:
- `IsPlayerCorpse()` returns `false` → check fails
- Spell is canceled with `CORPSE_NOT_VALID` message
- `SpellEffect::Revive` handler at `spell_effects.cpp:1720` that correctly routes to `Companion::ResurrectFromCorpse()` is **never reached**

This explains the user's observation: "I can see that he's attempting to rez but nothing happens." The cast animation fires (the companion starts casting), but `SpellFinished()` kills it on target validation.

### Key Architecture Finding: Infrastructure is Already Built

The full companion rez infrastructure was implemented in `companion-rerecruit`:

1. **`Companion::ResurrectFromCorpse(corpse, spell_id, caster)`** (`companion.cpp:3547`) — complete: DB update, corpse depop, new entity spawn, XP restore, HP/mana at rez%, group rejoin, group announce.

2. **`AI_ResurrectDeadGroupMember()`** (`companion_ai.cpp:1927`) — complete: rule check, post-combat delay timer, multi-healer coordination, tier-preference spell selection (healthy mana = best rez, low mana = cheapest rez), mana check + sit-to-meditate, `AIDoSpellCast()`.

3. **`FindDeadGroupMemberCorpse()`** (`companion_ai.cpp:1861`) — finds companion corpses within `RezRange` by owner char_id. **Does NOT find player corpses** (player rez is a separate concern).

4. **Post-combat delay timer** (`companion.cpp:1939–1953`) — fires `RuleI(Companions, RezPostCombatDelayS)` seconds after engaged→idle transition.

5. **`Corpse::SetCompanionData()`** called in `attack.cpp:2908` on companion death — companion_id and owner_char_id ARE correctly embedded in the corpse.

6. **`spell_effects.cpp:1720`** — `IsCompanionCorpse()` check already exists and routes to `Companion::ResurrectFromCorpse()`. This code is correct but unreachable because `spells.cpp` kills the spell first.

**The entire system is wired correctly except for the single gate in `spells.cpp:2051`.**

---

### Fix: One-Line Change in spells.cpp

The fix is minimal: in the `ST_Corpse` case, allow companion corpses through alongside player corpses.

**Current (broken):**
```cpp
if(!spell_target || !spell_target->IsPlayerCorpse())
```

**Fixed:**
```cpp
if(!spell_target || (!spell_target->IsPlayerCorpse() && !spell_target->IsCompanionCorpse()))
```

This lets the spell reach `SpellEffect::Revive` in `spell_effects.cpp`, which already has the correct branching:
- `IsPlayerCorpse()` → `CastRezz()` (standard player rez request/accept flow)
- `IsCompanionCorpse()` → `Companion::ResurrectFromCorpse()` (auto-accept, no UI)

---

### Player Corpse Rez (AC-2)

`FindDeadGroupMemberCorpse()` at `companion_ai.cpp:1861` only searches companion corpses. For PRD AC-2 (auto-rez player when player is down), a separate path is needed:

- Entity list function `GetCorpseByOwnerWithinRange(Client*, Mob*, range)` exists at `entity.cpp:2039`
- `FindDeadGroupMemberCorpse()` needs to also check for the owner's player corpse
- When a player corpse is found and targeted, the existing `CastRezz()` path handles it — routes through world to the player's zone, delivers `OP_RezzRequest`, player gets the dialog box (PRD AC-4)
- This is a separate but small extension to `FindDeadGroupMemberCorpse()`

**Priority:** AC-3 (NPC companion rez actually takes) is the primary fix. AC-2 (player rez) is additive.

---

### Timer Logic Review: Correct But Has an Edge Case

Timer state semantics (`companion.cpp:1939–1953`, `companion_ai.cpp:1939–1942`):
- Timer is **Disabled** at construction (never started)
- Timer is **started** on engaged→idle transition (combat ends)
- Timer is **disabled** (consumed) when it fires
- `AI_ResurrectDeadGroupMember()` blocks while timer is **Enabled** (counting down)
- When **Disabled** (never started OR already consumed), rez AI proceeds

**Edge case:** if the Cleric companion never engages (e.g., Cleric stayed out of aggro range), the timer never starts, so the post-combat delay doesn't apply. Rez would fire immediately when a corpse appears. This is arguably correct behavior (Cleric wasn't in combat) and matches the PRD's intent (rez is post-combat, and the Cleric was never IN combat). Acceptable.

---

### Risks

| Risk | Severity | Notes |
|------|----------|-------|
| Other ST_Corpse spells (SummonToCorpse, etc.) granted to companion corpses | Medium | `spell_effects.cpp:1707` already handles `SummonToCorpse` and `Revive` in the same case. Only rez/revive spells should be valid on companion corpses. No SummonCorpse spell would target an NPC; safe. |
| Player accidentally targets companion corpse with player rez | Low | Player's rez dialog uses `CastRezz()` → world routes rez to client `your_name`. For a companion corpse, `your_name` is the NPC name — no client matches → rez silently fails. The `spell_effects.cpp` branch already handles this correctly. |
| Mid-combat rez initiation (AC-8 violation) | Low | `AI_ResurrectDeadGroupMember()` is only called from `AI_IdleCastCheck()` and `AI_ClericIdleSpells()` — idle paths only. No engaged-path call. AC-8 already holds. |
| Multi-target sequencing (AC-6) | Low | `FindDeadGroupMemberCorpse()` returns ONE corpse per call. After rez completes, the next AI tick finds the next corpse. Sequence works but ordering is "first found" not "player first." Architect decides ordering policy. |
| Charm pets / swarm pets / mercs | None | These are NPC but NOT companion corpses (`IsCompanionCorpse()` requires `m_companion_id > 0`). They would still fail `ST_Corpse` check. No regression. |
| `IsCompanionCorpse()` check in message path | Low | `spells.cpp:2057` currently emits `CORPSE_NOT_VALID` for non-player corpses. After fix, companion corpses pass — they won't hit the message path. Message path still fires for non-companion NPC corpses. Correct. |

---

### TDD Test Attachment Points

**Existing tests (Suite 29):** rule checks, XP penalty, corpse metadata (`SetCompanionData`/`IsCompanionCorpse`), `AI_ResurrectDeadGroupMember()` gates. These all pass pre-fix.

**New tests needed (TDD — write failing first):**

| Test | What to Assert | Fails Before Fix | Passes After |
|------|---------------|-----------------|--------------|
| **Suite 29: 29.14** | `SpellFinished()` does NOT cancel a rez spell when target is a companion corpse (i.e., `IsCompanionCorpse()` passes `ST_Corpse` validation) | YES — `IsPlayerCorpse()` check fails | YES |
| **Suite 29: 29.15** | `Companion::ResurrectFromCorpse()` is reachable (mock that `spell_effects.cpp:1720` branch fires for companion corpse) | YES — spell canceled before effects | YES |
| **Suite 29: 29.16** | `AI_ResurrectDeadGroupMember()` returns false when player corpse present but only companion corpse scan (documents current AC-2 gap) | N/A (new behavior) | YES after AC-2 fix |
| **Suite 29: Regression** | Cleric companion casts rez on companion corpse → corpse depops, companion entity spawned, group rejoined | YES — rez fails today | YES |

Full test infrastructure exists in `zone/cli/tests/cli_companion_tests.cpp`. New tests follow the same pattern.

---

### Files to Modify (Implementation Phase)

| File | Action | What Changes |
|------|--------|-------------|
| `zone/spells.cpp` | Modify | `ST_Corpse` case: add `&& !spell_target->IsCompanionCorpse()` to the guard |
| `zone/companion_ai.cpp` | Modify (optional, AC-2) | `FindDeadGroupMemberCorpse()`: also search for owner's player corpse |
| `zone/cli/tests/cli_companion_tests.cpp` | Modify | Add Suite 29.14, 29.15, regression test for BUG-001 |

---

## Stage 4: Implementation Log

### Step A: Failing Tests Written (TDD Red)

Added 4 new tests to `TestCompanionResurrectionSystem()` in
`eqemu/zone/cli/tests/cli_companion_tests.cpp` (before `--- Suite 29 Complete ---`):

| Test | Pre-fix result | Post-fix result |
|------|---------------|-----------------|
| 29.14 | FAILS — DetermineSpellTargets returns false for companion corpse | PASSES |
| 29.15 | FAILS — gate blocked, pipeline unreachable | PASSES |
| 29.16 | PASSES — no-crash structural guard (no Client in zone for player corpse test) | PASSES |
| 29.17 | FAILS — DetermineSpellTargets returns false for companion corpse (Resurrection/392) | PASSES |

Note on 29.16: requires a live `Client` in zone to create a player corpse with owner
name match. Unit test harness constraint — AC-2 player corpse rez live behavior
validated by game-tester Scenario 2.

**Red commit:** `30f6d6ef5` — pushed to `bugfix/companion-rez`.

**Pre-fix failure output:**
```
[❌] Rez > 29.14 DetermineSpellTargets admits companion corpse (ST_Corpse guard) FAILED
   📌 Expected: true
   ❌ Got:      false
(runner exits at first failure)
```

### Step B: Production Code Fixed

**Task 2 — `eqemu/zone/spells.cpp:2049-2063`:**
Extended `ST_Corpse` case in `Mob::DetermineSpellTargets()`. Changed the inner
condition from a single `!IsPlayerCorpse()` check to two booleans:
`is_player_corpse` and `is_companion_corpse`, both requiring `IsCorpse()` first
then the specific predicate via `CastToCorpse()`. The outer guard now rejects
only when neither is true. The `MessageString` path preserves the same error
codes for non-corpse and non-player-non-companion targets.

**Task 3 — `eqemu/zone/companion_ai.cpp:1861-1876`:**
Extended `Companion::FindDeadGroupMemberCorpse()` with player corpse as
priority-1 return via `EntityList::GetCorpseByOwnerWithinRange(owner, this,
rez_range * rez_range)`. Note: `GetCorpseByOwnerWithinRange` compares
`DistanceSquaredNoZ < range` directly (no squaring inside) so we pass
`rez_range * rez_range` for a correct distance check. Companion corpse
remains priority-2 via the existing `GetCompanionCorpseByOwnerWithinRange`.

### Step C: Build and Verify

Build: clean, no warnings, 3 files rebuilt.
```
[1/3] Building CXX object zone/CMakeFiles/zone.dir/companion_ai.cpp.o
[2/3] Building CXX object zone/CMakeFiles/zone.dir/spells.cpp.o
[3/3] Linking CXX executable bin/zone
```

Test suite: ALL suites pass. Suite 29 new cases:
```
[✅] Rez > 29.14 DetermineSpellTargets admits companion corpse (ST_Corpse guard) PASSED
[✅] Rez > 29.15 IsCompanionCorpse() true after SetCompanionData (branch gate) PASSED
[✅] Rez > 29.15 DetermineSpellTargets gate open for companion corpse (pipeline reachable) PASSED
[✅] Rez > 29.16 FindDeadGroupMemberCorpse returns nullptr when no owner in zone (no crash post-fix) PASSED
[✅] Rez > 29.16 FindDeadGroupMemberCorpse callable without crash after player corpse path added PASSED
[✅] Rez > 29.17 DetermineSpellTargets admits companion corpse via Resurrection (392) PASSED
[OK] All Companion Tests Completed!
```

All 13 prior Suite 29 tests: PASS. Full suite (35 suites): PASS. No regressions.

### Step D: Commits and SHAs

| SHA | What |
|-----|------|
| `30f6d6ef5` | TDD red — 4 failing tests |
| `83a96f655` | Production fix — spells.cpp + companion_ai.cpp |

Both pushed to `bugfix/companion-rez` on remote.

### Deviations from Architecture Spec

1. **29.17 test** — Architecture specified 29.17 as a test that "rez attempt on
   companion corpse via AIDoSpellCast does NOT emit CORPSE_NOT_VALID". Implemented
   as DetermineSpellTargets check with Resurrection (spell 392) instead of full
   AIDoSpellCast pipeline — same root assertion, more direct unit test.

2. **29.16 test** — Architecture expected 29.16 to fail pre-fix (player corpse
   not found). Without a Client in zone, player corpse owner matching is impossible
   in unit tests. Test implemented as no-crash structural guard (passes both ways).
   Game-tester Scenario 2 validates the live AC-2 behavior.

3. **`GetCorpseByOwnerWithinRange` range arg** — Architecture noted to verify
   calling convention. Confirmed: the function uses raw `DistanceSquaredNoZ < range`
   (not `< range^2`), so we pass `rez_range * rez_range` to match the spatial
   intent. This is inconsistent with the merc call at `merc.cpp:3728` (which passes
   unsquared 50), but the merc call effectively gets a ~7-unit range which may be
   intentional for merc behavior. For companions we explicitly correct this.

---

## Open Items (All Resolved)

- [x] AC-2 (player corpse rez) — implemented in `FindDeadGroupMemberCorpse`, priority 1
- [x] Multi-target ordering — player first, then companion (hardcoded per architect)
- [x] lua-expert — no Lua changes needed (confirmed by architect audit)
- [x] data-expert — `companion_spell_sets` rez spells confirmed (Suite 29.13 passes)
- [x] Suite 29 tests 29.14–29.17 pass post-fix

---

## v2 Investigation — Production Debug Findings (2026-04-27)

**Context:** v1 fix landed (spells.cpp ST_Corpse + FindDeadGroupMemberCorpse). In-game
validation revealed the spell now reaches ResurrectFromCorpse but three deeper bugs
prevent a successful rez. This section documents the code-grounded findings.

---

### Bug v2-1: `ResurrectFromCorpse` bypasses `Spawn()` — name, immunity strips, and entity-list registration are all wrong

**Evidence:** `companion.cpp:3633-3647`

`ResurrectFromCorpse` creates a `Companion*` then calls:
```
entity_list.AddNPC(new_comp);        // line 3647 — WRONG: adds to npc_list, NOT companion_list
```

But the correct entry point is `entity_list.AddCompanion()` (`companion.cpp:3993-4022`), which:
- Calls `SetID(GetFreeID())` and adds to BOTH `companion_list` AND `mob_list`
- Does NOT add to `npc_list` (the comment at line 4003 explains why — double-processing)

`entity_list.AddNPC()` at `entity.cpp:703` adds to `npc_list` and `mob_list`, but NOT `companion_list`. After the rez, `entity_list.GetCompanionByOwnerCharacterID()`, `GetCompanionsByOwnerCharacterID()`, and all companion-list iteration in the test harness would return null/empty for the rezzed entity. The AI system's companion-specific processing paths would silently skip it.

Additionally, `ResurrectFromCorpse` skips:
1. **Name normalization** — `Spawn()` at line 2403-2404 clears `clean_name[0]` and calls `strcpy(name, GetCleanName())`. Without this, the spawn packet uses the raw name with MakeNameUnique suffix (e.g. `Guard_Liben001`) while `GetCleanName()` produces `Guard Liben`. Titanium client resolves group window clicks by matching these two — a mismatch means the client can't target the rezzed companion.
2. **Immunity strip** — `Spawn()` lines 2432-2440 strips 8 special abilities (MeleeImmunity, MagicImmunity, MeleeImmunityExceptBane, MeleeImmunityExceptMagical, HarmFromClientImmunity, RangedAttackImmunity, ClientDamageImmunity, NPCDamageImmunity) and clears `Invul`. Without this, boss-NPCs recruited as companions re-gain their invulnerability after rez (the source NPCType data still has those bits set).

**Fix:** Route through `Spawn()` instead of calling `AddNPC` directly. The sequence in `ResurrectFromCorpse` should become:
1. Create `Companion* new_comp` (constructor sets position)
2. Call `new_comp->Load(companion_id)` — restores state from DB
3. Call `new_comp->Spawn(owner)` — normalizes name, adds to companion_list, strips immunities, starts AI, joins group
4. Then apply post-rez stats (HP at rez%, 0 mana, BuffFadeAll) AFTER Spawn() since Spawn calls AI_Start which may set HP

The current code calls `AI_Start()`, `Load()`, `LoadEquipment()`, `CalcBonuses()`, `ScaleStatsToLevel()` manually between AddNPC and CompanionJoinClientGroup. If we route through `Spawn()`, some of these are already called inside `Spawn()` (AI_Start) and `SpawnCompanionsOnZone` (Load, ScaleStatsToLevel, etc.), so we need to verify the exact call order doesn't double-call anything.

**Risk of routing through Spawn():** `Spawn()` calls `CompanionJoinClientGroup()`. See Bug v2-2 — the group slot is not freed at death, so this call currently fails. Fix v2-2 (clearing the name slot at death) is a prerequisite before routing through `Spawn()` works end-to-end.

---

### Bug v2-2: Group slot NOT freed at death — `AddMember` returns false on rez, companion spawns but can't join group

**Evidence:** `groups.cpp:1184-1197` (GroupCount), `groups.cpp:596-637` (MemberZoned), `companion.cpp:713-718` (Death calls MemberZoned)

`GroupCount()` iterates `membername[]` (name strings):
```cpp
if (membername[i][0]) { ++MemberCount; }  // groups.cpp:1190
```

`MemberZoned()` clears `members[i]` (the pointer) but does NOT touch `membername[i]`:
```cpp
if (m == removemob) { m = nullptr; }  // groups.cpp:612 — only clears pointer
```

`AddMember()` at `groups.cpp:235` checks `GroupCount() >= MAX_GROUP_MEMBERS` (6). For a full group (player + 5 companions), after the companion dies:
- `MemberZoned(dead_comp)` runs → pointer cleared, name string stays
- `GroupCount()` still returns 6
- Rez spawns new entity, calls `CompanionJoinClientGroup()` → `AddMember(new_comp)` → `GroupCount() >= 6` → returns false
- Companion spawns in the zone but is not in any group: no follow-ID set, no group window entry, no XP sharing

**Scope note:** Even for small groups (player + 1 companion), the name slot for the dead companion still occupies a `membername[]` slot. `GroupCount()` returns 2 after death. `AddMember` (capacity check at 235: `>= 6`) would NOT fail for a 2-person group. BUT the duplicate-name check at line 277-280 would fire:
```cpp
for (const auto& m : membername) {
    if (Strings::EqualFold(m, new_member_name)) { return false; }
}
```
The dead companion's name is still in `membername[]`. The new rezzed companion has the same clean name. `AddMember` returns false on the name-collision check.

So the group slot bug fires for ALL group sizes — either via capacity check (full group) or via name-collision check (any size).

**Fix:** `MemberZoned()` must clear BOTH `members[i]` AND `membername[i]` when removing a dead companion. However, `MemberZoned()` is also called for legitimate zone-out (player moving to another zone while still conceptually in the group, so world server can track cross-zone membership). The comment at `groups.cpp:606` says "should NOT clear the name, it is used for world communication." Clearing the name for zone-out breaks cross-zone group tracking.

The fix must therefore distinguish between:
1. **Dead companion removal at death** — must clear BOTH pointer AND name string (slot is no longer in use; companion will rejoin as a new entity on rez with a new entity ID)
2. **Zoned-out living member** — clear pointer only, keep name string (cross-zone group tracking)

Options:
- Add an `is_dead` parameter to `MemberZoned()` — if true, also clear `membername[i]`. This is a localized change.
- Add a separate `RemoveMemberByDeath(Mob*)` method that clears both and call it from `Companion::Death()` instead of `MemberZoned()`.
- Clear the name explicitly in `Companion::Death()` after calling `MemberZoned()`.

The third option is the least invasive — do it in companion.cpp without touching groups.cpp (no risk to cross-zone group tracking for players/bots). After `g->MemberZoned(this)`, iterate `g->membername[]` and null-terminate the slot that matches `GetCleanName()`.

**file:line:** `companion.cpp:713-718` is where `Companion::Death()` calls `MemberZoned()`. The fix goes here or just below.

---

### Bug v2-3: Owner zones out — pending rez state is lost forever

**Evidence:** `companion.cpp:4133-4215` (SpawnCompanionsOnZone), `companion.cpp:3578-3584` (owner-not-in-zone early return)

`SpawnCompanionsOnZone()` at `companion.cpp:4155`:
```cpp
if (cd.is_suspended) { continue; }  // skips dead companions on zone-in — intentional
```

A dead companion (`is_suspended=1`) is never re-spawned when the owner zones in. This is correct behavior for normal zone-in. But it creates an unresolvable stuck state when:

1. Player is in Zone A with 5 companions. Warrior companion dies. Cleric begins rez.
2. Player zones to Zone B while rez is in-flight (or after the corpse forms but before the 10-second delay expires).
3. Zone A: `ResurrectFromCorpse` fires, owner not in zone → early return (line 3583). Corpse may or may not have been consumed at this point (IsRezzed=true set at line 3587, but DepopNPCCorpse at 3630 may not have run yet — the rez returned before either).
4. Zone B: `SpawnCompanionsOnZone` runs, skips the `is_suspended=1` Warrior.
5. Player is stuck: Warrior is `is_suspended=1` in DB forever, no mechanism to re-trigger the rez. `!unsuspend` would restore the Warrior but lose the rez XP and skip the group-rejoin flow.

**Existing zone-in handler:** `client_packet.cpp:1070` calls `SpawnCompanionsOnZone()`. This is the correct hook point. The fix would add a second query inside `SpawnCompanionsOnZone()` that looks for `is_suspended=1 AND is_dismissed=0` companions — i.e., dead ones — and checks if a corpse for them exists in the new zone. If no corpse exists (cross-zone zoning, corpse was in old zone), the companion should be auto-recovered: mark `is_suspended=0` (revive at minimum HP, 0 XP rez) or leave suspended and announce to the player that `!unsuspend` is available.

However: a dead companion's corpse does NOT follow the owner to the new zone (entity-only, zone-memory only). The Cleric companion (if alive) also zones with the owner to Zone B. In Zone B, the Cleric's rez-delay-timer fires normally, `FindDeadGroupMemberCorpse()` finds nothing (no corpse in Zone B), rez silently does nothing. The dead companion is indefinitely stuck.

**Practical scope for this fix:** The cleanest minimal fix is: when `SpawnCompanionsOnZone()` finds a `is_suspended=1` companion, rather than silently skip it, check if there is a companion corpse for it in the CURRENT zone. If yes → let the normal rez flow handle it (Cleric will rez). If no (zone-crossed while dead) → auto-recover at 10% HP (equivalent to a 0% XP rez, i.e., Reanimation). This preserves the XP penalty already taken at death and doesn't require a Cleric to be present.

An even simpler fallback: just log a warning and tell the player "Your companion X was unable to be resurrected and has returned home." (equivalent to auto-dismiss). This matches the existing `DeathDespawnS` behavior if the timer expires.

**Whether to fix in this pass:** The team-lead message says this is one of three bugs. The architect should decide whether to add auto-recovery on zone-in or defer. It requires touching `SpawnCompanionsOnZone()` and possibly a new auto-revive path.

---

### BUG-028 (Pre-existing) — Entity id=0 at death

`companion.cpp:669` already has the fallback guard: if `GetID() == 0 && m_companion_id > 0`, skip the ORM Save() and use a direct SQL UPDATE. This was implemented as a defense-in-depth fix for BUG-028. The root cause of id=0 at death is that the entity ID can be 0 if the companion is being removed from the entity list at the exact tick it takes fatal damage (entity list cleanup runs before the damage callback completes). The fallback exists and is tested; no additional fix needed for BUG-028 itself. The v2-1 fix (routing through `AddCompanion` instead of `AddNPC`) ensures the rezzed entity is properly in `companion_list` with a valid ID going forward.

---

### Summary Table — v2 Bugs

| Bug | File:Line | What fails | Fix |
|-----|-----------|-----------|-----|
| v2-1 | `companion.cpp:3647` | `AddNPC` instead of `AddCompanion`; skips name normalization and immunity strip | Route entity creation through `Spawn(owner)` instead of manual `AddNPC`+`AI_Start` |
| v2-2 | `companion.cpp:713-718` + `groups.cpp:1184,277` | `MemberZoned` clears pointer but not name; `GroupCount` and name-collision check both prevent AddMember on rez | After `g->MemberZoned(this)`, also clear `membername[slot]` for the dead companion in `Companion::Death()` |
| v2-3 | `companion.cpp:4155` | Dead companions skipped on zone-in; no auto-recovery if owner zones while companion is dead | Add recovery path in `SpawnCompanionsOnZone()` for `is_suspended=1` companions (auto-revive at 10% HP or auto-dismiss with message) |

---

### Cross-cutting Risk: `Spawn()` call order

If we route `ResurrectFromCorpse` through `Spawn()`, the call sequence must be:
1. `Load(companion_id)` — restore DB state including stance, equipment refs
2. `Spawn(owner)` — name normalization, `AddCompanion`, entity ID assignment, `AI_Start`, immunity strip, `CompanionJoinClientGroup`
3. `LoadEquipment()` — must come after entity ID is assigned (item attachment uses entity ID)
4. `CalcBonuses()`
5. `ScaleStatsToLevel()`
6. Set post-rez HP/mana, `BuffFadeAll`

The current broken sequence (`AddNPC`, `AI_Start`, `Load`, `LoadEquipment`, `CalcBonuses`, `ScaleStatsToLevel`) partially overlaps. The fix must not double-call `AI_Start` or `Load`. The `Spawn()` implementation calls `AI_Start()` at line 2418 — so we must NOT call `AI_Start()` separately if we route through `Spawn()`.

Note: `SpawnCompanionsOnZone()` also calls `Load()` before `Spawn()`. The rez path should follow the same pattern: Load → Spawn → LoadEquipment → post-rez stats.

---

### Verify: `GetCorpseByOwnerWithinRange` range argument (from v1)

Confirmed in v1 dev-notes: passes `rez_range * rez_range` because the function uses raw `DistanceSquaredNoZ < range` (not `< range^2`). The v2-3 fix doesn't change this.

---

### v2 TDD — New Tests Required

| Test | Suite | What | Fails Before Fix | Passes After |
|------|-------|------|-----------------|--------------|
| 30.1 | Suite 30 (new) | After `ResurrectFromCorpse`, new entity is in `companion_list` (not just `npc_list`) | YES — `AddNPC` doesn't add to companion_list | YES |
| 30.2 | Suite 30 | After rez, new entity has normalized name (clean_name matches spawn packet name) | YES — name normalization skipped | YES |
| 30.3 | Suite 30 | After rez, group slot for dead companion is freed (name cleared); `AddMember` succeeds for rezzed companion | YES — name slot not cleared | YES |
| 30.4 | Suite 30 | BUG-028 regression: `entity id=0` at death guard fires correctly (existing v1 coverage sufficient; confirm still passes) | NO (existing) | YES (existing) |
