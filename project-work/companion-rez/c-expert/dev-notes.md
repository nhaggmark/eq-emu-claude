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

---

## Stage 5: V2 Production Debug — Exact Citations (architect request)

**Context:** Architect asked for exact file:line for all three bugs before finalizing v2
architecture plan. This section supplements the v2 Investigation section above with
precise call-chain citations and formal answers to each question.

---

### Question 1 — Bug R-1: Exact citations for AddNPC + CompanionJoinClientGroup failure chain

**1a. AddNPC call in ResurrectFromCorpse:**
`companion.cpp:3647` — `entity_list.AddNPC(new_comp);`

Immediately preceding context: corpse depopped at line 3630, new Companion constructed at 3633-3635, SetCompanionID/SetOwnerCharacterID/etc at 3638-3644, then AddNPC at 3647.

**1b. CompanionJoinClientGroup call in ResurrectFromCorpse:**
`companion.cpp:3680` — `new_comp->CompanionJoinClientGroup();`

Called after AI_Start(3650), Load(3651), LoadEquipment(3652), CalcBonuses(3653), ScaleStatsToLevel(3657), SetHP/SetMana/BuffFadeAll (3663-3674).

**1c. Name normalization in Spawn():**
`companion.cpp:2403-2404`:
```cpp
clean_name[0] = '\0';
strcpy(name, GetCleanName());
```
ResurrectFromCorpse skips these lines entirely — it never calls Spawn() and never touches `name` or `clean_name` after the Companion constructor.

**1d. Where AddMember failure in existing group → Suspend() → Depop():**
`companion.cpp:2693-2711` — the existing-group branch of `CompanionJoinClientGroup()`:
```cpp
if (g->AddMember(this)) {          // line 2693 — returns false (see group slot issue below)
    ...
} else {
    Suspend();                      // line 2709 — THIS fires on AddMember failure
    LogInfo("Companion [{}] failed to join existing group — suspending", ...);
}
```

`Suspend()` at `companion.cpp:2465-2481`:
- line 2467: `SetSuspended(true)` — overwrites the `is_suspended=0` written by ResurrectFromCorpse at line 3624 (DB UPDATE already ran). This is the DB corruption: rez XP was restored, `is_suspended` was cleared, then Suspend() reverses both.
- line 2470: `Save()` — writes `is_suspended=1` and the companion's current state back to DB, permanently losing the XP restore.
- line 2478: `Depop()` — removes entity from zone

`Depop()` at `companion.cpp:2538-2569`:
- line 2548-2550: calls `RemoveCompanionFromGroup(this, GetGroup())`. But the new rez entity was NEVER in a group (AddMember failed), so `HasGroup()` is false and this is a no-op.
- line 2555: `entity_list.RemoveCompanion(GetID())` — BUT: since AddNPC was used (not AddCompanion), the entity was never in `companion_list`. RemoveCompanion finds nothing to remove. The entity IS in `npc_list` and `mob_list` (via AddNPC), but RemoveCompanion only iterates `companion_list`. The entity leaks from `npc_list` and `mob_list` — it's in the zone's entity tables but marked for depop. This is a secondary memory issue but process() returning false will eventually evict it.
- line 2569: `NPC::Depop(false)` — sets internal depop flag, entity removed on next process tick.

**Net result of R-1 AddMember failure:**
1. Corpse already depopped (line 3630) — no recovery possible.
2. DB: `is_suspended=1` written by Suspend()/Save() — the `is_suspended=0` + XP restore from line 3624 is overwritten. Companion is back to dead state, XP penalty taken again with no restoration.
3. new entity: leaks from npc_list/mob_list briefly, depopped next process tick.
4. Player sees: "companion appears briefly, immediately vanishes" or simply never appears (if AddNPC→spawn packet races with Depop→DeleteSpawn).

**1e. Does the dead companion still occupy its group slot at rez time?**

