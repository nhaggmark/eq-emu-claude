# companion-aggro-fixes — Architecture & Implementation Plan

> **Feature branch:** `bugfix/companion-aggro-fixes`
> **PRD:** `game-designer/prd.md`
> **Author:** architect
> **Date:** 2026-03-08
> **Status:** Approved

---

## Executive Summary

Companion NPCs generate zero persistent hate/aggro on mobs because the
Companion class does not override `IsOfClientBotMerc()` (returns `false`).
Regular NPCs periodically call `WipeHateList(true)` in their AI tick,
which preserves hate entries for Clients, Bots, and Mercs but wipes all
plain NPCs — including Companions, which appear indistinguishable from
regular NPCs to this check. The fix is a one-line override in
`companion.h` to make `IsOfClientBotMerc()` return `true`, plus a
related override for `IsOfClientBot()`. A secondary issue in the
`SmartAggroList` path of `GetMobWithMostHateOnList()` also prevents
Companions from being recognized as valid tank targets, which requires
adding Companion handling alongside the existing Bot and Merc checks.

## Existing System Analysis

### Current State

**Hate list lifecycle for a regular NPC target being attacked:**

1. Attacker (companion) calls `NPC::Attack(target)` which calls
   `target->AddToHateList(this, hate)` at `attack.cpp:2381`.
2. Damage is applied via `target->Damage(this, ...)` at `attack.cpp:2397`,
   which also calls `AddToHateList(attacker, 0, damage, ...)` at
   `attack.cpp:4124`.
3. Both calls successfully add the companion to the target's hate list
   (`HateList::AddEntToHateList()` in `hate_list.cpp:206`).
4. On the target's next `AI_target_check_timer` tick (in `mob_ai.cpp:1066`),
   the target calls `WipeHateList(true)`.
5. `WipeHateList(true)` iterates the hate list (`hate_list.cpp:44-72`):
   - Entries where `m->IsOfClientBotMerc()` returns `true` are **preserved**.
   - Entries where `m->IsPet() && m->GetOwner() && m->GetOwner()->IsOfClientBotMerc()`
     are **preserved**.
   - **All other entries are removed.**
6. Since `Companion::IsOfClientBotMerc()` returns `false` (no override;
   inherits `Entity::IsOfClientBotMerc()` default), the companion entry
   is **wiped every tick**.

**Result:** Companions briefly appear on the hate list after each attack but
are removed within milliseconds on the next AI tick. The mob always retargets
to the player (who IS preserved because `Client::IsOfClientBotMerc()` returns
`true`).

**How Bots solve this:** `Bot` overrides both `IsOfClientBot()` and
`IsOfClientBotMerc()` to return `true` (bot.h:795-796). This ensures bots
are never wiped from hate lists and are treated as valid tank targets.

**How Mercs solve this:** `Merc` overrides `IsOfClientBotMerc()` to return
`true` (merc.h:125).

### Gap Analysis

1. **`IsOfClientBotMerc()` not overridden** — Companion class inherits
   `false` from Entity base. This causes companions to be wiped from ALL
   NPC hate lists every AI tick.

2. **`IsOfClientBot()` not overridden** — Companion class inherits `false`
   from Entity base. This causes companions to miss aggro modifiers
   (sitting/melee range bonuses) in the SmartAggroList path and other
   combat calculations that branch on `IsOfClientBot()`.

3. **SmartAggroList tank target recognition** — In
   `hate_list.cpp:481-506`, the SmartAggroList logic checks if the
   top-hate entity is a Client, Bot, Merc, or has `AllowedToTank`.
   Companions are none of these, so even if a companion somehow stayed
   on the hate list, the mob would prefer to attack a client/bot/merc
   in melee range over the companion. This prevents companions from
   functioning as tanks.

## Technical Approach

### Architecture Decision

This is a pure C++ fix. The bug is in the Entity class hierarchy — the
Companion class is missing virtual method overrides that signal to the
combat and hate systems that it should be treated as a player-allied
entity rather than a plain NPC.

No Lua, SQL, rule, or config changes are needed. This cannot be solved
at any layer other than C++ because the `IsOfClientBotMerc()` method is
called in tight inner loops of the combat and AI systems that have no
script hooks.

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| `zone/companion.h` | Add two method overrides | Missing `IsOfClientBotMerc()` and `IsOfClientBot()` overrides are the root cause |
| `zone/hate_list.cpp` | Add companion recognition in SmartAggroList | Companion needs to be recognized as valid tank target alongside Bot/Merc |

### Data Model

No data model changes required.

### Code Changes

#### C++ Changes

**File 1: `eqemu/zone/companion.h`** (2 lines added)

Add overrides to the type identification section (after line 102):

```cpp
// Type identification
virtual bool IsCompanion() const override { return true; }
virtual bool IsNPC()       const override { return true; }
virtual bool IsOfClientBot()     const override { return true; }  // NEW
virtual bool IsOfClientBotMerc() const override { return true; }  // NEW
```

These overrides make the companion visible to:
- `WipeHateList(true)` — companion entries will be preserved on hate lists
- `GetMobWithMostHateOnList()` SmartAggroList — companion gets aggro modifiers
- `offense()` and `mitigation()` calculations that branch on `IsOfClientBotMerc()`
- All other combat and spell systems that check these methods

**File 2: `eqemu/zone/hate_list.cpp`** (approx 6 lines added)

In `GetMobWithMostHateOnList()` at the SmartAggroList section
(after the Merc check at line ~495), add a Companion check:

```cpp
if (!is_top_client_type) {
    if (top_hate->IsCompanion()) {
        is_top_client_type          = true;
        top_client_type_in_range = top_hate;
    }
}
```

This ensures that when a companion has the highest hate and is in
melee range, the mob treats it as a valid tank target and will not
switch to a client-type entity behind it.

#### Lua/Script Changes

None required.

#### Database Changes

None required.

#### Configuration Changes

None required.

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | Add `IsOfClientBot()` and `IsOfClientBotMerc()` overrides to `companion.h` | c-expert | — | 2 lines |
| 2 | Add companion recognition in `GetMobWithMostHateOnList()` SmartAggroList in `hate_list.cpp` | c-expert | — | ~6 lines |
| 3 | Build and verify compilation | c-expert | 1, 2 | Build cycle |

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Adding `IsOfClientBotMerc()` override causes unintended side effects in combat formulas | Low | Medium | The override aligns companion behavior with Bot/Merc, which already work correctly. The combat formula branches (offense, mitigation, stun immunity) all behave correctly for Bot/Merc and will behave identically for companions. |
| Companion tanks too effectively, trivializing content | Low | Low | Companion tankability is already bounded by their HP, AC, and level from npc_types. They won't suddenly become invincible — they'll just properly hold aggro. This is the intended design. |
| `IsOfClientBotMerc()` returning true changes how spells interact with companions | Low | Low | Spells that check `pcnpc_only_flag` (effects.cpp:1155-1159) will now treat companions as PC-type targets. This is actually correct — companions should receive PC-targeted buffs from group members, not NPC-only debuffs. |

### Compatibility Risks

No backward compatibility concerns. This fix only affects the Companion
class, which is custom to this project. No standard EQEmu behavior is
modified.

### Performance Risks

None. The added checks are trivial boolean method calls in existing
code paths. No new allocations, queries, or iteration.

## Review Passes

### Pass 1: Feasibility

Fully feasible. The fix follows the exact same pattern used by Bot
(bot.h:795-796) and Merc (merc.h:125). The Companion class already
inherits from NPC, which inherits from Mob, which inherits from Entity
where these virtual methods are declared. Adding overrides in the header
is trivial.

The SmartAggroList fix in hate_list.cpp follows the existing pattern of
Bot (line 484) and Merc (line 491) checks. Adding a Companion check
after Merc is structurally identical.

### Pass 2: Simplicity

This is already the simplest possible fix:
- 2 lines in companion.h (method overrides)
- ~6 lines in hate_list.cpp (companion recognition in SmartAggroList)
- No new systems, no new data, no new configuration