YES. Sequence at death:
1. `Companion::Death()` at `companion.cpp:619`: calls `NPC::Death()` first.
2. Line 627: `SetDepop(false)` — prevents standard NPC entity removal. Entity stays alive in zone as dead mob.
3. Lines 713-718: `g->MemberZoned(this)` — `groups.cpp:596-637` clears `members[i]` (pointer) but does NOT clear `membername[i]` (name string). Comment at line 606: "should NOT clear the name, it is used for world communication."

`GroupCount()` at `groups.cpp:1184-1196` counts non-empty `membername[]` slots. Since MemberZoned only clears the pointer, the dead companion's name string persists in `membername[]`. `GroupCount()` still counts the dead companion.

`AddMember()` at `groups.cpp:235`: capacity check `GroupCount() >= MAX_GROUP_MEMBERS` (6). For a group of player + 5 companions, this fires immediately. Even for smaller groups, the name-collision check at `groups.cpp:277-280` fires because `Strings::EqualFold(membername[i], new_comp->GetCleanName())` matches the dead companion's still-present name string.

**Why DelMember is NOT called at death:** `DelMember` at `groups.cpp:698-798` does clear the name slot (line 720: `membername[i][0] = '\0'`). But DelMember is called by `RemoveCompanionFromGroup` → called by `Depop()`. Depop() is NOT called at death — `Companion::Death()` explicitly resets `p_depop=false` at line 627 to preserve the entity for the rez window. Depop() only runs when (a) despawn timer fires, (b) Suspend() is called, or (c) the player explicitly dismisses. None of these happen between death and rez attempt.

**Root cause of R-1:** Two independent bugs that compound:
- A: ResurrectFromCorpse uses AddNPC instead of AddCompanion (wrong entity list)
- B: Dead companion's group slot (name string) is not freed at death, so AddMember always returns false for the rez entity

Fix B must land before Fix A (routing through Spawn()) will work end-to-end, because Spawn() calls CompanionJoinClientGroup() which calls AddMember().

---

### Question 2 — Bug R-2: Owner zones out, pending rez state lost

**2a. GetCompanionOwner() body:**
`companion.cpp:3903-3906`:
```cpp
Client* Companion::GetCompanionOwner() const
{
    return entity_list.GetClientByCharID(m_owner_char_id);
}
```
`entity_list.GetClientByCharID()` returns nullptr if the client is not currently in THIS zone's entity list. When the owner zones out, they are removed from the zone's `client_list` immediately. Any subsequent `GetCompanionOwner()` call returns nullptr.

**2b. Zone-out event for the owner — does it flag pending rez state?**

When a player zones, `ClientList::Process()` in world detects the zone change and routes the player. In the zone-side entity list, the Client object is delinked and eventually freed. There is NO hook in the current companion code that fires when the owner leaves the zone. No `OnOwnerZoneOut()`, no `OnOwnerDisconnect()`, no pending-rez persistence.

`CompanionJoinClientGroup()` at line 2628: `GetCompanionOwner()` returns nullptr → calls `Suspend()` at line 2630. This fires on the NEXT AI tick after the owner zones (when any companion logic calls `GetCompanionOwner()`). This is correct behavior for live companions (they Suspend and persist in DB until owner zones in again). But for a dead companion, `m_companion_ai` is not running, so this path does not fire.

The dead companion entity just sits in the zone. `m_death_despawn_timer` continues ticking. When it fires (30 minutes), the companion auto-dismisses (`is_dismissed=1` written). This is the only cleanup path.

**2c. Cross-zone pending-rez persistence — what and where:**

**What's lost:** The corpse entity is zone-memory only. When the zone unloads or the corpse's decay timer fires (30 minutes), it's gone. The Cleric companion (if alive) zones with the owner and has no pending rez flag. On zone-in in the new zone, `SpawnCompanionsOnZone()` skips `is_suspended=1` rows. No rez fires.

**Where persistence would need to live:** There are two options:

Option A — `companion_data` column: add a `pending_rez` boolean (or `rez_spell_id` int). `ResurrectFromCorpse` would write `pending_rez=1, rez_spell_id=X` before proceeding (so if owner is not in zone, the column is set). `SpawnCompanionsOnZone()` would check: if `is_suspended=1 AND pending_rez=1` → auto-revive at the stored rez% on zone-in. Requires a schema migration.

Option B — `data_buckets`: key = `companion_pending_rez_<companion_id>`, value = `spell_id`. Written when rez fires with owner not in zone. Checked on zone-in. No schema change. data-expert confirms companion system already uses data_buckets for similar state.

Option C — Auto-recover at fixed 10% HP on zone-in with no DB tracking: `SpawnCompanionsOnZone()` checks `is_suspended=1 AND is_dismissed=0` and auto-revives at minimum HP (Reanimation-equivalent) without a Cleric present. Simplest. Loses the rez-spell-quality differentiation (always 10% HP regardless of what spell was attempted). Still applies the death XP penalty already taken at death.

**Architect's call on scope.** The simplest defensible fix is Option C; it closes the "stuck forever" case without requiring a schema migration or cross-zone state tracking. data_buckets (Option B) is more correct but adds complexity. I flag Option C as the TDD-safe minimal fix for this pass.

---

### Question 3 — Bug R-3: Entity id=0 and corpse metadata integrity

**3a. Where does entity id=0 occur in Death() sequence:**

`Companion::Death()` at line 619 calls `NPC::Death()` first. Inside `NPC::Death()` (in `attack.cpp`), at line 2899: `entity_list.AddCorpse(corpse, GetID())`. `GetID()` is the entity's current entity ID. If id=0 at this point, the corpse is added with npc_id=0 (the corpse's internal `npc_id` tracking field — different from `m_companion_id`).

Then at `attack.cpp:2908`: `corpse->SetCompanionData(comp->GetCompanionID(), comp->GetOwnerCharacterID())`. `GetCompanionID()` is `m_companion_id` — a plain integer member of the Companion object, NOT derived from the entity list ID. It is set at construction time and by `SetCompanionID()`. **Even if entity id=0, `m_companion_id` is valid.** The corpse gets the correct `companion_id` and `owner_char_id`.

**3b. Does entity id=0 corrupt the corpse m_companion_id field? NO.**

`m_companion_id` and the entity list ID are completely separate. `GetID()` returns the entity list ID (slot in `npc_list` / `mob_list`). `GetCompanionID()` returns `m_companion_id`. `SetCompanionData()` uses only `GetCompanionID()` and `GetOwnerCharacterID()` — neither is the entity ID.

The existing fallback at `companion.cpp:669-701` handles the DB side: if entity id=0, skip the ORM Save() and run a direct SQL UPDATE to ensure `is_suspended=1` is persisted. The fallback runs BEFORE `NPC::Death()` is called (the sequence: ApplyDeathXPPenalty at 616, then NPC::Death at 619, then the DB save block at 669). Actually re-reading: the DB save block at 669-701 is inside the `owner != nullptr` branch which comes AFTER `NPC::Death()`. Let me clarify sequence:

Line 616: `ApplyDeathXPPenalty()`
Line 619: `result = NPC::Death(...)` — corpse created with `SetCompanionData` here
Line 627: `SetDepop(false)`
Lines 631-645: equipment handling
Line 649: `Client* owner = GetCompanionOwner()`
Lines 650-704: owner notification + DB save (includes entity id=0 guard at 669-701)
Lines 713-718: `g->MemberZoned(this)` — group pointer cleared

So the entity id=0 SQL fallback fires AFTER the corpse is already created with correct companion metadata. BUG-028 does not corrupt corpse metadata. **No additional fix needed for R-3.**

**3c. Does id=0 cause any other rez-path issue beyond what BUG-028 already handles?**

One edge case: `entity_list.AddCorpse(corpse, GetID())` at `attack.cpp:2899` passes `GetID()=0` as the NPC's entity ID for corpse indexing. The corpse is added to `corpse_list` with its own new entity ID (assigned by `GetFreeID()` inside `AddCorpse`). The `0` argument is the NPC ID passed to the corpse constructor for `npc_id` tracking, not the corpse's entity ID. `IsCompanionCorpse()` uses `m_companion_id > 0`, not npc_id. So id=0 at death does not affect `IsCompanionCorpse()` or `ResurrectFromCorpse`. **Confirmed non-issue for the rez path.**

---