Alternative approaches considered and rejected:
- **Rule-based toggle**: Not applicable — the issue is a missing type
  classification, not a tuning value.
- **Special ability `AllowedToTank`**: Would fix only the SmartAggroList
  issue, not the WipeHateList issue. Would require setting the special
  ability on every companion spawn, adding unnecessary complexity.
- **Modifying `WipeHateList()` to check `IsCompanion()`**: Would fix
  the primary issue but not the SmartAggroList issue or the many other
  combat systems that check `IsOfClientBotMerc()`. The override approach
  fixes all of them at once.

### Pass 3: Antagonistic

**Edge case: Charm interactions.** If a companion has `IsOfClientBotMerc()`
returning true, could a charmed companion be treated differently?
Analysis: Charm sets `type_of_pet = PetType::Charmed` which is checked
separately from `IsOfClientBotMerc()`. No interaction.

**Edge case: PVP guard assist.** The guard assist code in
`NPC::Attack()` (attack.cpp:2298-2317) checks
`IsClient() && other->IsClient()` or `HasOwner() && GetOwner()->IsClient()`.
Companions return `false` for `IsClient()` and `nullptr` for `GetOwner()`,
so this code path is not entered. No interaction.

**Edge case: Bot leash check.** Bot.cpp:3173 checks
`tar->GetUltimateOwner()->IsOfClientBotMerc()`. If a mob is trying to
leash and the target's ultimate owner is a companion, this check would
now return true. However, companions don't have `GetUltimateOwner()`
resolving to themselves in the standard way — they return `this` from
the base `Mob::GetUltimateOwner()` which walks up the owner chain.
Since companions have no owner set via the petid system,
`GetUltimateOwner()` returns the companion itself. With
`IsOfClientBotMerc()` now returning true, this would prevent bots
from attacking companion NPCs, which is actually correct behavior
(companions should not be attacked by bots).

**Edge case: Spell `pcnpc_only_flag`**. PC-only spells
(pcnpc_only_flag == PC) will now affect companions. NPC-only spells
(pcnpc_only_flag == NPC) will no longer affect companions. This is
correct — companions are player-allied entities that should receive
PC buffs and be immune to NPC-targeted debuffs.

**Edge case: `offense()` calculation.** With `IsOfClientBotMerc()`
returning true, companions will use the PC attack power formula
(`ATK/2 + PetATKBonus) * PCAttackPowerScaling / 100`) instead of
the NPC formula. This may slightly change companion melee damage
calculations. However, since companions use NPC base damage from
npc_types and don't have significant ATK bonuses, the practical
impact is minimal.

### Pass 4: Integration

The implementation is trivial and self-contained:
- Both files can be modified independently
- No dependency ordering between the two changes
- A single build cycle tests both changes
- The fix is immediately testable by recruiting a companion and having
  it attack a mob — if the mob targets the companion, the fix works

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| c-expert | Tasks 1-3: Add overrides in companion.h, add SmartAggroList companion check in hate_list.cpp, build | Pure C++ changes in zone/ header and source |

## Validation Plan

- [ ] Recruit a companion NPC and engage it with a mob. Verify the mob
      adds the companion to its hate list and does NOT wipe it on the
      next AI tick.
- [ ] Have a companion deal melee damage to a mob. Verify the mob's
      hate list (via `#hatelist` GM command) shows the companion with
      non-zero hate.
- [ ] Recruit a warrior-class companion and have it taunt a mob. Verify
      the mob switches to attacking the companion.
- [ ] Test with multiple group members (player + companion). Verify the
      mob distributes hate correctly and will target the companion if
      it has the most hate.
- [ ] Verify companions in PASSIVE stance still disengage properly
      (existing behavior preserved).
- [ ] Verify regular NPCs still do NOT yell for help when a companion
      attacks (the `IsCompanion()` guard in `aggro.cpp:409` and
      `npc.cpp:776` must remain functional).
- [ ] Verify companion spells (heals, nukes) generate appropriate hate
      on target mobs.

---

> **Next step:** Spawn the implementation team with ONLY the agents listed
> in "Required Implementation Agents" above. Do not spawn experts without
> assigned tasks.