### Question 4 — Fix sites with exact function/file:line and dependency order

**Fix A — Free the dead companion's group slot at death (prerequisite for everything)**

**File:line:** `companion.cpp:713-718` — after `g->MemberZoned(this)`.

**What:** After `MemberZoned()` clears the `members[i]` pointer, also null-terminate the matching `membername[i]` slot. Iterate `g->membername` matching `GetCleanName()`. This ensures `GroupCount()` decrements and the name-collision check passes for the rez entity.

**Why not in groups.cpp:** The "should NOT clear the name" comment at `groups.cpp:606` applies to living members who zone out (cross-zone group tracking). Dead companions are different — they won't zone back in as the same entity; they'll come back as a brand-new entity with a new entity ID. Clearing the name for death-only is correct and safe.

**Dependencies:** None. Must land first.

**Subtlety:** `HasGroup()` check at line 713 ensures we don't iterate a null Group pointer. The name to match is `GetCleanName()` (not `GetName()`) — this is the value that was stored in `membername[]` by `AddMember()` at `groups.cpp:260` (`new_member_name = new_member->GetCleanName()`). Name normalization in Spawn() (Fix B below) ensures GetCleanName() is stable at death.

**Fix B — Route ResurrectFromCorpse entity creation through Spawn()**

**File:line:** `companion.cpp:3632-3680` — replace the manual construction block.

**What:** Replace the current sequence (Companion constructor → attribute setters → AddNPC → AI_Start → Load → LoadEquipment → CalcBonuses → ScaleStatsToLevel → CompanionJoinClientGroup) with:
1. `new Companion(npc_type_data, x, y, z, h, owner_char_id, companion_type)` — constructor
2. `SetCompanionID()`, `SetOwnerCharacterID()`, etc. — preserve attribute init
3. `new_comp->Load(companion_id)` — restore DB state (must be before Spawn for stance/equipment refs)
4. `new_comp->Spawn(owner)` — normalizes name, AddCompanion, entity ID, AI_Start, immunity strip, CompanionJoinClientGroup
5. `new_comp->LoadEquipment()`, `CalcBonuses()`, `ScaleStatsToLevel()` — after entity ID assigned
6. Set post-rez HP/mana/BuffFadeAll — after ScaleStatsToLevel sets max HP

**Dependencies:** Fix A must land first (Spawn calls CompanionJoinClientGroup which calls AddMember — will fail until group slot is freed).

**Subtlety 1:** `Spawn()` calls `AI_Start()` at line 2418. Do NOT call `AI_Start()` separately. Calling it twice double-registers the AI timer and double-calls `LoadCompanionSpells()`.

**Subtlety 2:** `Load()` before `Spawn()` is the pattern from `SpawnCompanionsOnZone()` (lines 4183-4201). Follow that pattern exactly.

**Subtlety 3:** The corpse is already depopped at line 3630 before this block. Spawn() will call `CompanionJoinClientGroup()` which can now succeed (Fix A landed). But if Spawn() fails (entity ID not assigned — rare), we have an inconsistent state: corpse gone, DB updated, new entity not spawned. This is the "atomic transaction" question (see Fix C below).

**Fix C — Handle rez failure atomically so DB state is not corrupted on Spawn() failure**

**File:line:** `companion.cpp:3616-3680` — the DB UPDATE + corpse depop + entity creation sequence.

**Current problem:** DB UPDATE at line 3624 (`is_suspended=0`, XP restored) runs BEFORE corpse depop and entity creation. If Spawn() then fails (entity ID=0, AddCompanion fails), the DB is in an inconsistent state: `is_suspended=0` but no entity in zone.

**Proposed fix:** Defer corpse depop to AFTER Spawn() succeeds:
1. Save corpse position.
2. Call `new_comp->Load(companion_id)`.
3. Call `new_comp->Spawn(owner)` — entity creation.
4. If Spawn() returns false: `delete new_comp; return;` — corpse stays alive, DB not updated yet, rez can retry.
5. If Spawn() succeeds: THEN run DB UPDATE (`is_suspended=0`, XP restore) and THEN `corpse->DepopNPCCorpse()`.

This is a tighter invariant: either the full rez completes (entity in zone + DB updated + corpse gone) or nothing changes (entity not created + DB unchanged + corpse still present).

**Dependencies:** Fix B (routing through Spawn) makes the Spawn() return value meaningful and available.

**Subtlety:** The current code at line 3587 calls `corpse->IsRezzed(true)` before the DB UPDATE and before entity creation. This is a race guard (prevents concurrent rez attempts). With the new ordering, we still need `IsRezzed(true)` early (before Spawn) to block concurrent casts. But we can treat a Spawn() failure as "rez failed — reset IsRezzed to false" so the corpse becomes rezzable again. This is safe because Spawn() failure is deterministic (entity list full or similar), not a race condition.

---

### Question 5 — Fourth bug candidate

**Potential R-4: Dead companion entity is still in mob_list and receives AI ticks**

`Companion::Death()` sets `SetDepop(false)` at line 627 to keep the entity alive for the rez window. The entity stays in `mob_list` and `Companion::Process()` continues to tick. In `Companion::Process()`, the `m_death_despawn_timer` check at line ~1911 fires after 30 minutes to auto-dismiss.

The risk: `Companion::AI_Process()` or `AI_IdleCastCheck()` can fire on this dead entity during the rez window. If the dead companion is a Cleric, it could try to rez itself. `AI_ResurrectDeadGroupMember()` calls `FindDeadGroupMemberCorpse()` which looks for corpses by `owner_char_id` — it would find its OWN corpse. It would then cast a rez spell targeting itself.

`AI_ResurrectDeadGroupMember()` has no guard for "I am the dead companion." It only checks `AnotherCompanionIsRezzing()` (are OTHER companions currently casting rez). A dead Cleric casting rez on its own corpse would walk into `ResurrectFromCorpse` and hit the `GetCompanionOwner()` check at line 3578 (owner must be in zone) — this acts as a soft guard. But if the owner IS in zone, the dead Cleric would attempt to rez itself, which is logically absurd and may produce erratic behavior.

**Severity:** Low. Clerics are usually the rezzer, not the dead. In a party where the Cleric died, another rez-capable class would need to be present anyway. And `AI_ResurrectDeadGroupMember()` is gated by `m_rez_delay_timer` (must have fired) and by `GetHP() > 0` check... actually let me verify whether there's an HP guard.

I do not have `AI_ResurrectDeadGroupMember()` open right now, but the relevant guard is whether the function checks if `this` (the casting companion) is alive. If not, this is a genuine edge-case bug. I flag it as a potential R-4 for architect investigation — worth checking `companion_ai.cpp:1927-2011` for a self-rez guard.

---

### Question 6 — Cross-zone resilience summary

**Current state (fully documented above):**
- Corpse: zone-memory only, lost when zone unloads or timer expires.
- Dead companion `is_suspended=1` row: persists in DB indefinitely.
- Pending rez: nothing persists cross-zone. Cleric zones with owner but has no pending-rez flag.
- Recovery: `!unsuspend` works (brings back at full HP, no rez XP, proper group-rejoin).

**Minimum fix for this pass (no schema change):**
In `SpawnCompanionsOnZone()` at `companion.cpp:4155`, when `cd.is_suspended=1 AND cd.is_dismissed=0`:
- Instead of silently skipping, log a message to the player: "Your companion X was unable to be resurrected and has returned. Use `!unsuspend` to bring them back."
- Optionally: auto-call Unsuspend with HP set to 10% of max (Reanimation-equivalent). This is Option C from the v2 Investigation section.

The auto-unsuspend approach requires calling `Spawn(this)` on the companion, which is the same path as `SpawnCompanionsOnZone` already does for non-suspended companions. The difference is setting HP to 10% post-spawn instead of full HP. This is a small delta.

**Architect recommendation:** Implement auto-unsuspend at 10% HP in `SpawnCompanionsOnZone()` for `is_suspended=1` companions when no corpse is found in the current zone. This is the minimum behavior to avoid the "stuck forever" case. It does not restore the rez XP (penalty remains), which is correct — the death penalty was already applied.
