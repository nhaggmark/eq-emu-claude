# Companion Rez — Architecture & Implementation Plan

> **Feature branch:** `bugfix/companion-rez`
> **PRD:** `game-designer/prd.md`
> **Author:** architect
> **Date:** 2026-04-27
> **Status:** Approved

---

## Executive Summary

The companion auto-rez subsystem **is already substantially built end-to-end**: post-combat trigger (`Companion::Process()` engaged→idle starts `m_rez_delay_timer`), AI pipeline (`Companion::AI_ResurrectDeadGroupMember` with tier preference, multi-healer coordination, and meditation), corpse marking (`Corpse::SetCompanionData` on death), companion-specific rez handler (`Companion::ResurrectFromCorpse` — auto-accept, no UI), and rule values (`Companions:RezEnabled=true`, `RezPostCombatDelayS=10`, `RezRange=200`, `RezWaiveReagents=true`). The data layer is complete: 9 Cleric rez spells are populated in `companion_spell_sets` with `spell_type=65536` (rez bitmask), and `spells_new` rows have `targettype=15` (corpse) and `effectid1=81` (Revive). Suite 29 in the C++ CLI test runner has 13 unit tests for rules / penalty / corpse metadata / AI gates.

**Triage by c-expert pinned the bug to a single guard at `eqemu/zone/spells.cpp:2051`:** `Mob::DetermineSpellTargets()` rejects `ST_Corpse` casts whose target is not `IsPlayerCorpse()`. Companion corpses fail this check, so the rez spell is canceled with `CORPSE_NOT_VALID` BEFORE reaching `SpellEffect::Revive` at `spell_effects.cpp:1707-1730` (which already correctly routes companion corpses to `Companion::ResurrectFromCorpse`). The user observes "the cleric attempts to cast but nothing happens" because the cast finishes — the spell-target validation kills it on completion.

**The fix is one logical extension to the `ST_Corpse` guard plus one small extension to `FindDeadGroupMemberCorpse` to also discover the player's corpse for AC-2.** Plus failing-first TDD coverage per AC-9. No Lua changes. No protocol changes. No DB schema changes. No new rules.

---

## Existing System Analysis

### Current State

**Rez pipeline — full path that ALREADY exists:**

```
Combat ends — engaged→idle transition
  ↓
companion.cpp:1942-1948  m_rez_delay_timer.Start(RuleI(Companions, RezPostCombatDelayS) * 1000)
  ↓ (10 seconds elapse)
companion.cpp:1952-1954  m_rez_delay_timer.Check() fires; timer disabled (consumed)
  ↓
mob_ai.cpp:1906          AIautocastspell_timer fires (in idle window: 6-60s cadence)
  ↓
companion.cpp:2245-2252  Companion::AI_IdleCastCheck() →
                         AICastSpell(GetChanceToCastBySpellType(0),
                           SpellType_Buff | SpellType_Heal | SpellType_Pet | SpellType_Resurrect)
  ↓
companion_ai.cpp:1096-1153  Companion::AI_Cleric() idle branch — Cure → Heal → Resurrect → Buff
  ↓
companion_ai.cpp:1142-1146  if (iSpellTypes & SpellType_Resurrect) {
                              if (AI_ResurrectDeadGroupMember()) return true;
                            }
  ↓
companion_ai.cpp:1927-2011  Companion::AI_ResurrectDeadGroupMember()
  ├─ RuleB(Companions, RezEnabled) check
  ├─ m_rez_delay_timer.Enabled() check (must have already fired)
  ├─ AnotherCompanionIsRezzing() check (multi-healer coordination)
  ├─ FindDeadGroupMemberCorpse() — at companion_ai.cpp:1861-1876, calls
  │   entity_list.GetCompanionCorpseByOwnerWithinRange(owner_char_id, this, RezRange)
  │   *** ONLY RETURNS COMPANION CORPSES — does not see player corpses ***
  ├─ Tier selection: ≥50% mana → SelectFirstSpell (highest); <50% mana → cheapest
  ├─ Mana check: if OOM, sit + announce meditation once, return
  └─ AIDoSpellCast(rez_spell, target_corpse, mana_cost)
       ↓
       companion.cpp:2284  Companion::AIDoSpellCast() → CastSpell(spellid, target_id, ...)
       ↓
       spells.cpp:1855-2380  Mob::DetermineSpellTargets() (called from CastSpell pipeline)
         case ST_Corpse:
       ↓
       *** spells.cpp:2051   if (!spell_target || !spell_target->IsPlayerCorpse())  ← BUG ***
       *** RETURNS FALSE; SPELL CANCELED; "CORPSE_NOT_VALID"; CAST DOES NOT FINISH ***

   The path BELOW this line is correct but unreachable today:
       ↓
       spells.cpp:SpellFinished → SpellOnTarget → ApplySpellEffects
       ↓
       spell_effects.cpp:1707-1730  case SpellEffect::Revive:
         if (IsPlayerCorpse())        → CastRezz()                            (path A)
         else if (IsCompanionCorpse()) → Companion::ResurrectFromCorpse()    (path B — bypass UI)
       ↓ (path B)
       companion.cpp:3547-3700  Companion::ResurrectFromCorpse()
         ├─ Validates IsCompanionCorpse, gets companion_id + owner_char_id
         ├─ Loads companion_data row, NPCType data, finds owner Client in zone
         ├─ Marks corpse->IsRezzed(true)
         ├─ Computes XP restore from spell base_value[0] (rez %)
         ├─ DB UPDATE: is_suspended=0, cur_hp=0, experience += xp_restore
         ├─ corpse->DepopNPCCorpse()
         ├─ Creates new Companion entity at corpse position
         ├─ Spell-spec HP (rez_pct% of max), 0 mana, BuffFadeAll
         ├─ CompanionJoinClientGroup()
         └─ CompanionGroupSay("X has been resurrected by Y.")
```

**Companion-corpse marking on death:**

```
attack.cpp:2899-2912  (NPC death path, generic for any NPC)
  entity_list.AddCorpse(corpse, GetID());
  if (IsCompanion()) {
      Companion* comp = CastToCompanion();
      corpse->ClearAllLoot();
      corpse->SetCompanionData(comp->GetCompanionID(), comp->GetOwnerCharacterID());
      corpse->SetDecayTimer(RuleI(Companions, DeathDespawnS) * 1000);  // 30 min
  }
```

**`Corpse::IsCompanionCorpse()` predicate (corpse.h:104):** `return m_companion_id > 0;` — true exactly when `SetCompanionData` was called with a non-zero companion_id, which is the case for every companion that has been Saved to DB (the companion-rerecruit guarantee).

**Player corpse rez path (existing, working):**

```
spell_effects.cpp:1714  if (IsPlayerCorpse())
  ↓
corpse.cpp:2305-2374  Corpse::CastRezz(spell_id, caster)
  ├─ CharacterCorpsesRepository::FindOne(m_corpse_db_id) — bails if !e.id
  ├─ Refresh rezzed/rezzable state from DB
  ├─ Build OP_RezzRequest (Resurrect_Struct, 228 bytes, Titanium pass-through)
  ├─ worldserver.RezzPlayer(packet, exp, dbid, OP_RezzRequest)
  ↓
worldserver.cpp:909-960  ServerOP_RezzPlayer routing to player's zone
  ↓
client_packet.cpp:13666  Handle_OP_RezzAnswer (player's zone, after they accept)
  ↓
client_process.cpp:1053  OPRezzAnswer applies rez, returns experience, restores
```

**Rez rules (live values from data-expert audit):**

| Rule | Value | Purpose |
|------|-------|---------|
| `Companions:RezEnabled` | `true` | Master toggle |
| `Companions:RezPostCombatDelayS` | `10` | Post-combat delay (answers AC-1: N=10) |
| `Companions:RezRange` | `200` | Max corpse-target distance |
| `Companions:RezWaiveReagents` | `true` | NPCs don't consume bone chips |
| `Companions:DeathDespawnS` | `1800` | Companion corpse persistence (30 min) |
| `Spells:AI_IdleBeneficialChance` | `100` | Idle NPCs always cast beneficials |
| `Spells:AI_IdleNoSpellMinRecast` | `6000` | Idle AI tick cadence min |
| `Spells:AI_IdleNoSpellMaxRecast` | `60000` | Idle AI tick cadence max |

**Cleric rez spells in `companion_spell_sets` (data-expert audit, 9 rows, `class_id=2`, `spell_type=65536`):**

| spell_id | name | min_level | base_value (XP%) | mana | cast_time | recast_time | targettype | effectid1 |
|----------|------|-----------|------------------|------|-----------|-------------|-----------|-----------|
| 2168 | Reanimation | 12 | 0% | 150 | 6s | 20s | 15 (corpse) | 81 (Revive) |
| 391 | Revive | 27 | 35% | 300 | 6s | 20s | 15 | 81 |
| 388 | Resuscitate | 37 | 60% | 500 | 6s | 20s | 15 | 81 |
| 2172 | Restoration | 42 | 75% | 600 | 6s | 20s | 15 | 81 |
| 392 | Resurrection | 47 | 90% | 700 | 6s | 20s | 15 | 81 |

(plus 4 more in-era variants: Reconstitution, Reparation, Renewal, Reviviscence.)

### Gap Analysis

| PRD Requirement | Current State | Gap |
|-----------------|---------------|-----|
| AC-1: Auto-rez NPC companion within N seconds | `m_rez_delay_timer` exists, fires at 10s; AICastSpell idle cadence 6-60s after | **None for trigger; effective wall-clock is 10s + idle-tick (worst case ~70s)** |
| AC-2: Auto-rez player when down | `FindDeadGroupMemberCorpse` only scans companion corpses | **GAP — extend to also find owner's player corpse** |
| AC-3: Rez "takes" on NPC companion | `Companion::ResurrectFromCorpse` is wired, but the spell never reaches `SpellEffect::Revive` because of `spells.cpp:2051` | **GAP — extend `ST_Corpse` guard to allow companion corpses** |
| AC-4: Player rez window for player targets | `Corpse::CastRezz` → `OP_RezzRequest` → Titanium dialog (existing; bot precedent works) | None |
| AC-5: Higher-tier rez preferred when affordable | `AI_ResurrectDeadGroupMember` already implements ≥50% mana → highest, <50% → cheapest | None — policy decision documented below |
| AC-6: Multi-target sequencing | Each AI tick finds one corpse; recast timer (20s) sequences naturally | None — first-found ordering, documented below |
| AC-7: OOM / OOC graceful behavior | Mana check + sit-to-meditate + one-time announcement | None |
| AC-8: No mid-combat rez initiation | Only called from `AI_IdleCastCheck`; the engaged branch of `AI_Cleric` does not call rez | None |
| AC-9: TDD discipline | Suite 29 (13 tests) exists; 4 new failing-first tests needed | **GAP — write 4 new tests covering BUG-001 regression** |
| AC-10: Reliability — every prereq-met rez succeeds | After fix, all gates upstream of `SpellEffect::Revive` pass for companion corpses | Closed by the same fix |

**Three concrete gaps:**

1. **`spells.cpp:2051`** — `ST_Corpse` validation does not admit companion corpses. **Root cause of BUG-001's primary symptom.** One-line code addition.
2. **`companion_ai.cpp:1861-1876`** — `FindDeadGroupMemberCorpse()` only scans companion corpses. AC-2 requires also scanning the owner's player corpse via `GetCorpseByOwnerWithinRange()` (which exists at `entity.cpp:2039-2050`).
3. **TDD coverage** — Suite 29 already has 13 tests; 4 new tests required to nail the regression (failing pre-fix, passing post-fix) per AC-9.

**No other gaps.** No Lua changes. No protocol changes. No DB schema changes. No new rules.

---

## Technical Approach

### Architecture Decision

Least-invasive-first applied:

| Layer | Considered? | Decision | Rationale |
|-------|-------------|----------|-----------|
| Rule values | Yes | **No change** | All four `Companions:Rez*` rules already exist in DB with sane values. No rule could explain a "cast goes off but nothing happens" symptom (config-expert verified). |
| Server config | Yes | **No change** | No companion-rez settings in `eqemu_config.json` or `.env`. |
| Lua scripts | Yes | **No change** | lua-expert audit: no rez-related Lua hooks anywhere; all logic is C++. The C++ pipeline does not call back into Lua for the rez decision. |
| SQL data | Yes | **No change** | `companion_spell_sets` already has the 9 Cleric rez spells; `spells_new` rows are well-formed; `companion_data` death state is correct. |
| C++ source | Yes | **One logical change to `spells.cpp:2051` + one extension to `FindDeadGroupMemberCorpse`** | The bug is here. The pipeline's correctness ends abruptly at one validation gate. |

The architecture is decisively **C++-only** — and the C++ surface is two short, narrowly-scoped functions.

### Data Model

**No schema changes.** Existing tables already support the invariant:

- `companion_data` — `is_suspended=1` is the death-state flag; `is_dismissed=0` distinguishes a death-suspended row from a soft-dismissed one. Set by `Companion::Death()` (companion.cpp:683/669-680). Not touched by this fix.
- `companion_spell_sets` — `spell_type=65536` is the rez bitmask matching `SpellType_Resurrect` in C++. 9 rows for class_id=2 cover the in-era Cleric progression. Not touched by this fix.
- `spells_new` — rez spells have `targettype=15` (`ST_Corpse`), `effectid1=81` (`SpellEffect::Revive`), `effect_base_value1` = XP restore percentage. Not touched.
- `rule_values` — All four `Companions:Rez*` rules and `Companions:DeathDespawnS` already populated. Not touched.

**No data buckets used by the rez subsystem.** No schema migration. No DB writes added.

### Code Changes

#### C++ Changes

All in `eqemu/zone/`. Two narrowly-scoped edits and one new test suite extension.

**1. `eqemu/zone/spells.cpp` — Extend `ST_Corpse` validation to admit companion corpses (THE bug fix).**

Located in `Mob::DetermineSpellTargets` at `spells.cpp:1855-2380`. Current `ST_Corpse` case at lines 2049-2063 rejects non-player-corpse targets:

```cpp
// Current (broken):
case ST_Corpse:
{
    if(!spell_target || !spell_target->IsPlayerCorpse())
    {
        LogSpells("Spell [{}] canceled: invalid target (corpse)", spell_id);
        uint32 message = ONLY_ON_CORPSES;
        if(!spell_target) message = SPELL_NEED_TAR;
        else if(!spell_target->IsCorpse()) message = ONLY_ON_CORPSES;
        else if(!spell_target->IsPlayerCorpse()) message = CORPSE_NOT_VALID;
        MessageString(Chat::Red, message);
        return false;
    }
    CastAction = SingleTarget;
    break;
}
```

```cpp
// Fixed — admit companion corpses alongside player corpses:
case ST_Corpse:
{
    bool is_player_corpse    = spell_target && spell_target->IsCorpse() &&
                               spell_target->CastToCorpse()->IsPlayerCorpse();
    bool is_companion_corpse = spell_target && spell_target->IsCorpse() &&
                               spell_target->CastToCorpse()->IsCompanionCorpse();
    if(!spell_target || (!is_player_corpse && !is_companion_corpse))
    {
        LogSpells("Spell [{}] canceled: invalid target (corpse)", spell_id);
        uint32 message = ONLY_ON_CORPSES;
        if(!spell_target) message = SPELL_NEED_TAR;
        else if(!spell_target->IsCorpse()) message = ONLY_ON_CORPSES;
        else if(!is_player_corpse && !is_companion_corpse) message = CORPSE_NOT_VALID;
        MessageString(Chat::Red, message);
        return false;
    }
    CastAction = SingleTarget;
    break;
}
```

The c-expert exact-form sketch (single-line OR addition) is logically equivalent; the engineer chooses the cleaner form during implementation. The code reaches `Corpse::CastToCorpse()->IsCompanionCorpse()` via `spell_target->IsCorpse()` first (already a check earlier in the function block at line 2056), so a defensive `IsCorpse()` guard before `CastToCorpse()` keeps it safe.

The downstream `SpellEffect::Revive` handler at `spell_effects.cpp:1707-1730` correctly branches on `IsPlayerCorpse()` vs `IsCompanionCorpse()` — no change needed there.

**2. `eqemu/zone/companion_ai.cpp` — Extend `FindDeadGroupMemberCorpse` to discover the owner's player corpse (AC-2).**

Current implementation at `companion_ai.cpp:1861-1876` only checks companion corpses. Replace the body so the function returns either the closest companion corpse OR the owner's player corpse, with a documented selection rule.

```cpp
// Fixed — also consider the owner's player corpse:
Corpse* Companion::FindDeadGroupMemberCorpse()
{
    Client* owner = GetCompanionOwner();
    if (!owner) {
        return nullptr;
    }

    int rez_range = RuleI(Companions, RezRange);

    // Priority 1: the owner's player corpse if in range and not yet rezzed.
    // Player rez is highest priority (the player can't keep playing without it,
    // and a downed player is more disruptive than a downed companion).
    Corpse* player_corpse = entity_list.GetCorpseByOwnerWithinRange(owner, this, rez_range * rez_range);
    if (player_corpse && !player_corpse->IsRezzed()) {
        return player_corpse;
    }

    // Priority 2: closest companion corpse owned by this owner.
    return entity_list.GetCompanionCorpseByOwnerWithinRange(
        owner->CharacterID(), this, rez_range);
}
```

Notes:
- `EntityList::GetCorpseByOwnerWithinRange(Client*, Mob*, range)` already exists at `entity.cpp:2039-2050`, filters by `IsPlayerCorpse()` and matches owner by name.
- The `range * range` argument matches that function's distance comparison (it uses raw squared distance against the unsquared `range` argument — verify during implementation; the engineer confirms which form is correct and matches calling convention).
- `IsRezzed()` guard prevents re-targeting a corpse that's already had a rez applied this cycle.
- The companion corpse path remains the existing `GetCompanionCorpseByOwnerWithinRange` which already filters by `IsRezzed`.

**3. `eqemu/zone/cli/tests/cli_companion_tests.cpp` — Add 4 failing-first tests to Suite 29 (TDD per AC-9).**

Suite 29 starts at line 6494. Add at the end (before `--- Suite 29 Complete ---` at line 6764):

| Test | Description | Pre-fix behavior | Post-fix behavior |
|------|-------------|------------------|-------------------|
| 29.14 | `DetermineSpellTargets` accepts a companion corpse for `ST_Corpse` rez spell | FAILS — returns false (CORPSE_NOT_VALID) | PASSES — returns true, CastAction=SingleTarget |
| 29.15 | `Companion::ResurrectFromCorpse` is reachable end-to-end via cast pipeline (synthesize a Cleric companion + dead companion corpse, dispatch a rez spell, observe the corpse is depopped and a fresh Companion is in entity_list) | FAILS — corpse persists, no new companion entity | PASSES |
| 29.16 | `FindDeadGroupMemberCorpse` returns the owner's player corpse when present (mock a player corpse near the cleric, owner relationship correct) | FAILS — returns nullptr | PASSES |
| 29.17 | Rez attempt on companion corpse via `AIDoSpellCast` does NOT emit `CORPSE_NOT_VALID`; spell finishes successfully (regression guard for spells.cpp:2051) | FAILS — message string emitted, cast canceled | PASSES |

Test pattern follows existing Suite 29 conventions (uses `CreateTestCompanionByClass`, `RunTest`, `RunTestNull`, `SkipTest` helpers already defined in the file).

The c-expert dev-notes file (`claude/project-work/companion-rez/c-expert/dev-notes.md`) is the ground-truth implementation reference for engineers picking up these tasks.

#### Lua/Script Changes

**None.** lua-expert audit confirmed no rez logic in companion.lua, global_npc.lua, companion_culture.lua (the LLM "resurrection" event_type stub is presentation-only and doesn't gate rez logic). The `companion-rerecruit` death-state semantics (`is_suspended=1` row preserved) still hold; no Lua change broke this. No `make test-companion` extension required for this fix.

#### Database Changes

**None.** No schema migrations. No new rule_values. No data inserts. No table changes.

#### Configuration Changes

**None.** No `eqemu_config.json` or `.env` changes. All four `Companions:Rez*` rules and `Companions:DeathDespawnS` already exist with correct values.

---

## Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | Write 4 failing tests in Suite 29 of `eqemu/zone/cli/tests/cli_companion_tests.cpp` (29.14, 29.15, 29.16, 29.17) per the test table above. Build the test binary inside the akk-stack container (`docker exec akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`). Run via `./bin/zone tests:companion` and verify the 4 new tests fail today. | c-expert | — | ~120 lines C++ test code |
| 2 | Implement the `ST_Corpse` extension at `eqemu/zone/spells.cpp:2049-2063`. Follow the c-expert dev-notes form. Keep the existing `MessageString` paths for non-corpse / non-player-non-companion targets unchanged. | c-expert | 1 | ~6 lines C++ |
| 3 | Implement the `FindDeadGroupMemberCorpse` extension at `eqemu/zone/companion_ai.cpp:1861-1876`. Player corpse priority FIRST, then companion corpse. Use existing `EntityList::GetCorpseByOwnerWithinRange` for the player corpse path. | c-expert | 1 | ~10 lines C++ |
| 4 | Rebuild the zone binary inside the container (`ninja -j$(nproc)`). Re-run `./bin/zone tests:companion` and verify ALL 4 new tests now PASS, and the existing 13 Suite 29 tests still PASS. Run the full companion test suite to confirm no regression. | c-expert | 2, 3 | runtime |
| 5 | `make restart` from akk-stack/, then full server start (loginserver / world / 8 dynamic_NN zones per the documented startup procedure). | infra-expert | 4 | runtime |
| 6 | In-game validation per Validation Plan below. game-tester runs the 7 required scenarios. User confirms. | game-tester | 5 | manual |
| 7 | Commit and push all changes on `bugfix/companion-rez` in eqemu and claude repos. (akk-stack and spire have no changes for this fix.) | c-expert | 4 | git |

**Dependency graph:**

```
1 (failing tests) ──→ 2 (spells.cpp fix) ──┐
                       └─→ 3 (corpse search ext) ──→ 4 (rebuild + verify) ──→ 5 (restart) ──→ 6 (validate) ──→ 7 (commit)
```

Tasks 2 and 3 are independent of each other; both depend on task 1 (the failing tests written first per AC-9), and both feed task 4 (the post-fix verification). The TDD ordering guarantee: task 1 demonstrates the bug machine-verifiably before any production code is touched.

---

## Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| c-expert | 1, 2, 3, 4, 7 | All C++ source and CLI test runner work. Owns `spells.cpp`, `companion_ai.cpp`, `cli_companion_tests.cpp`. Engineer also commits and pushes the changes. |
| infra-expert | 5 | Server restart and full-stack startup per the documented procedure (loginserver / world / 8 dynamic zones). Ensures the player can repro tests in-game. |
| game-tester | 6 | In-game validation of the 7 required scenarios before user sign-off. |

**Not needed:** lua-expert (no Lua changes), data-expert (no DB changes), config-expert (no rule changes), perl-expert (no Perl involved), protocol-agent (no client packet changes).

---

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Other `ST_Corpse` spells (`SummonToCorpse`, etc.) become unexpectedly castable on companion corpses | Low | Low | `spell_effects.cpp:1707` already handles `SummonToCorpse` in the same case as `Revive`. There is no per-spell whitelist gating companion corpses; `IsCompanionCorpse()` allowing the cast through validates only the *target* is a corpse — the EFFECT branch still discriminates. Summon-to-corpse on a companion corpse would attempt to summon a corpse to the caster's location, which is benign for companion corpses (they're not part of the loot economy). c-expert reviewed this and confirmed no regression risk. |
| Player accidentally targets companion corpse with `/cast Resurrection` and the rez fires unexpectedly | Low | Low | Player-cast rez on a companion corpse now reaches `Companion::ResurrectFromCorpse` and… **succeeds**. This is consistent with the PRD's intent (player can manually rez their companion). The PRD's "Non-Goals" section excludes a `!rez` *companion command*, but a player using their own Cleric character to rez their companion is a natural emergent use case and is fine. If the player is NOT the companion's owner, `Companion::ResurrectFromCorpse` at `companion.cpp:3578-3584` returns early (owner not in zone or not the casting client's owner), so cross-character griefing is prevented by existing logic. |
| Player's rez prompt receives an NPC name as `rezzer_name` (looks weird in dialog) | Low | Cosmetic | `Corpse::CastRezz` populates `rezzer_name` from `caster->GetName()`. For a Cleric companion this is the entity name like `Hollish_Tnoops00`. Bot precedent (botspellsai.cpp) uses bot names which look fine to players. Companion entity names follow the same convention (clean name with index suffix). Acceptable. If polish is desired in a future pass, `caster->GetCleanName()` could be used instead. |
| Mid-combat rez initiation (AC-8 violation) | Very Low | Medium | `AI_ResurrectDeadGroupMember` is only called from idle branches of class AI handlers (`AI_Cleric` line 1142, `AI_Paladin` line 1028, `AI_Necromancer` line 1682). The engaged branches do NOT call rez. AC-8 already holds — verified by c-expert in dev-notes. The `m_rez_delay_timer` adds a 10s post-combat settling buffer on top. |
| Multi-target sequencing breaks (AC-6) | Low | Low | Each AI tick finds ONE corpse via `FindDeadGroupMemberCorpse`. After a rez completes, the corpse is depopped (or `IsRezzed(true)`), so the next AI tick finds the next-closest corpse. The 20-second recast timer on rez spells naturally sequences attempts. Player-corpse-first priority is now explicit (architect decision below). |
| Race condition: corpse rezzed twice | Very Low | Low | `Companion::ResurrectFromCorpse` calls `corpse->IsRezzed(true)` BEFORE `DepopNPCCorpse` and BEFORE creating the new entity. `FindDeadGroupMemberCorpse` skips rezzed corpses (`GetCompanionCorpseByOwnerWithinRange` checks `IsRezzed()` at entity.cpp:2059). `AnotherCompanionIsRezzing()` provides multi-healer coordination. |
| Rez applied while corpse is being looted | Very Low | Low | NPC corpses have loot-cooldown logic. Companion corpses are stripped of loot at death (`corpse->ClearAllLoot()` at attack.cpp:2907), so loot-state issues are absent. |
| Server crash during `Companion::ResurrectFromCorpse` mid-DB-update | Low | Low | The DB UPDATE happens BEFORE the new entity is created (companion.cpp:3621-3624). If the server crashes after the UPDATE but before entity spawn, the companion is marked active in DB but not in zone — the player can `!unsuspend` or wait for next zone re-load. If the crash happens before the UPDATE, the corpse persists and another rez attempt can complete. Architecture decision documented in companion.cpp:3617-3620. |
| `FindDeadGroupMemberCorpse` returning the wrong player corpse if multiple players in zone share a name | Very Low | Low | `GetCorpseByOwnerWithinRange` matches owner by character name (`strcasecmp`) AND by range from the cleric. Since EQ enforces unique character names per server, the match is unambiguous. |

### Compatibility Risks

- **Charm pets, swarm pets, mercenaries:** Untouched. None of these have `m_companion_id > 0` (only Companions get `SetCompanionData` called at `attack.cpp:2908`). They still fail the `ST_Corpse` guard exactly as today. No regression.
- **Bots:** Independent system. `Bot::CastSpell` overrides at `bot.cpp:11457` already restrict rez to player corpses; bots and companions share the underlying spell pipeline, but the bot-specific override gates rez differently than companions. No interaction; no regression.
- **Existing companion data:** No migration. `is_suspended=1` rows continue to behave per companion-rerecruit semantics. The fix is additive — companions that were previously dead stay dead until a rez is cast (or `DeathDespawnS` expires).
- **Suite 29 existing 13 tests:** Pre-fix the existing tests cover rules, XP penalty, and corpse metadata — none of which are touched by this fix. They continue to pass.

### Performance Risks

None of the changes touch hot paths.

- **`spells.cpp:2051` extension:** Adds two `IsCorpse()` + accessor checks per cast; negligible (~3 ns) and only on `ST_Corpse` spells (rare).
- **`FindDeadGroupMemberCorpse` extension:** One additional call to `GetCorpseByOwnerWithinRange` per cleric AI tick; the function iterates the zone's corpse list (O(corpses) ~20-50 in typical zones) and runs only when the cleric is idle and the post-combat timer has fired. Already well within the existing AI budget.
- **No new DB queries.** No new packet emissions. No new memory allocations.

---

## Review Passes

### Pass 1: Feasibility

**Can we actually build this with the existing codebase?**

Trivially. Two narrowly-scoped C++ changes (~16 lines combined) plus 4 new tests in an existing test file (~120 lines). Standard Docker-exec rebuild via `ninja -j$(nproc)`. Existing CLI test runner (`./bin/zone tests:companion`) provides immediate feedback.

The hardest part is verifying the player-corpse path's range-comparison convention in `EntityList::GetCorpseByOwnerWithinRange` (one inspection during task 3). c-expert's dev-notes and the in-tree call sites at `client.cpp:7204` and `client_packet.cpp:5487` provide the convention to mirror.

**Protocol-agent consultation:** Confirmed no Titanium-client constraints. `OP_RezzRequest` / `OP_RezzAnswer` / `OP_RezzComplete` are pass-through (no `E()`/`D()` entry in `titanium_ops.h`). The companion bypass path emits zero rez-specific opcodes. The bot precedent (`botspellsai.cpp:204`, `bot.cpp:11457`) confirms NPC casters rezzing player corpses works in production.

**Config-expert consultation:** Confirmed no rule could explain the bug; rules are clean and pre-set. Architect's intent to keep `RezPostCombatDelayS=10` (AC-1 N=10) and hardcode tier / ordering policies is endorsed.

**Data-expert consultation:** Confirmed the data layer is complete. `companion_spell_sets` has the 9 Cleric rez spells; `spells_new` rows are well-formed; `companion_data` death state is correct.

### Pass 2: Simplicity

**Is this the simplest approach?**

Yes. The implementation surface is the smallest possible:
- 1 logical extension to a single validation guard (`spells.cpp:2051`)
- 1 small extension to a single helper method (`FindDeadGroupMemberCorpse`)
- 4 TDD tests (mandatory per AC-9)

**Considered and rejected:**

- A new `Companions:AutoRezTierPreference` rule — the existing C++ policy (≥50% mana → highest, <50% → cheapest) is a sensible default, and adding a rule expands the misconfiguration surface without benefit. Hardcoded.
- A new `Companions:RezPlayerFirst` rule — same logic. Player-first ordering is a clear UX win and fits the PRD's "rezzes one, then the next" framing. Hardcoded.
- A separate `EntityList::GetGroupMemberCorpseByOwnerWithinRange` that combines player + companion in one call — premature abstraction. Two existing methods called sequentially in `FindDeadGroupMemberCorpse` is shorter and reads more clearly.
- A Lua-side trigger via `event_combat(e.joined=false)` — unnecessary; C++ already handles this with `m_rez_delay_timer`. Adding Lua duplicates the trigger and adds two failure modes.
- Additional `Spells:AI_*` rule tuning to reduce idle-tick latency for rez — current 10s post-combat delay + 6-60s idle cadence is acceptable per PRD AC-1 ("small enough to feel responsive, large enough to confirm combat is genuinely over"). Tightening would require deeper AI-loop changes.

### Pass 3: Antagonistic

**What could go wrong?**

- **Edge case: companion corpse despawns mid-cast.** `Companion::ResurrectFromCorpse` is called from `SpellEffect::Revive` which runs inside `SpellOnTarget`. If the corpse despawns between cast initiation and effect application, `spell_target` becomes invalid. Mitigation: `SpellOnTarget` already validates the target before applying effects (existing engine-level check). If the corpse is gone, the spell completes with no effect — same as a player corpse despawning during a player-Cleric rez attempt. Acceptable.

- **Edge case: target acquisition during cast.** `AIDoSpellCast` passes `target_corpse` as the entity ID. If the corpse depops mid-cast, the entity ID becomes stale. The same engine-level check at `SpellOnTarget` handles this. No special-case needed.

- **Edge case: Cleric rezzes a companion in a different zone.** Owner-not-in-zone guard at `companion.cpp:3578-3584` prevents this. The cleric and the corpse are co-located in the same zone (the cleric just fought there), so this is impossible by physical positioning, but the guard is defensive.

- **Player exploit: dismiss + recruit + die + auto-rez to "reset" the death penalty.** Auto-rez restores `effect_base_value1` percent of the deducted XP (e.g., 90% for Resurrection). The penalty deduction (`Companions:XPDeathPenaltyPct`, default 10%) was already applied at death. Net XP change: -10% × (1 - 0.9) = -1% per death-rez cycle. That's a real cost; the player isn't getting "free" recoveries. No exploit.

- **Player exploit: kill companion in safe area to drop equipment, then auto-rez to restore.** `RuleB(Companions, EquipmentPersistsThroughDeath)` is true by default — equipment is preserved on death. No drop happens. Even if the rule were false, the equipment goes back to the owner (companion.cpp:631-646), not to the corpse. No exploit.

- **Race: two clerics in the party rez the same corpse simultaneously.** `AnotherCompanionIsRezzing` (companion_ai.cpp:1884-1906) checks if any other companion is currently casting a `SpellType_Resurrect` spell and bails. Single-cleric scenarios get false; multi-cleric scenarios are gracefully serialized. The PRD's small-group context (1-3 players) typically has 1 cleric, so this rarely matters but is correctly handled.

- **Race: player kills the companion's corpse before the rez completes.** Companion corpses are no-loot (cleared at death) and players cannot `#kill` corpses through normal means. GM `#kill` could destroy a corpse mid-rez; `IsRezzed(true)` is set early in `ResurrectFromCorpse` so a concurrent `Depop` is benign. Not a real-game concern.

- **Performance: 1000 companion corpses + 1 cleric.** `MaxPerPlayer=5` caps companions per player; `DeathDespawnS=1800` caps corpse persistence at 30 min. Realistic upper bound: ~5 corpses in a zone at any time. `FindDeadGroupMemberCorpse` iterates `corpse_list` — typically 20-50 items. Negligible.

- **Backward compat: existing companion corpses left over from before the fix lands.** Companion corpses are zone-memory only (no DB persistence). On `make restart` they vanish. After the fix lands and the zone restarts, future companion corpses become rezzable. No migration needed.

- **What if `RezEnabled=false`?** `AI_ResurrectDeadGroupMember` returns false at the first check; no rez is attempted; behavior reverts to the pre-feature null state (corpse stays down until despawn). Master toggle works.

- **What if `RezPostCombatDelayS` is set negative or huge?** Negative becomes effectively zero (timer fires immediately on engaged→idle). Huge values delay rez indefinitely. Both are graceful; no crash. config-expert flagged that one rule (`Spells:AI_IdleNoSpellMaxRecast=60000ms`) could in theory delay the rez attempt by up to 60s on top of the post-combat delay. This is acceptable in the PRD framing ("a small window, ~10 seconds").

**Protocol-level edge cases (protocol-agent consult):** None. No new packets emitted. Bot precedent confirms NPC-cast rez-on-player-corpse is production-tested.

**Rule-value boundary conditions (config-expert consult):** All four `Companions:Rez*` rules are sensibly bounded; misconfiguration would cause graceful degradation, not the observed bug.

**DB boundary conditions (data-expert consult):** No DB writes added; existing read-only access paths (companion_data lookup, companion_spell_sets selection) are stable and unchanged.

### Pass 4: Integration

**How do the pieces fit together?**

The dependency graph is short and linear with two parallel branches at task 1:

```
1 (4 failing tests written first per AC-9)
  ├──→ 2 (spells.cpp:2051 extension)
  └──→ 3 (companion_ai.cpp:1861 player-corpse-first extension)
         ↓
       4 (rebuild + verify all tests pass)
         ↓
       5 (server restart by infra-expert)
         ↓
       6 (game-tester scenarios + user sign-off)
         ↓
       7 (commit + push)
```

**Ordering matters:**
- Tests MUST be written before fixes (AC-9 TDD discipline; same as companion-rerecruit).
- Tasks 2 and 3 are independent — they can be done in either order or simultaneously.
- The rebuild MUST happen inside the akk-stack container (vcpkg-based environment).
- Server restart MUST follow the documented full-stack procedure (Docker containers + 8 dynamic zones), per project memory's Server Startup Order rules.
- game-tester runs after a clean restart, not before.
- Commit happens after all tests pass and game-tester reports PASS.

**No circular dependencies. No missing prerequisites. Each engineer has the file:line citations needed.**

**Cross-cutting integration with prior `companion-rerecruit` fix:** The death-state semantic (`is_suspended=1` row preserved) is exactly what `Companion::ResurrectFromCorpse` reads at `companion.cpp:3563-3567`. The companion-rerecruit fix is a hard prerequisite for this rez fix — without `is_suspended=1` set on death, `ResurrectFromCorpse` would have no row to find. companion-rerecruit is already merged; this fix builds on its foundations cleanly.

---

## Resolved PRD Open Questions

The PRD's status.md tracks 6 architect-domain open questions (Q5 was already resolved by lore-master). Resolutions:

### Q1 — Post-combat delay N (RuleI Companions:RezPostCombatDelayS)

**Resolution: N = 10 seconds.** This is the existing default in `common/ruletypes.h:1251` and the live `rule_values` row. data-expert audited and confirmed the value is set in the live DB. It satisfies the PRD requirement: small enough to feel responsive (player isn't waiting forever), large enough to confirm combat is genuinely over (no in-flight aggro from a fleeing mob's friend).

**Note:** Effective wall-clock latency is `RezPostCombatDelayS` + AI tick cadence (`Spells:AI_IdleNoSpellMin/MaxRecast` = 6-60s in idle). Worst case: ~70s. This is acceptable per PRD framing; if real-world UX feedback demands tighter, a future polish pass could trigger an immediate `AICastSpell` call from `m_rez_delay_timer.Check()` consumption to short-circuit the idle wait. Out of scope for this fix.

### Q2 — NPC corpse rez confirmation gap (BUG-001 hypothesis)

**Resolution: User hypothesis CONFIRMED but the bypass is ALREADY IN PLACE.**

protocol-agent and c-expert independently verified: `spell_effects.cpp:1707-1730` already routes companion corpses to `Companion::ResurrectFromCorpse` (server-side direct rez, no UI dialog). The reason the rez "doesn't take" today is NOT the UI gap — it's the upstream `ST_Corpse` validation at `spells.cpp:2051` rejecting non-player corpses BEFORE the spell can finish. The fix is to extend the validation to admit companion corpses (the existing downstream branch at `spell_effects.cpp:1720` then handles the rez application correctly).

This rejects the implicit assumption that we need to "add" auto-accept logic. The auto-accept path exists; we just need to let the spell reach it.

### Q3 — Rez tier preference policy

**Resolution: Existing policy at `companion_ai.cpp:1962-1981` retained.**

When mana ≥ 50%: select the highest-tier rez (`SelectFirstSpell`, which iterates by slot priority). When mana < 50%: select the cheapest rez (`GetSpellsForType` then `min by spells[id].mana`). Rationale:
- Healthy mana → spend on the best available rez (90% Resurrection > 35% Revive). Maximizes XP returned to the target.
- Low mana → spend on the cheapest viable rez to maximize the chance of *something* getting rezzed instead of nothing. Falls through to AC-7 OOM behavior if even the cheapest is unaffordable.

This is implemented and correct. No change. Policy is hardcoded (no rule), per architect+config-expert agreement.

### Q4 — Multi-target ordering policy

**Resolution: Player corpse first, then closest companion corpse, sequenced by recast timer (20s).**

Rationale:
- Player rez is highest priority — the player can't keep playing without it. The companion can wait 20s for the next rez cycle.
- After the player is rezzed (or no player corpse exists), the next AI tick finds the closest companion corpse via the existing logic.
- Sequencing is automatic via the rez-spell recast timer (20s per the data-expert spell audit) — the cleric can't spam rezzes faster than once per 20s anyway.

Implemented as the priority-1 path in the new `FindDeadGroupMemberCorpse` body (see Code Changes #2). Hardcoded.

### Q5 — Cleric OOM flavor message

**RESOLVED 2026-04-27 by lore-master:** silent (no chat output). Existing `AI_ResurrectDeadGroupMember` already does the right thing — `m_rez_meditation_announced` ensures the meditation announcement fires only ONCE per OOM episode, and recovers silently when mana is restored. No change needed.

### Q6 — Quest-NPC rez interaction

**Resolution: NO special handling.** Per the PRD's awareness flag (not a scope expansion). If a recruited NPC is also a kill-target / quest-state node, the rez succeeds and the player can subsequently kill the NPC again to satisfy the quest objective. This matches the documented behavior of charm pets and other befriended quest targets in vanilla EQ.

If a quest designer wants to gate auto-rez on quest state in the future, they can add a per-NPC `companion_exclusions` row of type 0 (manual lore-anchor exclusion) — but even then, an already-recruited companion's corpse still rezzes because the exclusion check happens at recruitment time, not at rez time. No code path change needed.

### Q7 — TDD test scope mapping (PRD Validation Plan to test types)

**Resolution:** The mapping below; one of the smaller test sets in this project's history because the existing scaffolding does most of the heavy lifting.

| Validation Plan Scenario | Test Type | Owner | Notes |
|--------------------------|-----------|-------|-------|
| 1. Single companion down → rezzed within N seconds | Game-tester (live) | game-tester | The "happy path" smoke test. |
| 2. Player down → standard EQ rez prompt | Game-tester (live) | game-tester | Requires Titanium client to render the dialog. AC-2 / AC-4 coverage. |
| 3. Multi-target sequenced rez | Game-tester (live) | game-tester | AC-6 + Q4 ordering verification. |
| 4. Cleric OOM → no spam, recovers | Game-tester (live) | game-tester | AC-7. AnotherCompanionIsRezzing + meditation already cover code path; live verifies UX. |
| 5. Cleric down (no rezzer) → graceful no-op | Game-tester (live) | game-tester | AC-7 graceful path. |
| 6. Back-to-back fights (in-flight rez) | Game-tester (live) | game-tester | AC-8 mid-combat-init guard. |
| 7. Party member dies during rez cast | Game-tester (live) | game-tester | Edge case verification. |
| 8. Higher-tier rez preferred when affordable | Suite 29 unit test | c-expert | AC-5 — write a unit test asserting `SelectFirstSpell` returns `392` (Resurrection) when mana ≥50% and 392/391 are both available. (Optional addition to Suite 29 if engineer wants it; not in the required 4 above.) |
| 9. Tier fallback on insufficient mana | Suite 29 unit test | c-expert | AC-5 fallback — same as above with mana <50%. (Optional.) |
| 10. NPC companion rez actually "takes" — BUG-001 reproduction | Suite 29 unit test 29.15 + game-tester regression | c-expert + game-tester | Primary regression guard. Test 29.15 covers the cast path; game-tester confirms in-game. |
| 11. No mid-combat initiation | Game-tester (live) | game-tester | AC-8 — verify by entering combat with a downed companion and observing the cleric does NOT begin rezzing. |
| 12. Range / LoS failure → graceful skip | Game-tester (live) | game-tester | RezRange=200 enforcement. |

**Required Suite 29 additions (failing-first per AC-9):** 29.14, 29.15, 29.16, 29.17 (per Code Changes #3 above).

**Optional Suite 29 additions (nice-to-have):** Tier preference and fallback unit tests for AC-5 (scenarios 8 and 9). Engineer may add during implementation if it doesn't expand scope.

The bulk of game-tester scenarios are live in-game verification, which is appropriate for a UX-sensitive feature like auto-rez. The unit tests guard the regression and the new player-corpse search.

---

## Validation Plan

### What game-tester should verify (post-implementation)

1. **AC-3 / Scenario 1 (NPC companion rez "takes"):** Engage a fight in a Classic-Luclin zone (e.g., Najena, Lake of Ill Omen). Have a Cleric NPC companion + Warrior NPC companion + player. Ensure the Warrior dies during the fight. Win the fight. Wait ~10-15 seconds. Cleric should cast a rez spell on the Warrior corpse, the corpse depops, and the Warrior reappears at the corpse position with HP at the rez spell's percentage of max, 0 mana, no buffs, in the active group. **PRIMARY REGRESSION TEST.**

2. **AC-2 / Scenario 2 (player rez prompt):** Same setup as above, but player dies on the final blow of the fight. Pet/DoT/companion finishes the mob. Cleric should target the player corpse, cast rez. Player sees the standard EQ rez prompt with the cleric companion's name as `rezzer_name`. Player accepts; standard rez behavior follows.

3. **AC-6 / Scenario 3 (multi-target sequenced):** Have player + Cleric + Warrior + Wizard. Bad pull wipes everyone except the cleric (who finishes via stun-chain or low-level adds dying to remaining DoTs). Verify cleric rezzes player FIRST (priority-1 player-corpse path), then closest companion corpse, then next, separated by ~20s recast timer. AC-6 + Q4 ordering verification.

4. **AC-7 / Scenario 4 (OOM recovery):** Engineer the cleric to be at low mana post-combat. Cleric casts one rez, runs OOM. Verify: no error spam in chat or logs, cleric sits to meditate (one announcement), waits, then resumes rezzing remaining corpses when mana is sufficient.

5. **AC-7 / Scenario 5 (Cleric down — graceful no-op):** Cleric dies during fight. Fight ends with player + non-cleric companion finishing. Verify: no auto-rez, no error spam, no surprise side effects. Player handles recovery via existing systems.

6. **AC-8 / Scenario 6 (back-to-back fights):** Pull fight #1, Warrior dies, fight #1 ends, cleric begins rez. Player pulls fight #2 mid-cast. The in-flight rez on the now-still-dead Warrior should complete (PRD Scenario F). After fight #2 begins, the cleric should NOT initiate new rez attempts until fight #2 ends (AC-8).

7. **AC-10 / Scenario 12 (range / LoS):** Position the cleric outside `RezRange=200` of the corpse. Verify: cleric does not attempt to cast (no message spam). Move the cleric within range. Verify: cleric attempts and succeeds. (`AI_ResurrectDeadGroupMember` returns false when `FindDeadGroupMemberCorpse` returns nullptr.)

### Engineer-side validation (pre-implementation)

Before declaring task 4 complete, c-expert MUST verify:

- All 4 new tests in Suite 29 (29.14, 29.15, 29.16, 29.17) PASS
- All 13 existing Suite 29 tests still PASS
- Full companion test runner output exits cleanly with status 0
- Build artifacts in `eqemu/build/bin/` are fresh (timestamp post-build)
- No new compiler warnings introduced
- No `LogSpells` errors when running the rez tests

### Acceptance criteria coverage

| AC | Validation method | Owner |
|----|-------------------|-------|
| AC-1 (rez within N=10s post-combat) | Game-tester scenario 1 + 2 + 3 timing observation | game-tester |
| AC-2 (auto-rez player when down) | Game-tester scenario 2 | game-tester |
| AC-3 (rez "takes" on NPC companion) | Test 29.15 + game-tester scenario 1 | c-expert + game-tester |
| AC-4 (player rez window appears) | Game-tester scenario 2 | game-tester |
| AC-5 (higher-tier rez preferred) | Optional unit tests + game-tester observation | c-expert + game-tester |
| AC-6 (multi-target sequencing) | Game-tester scenario 3 | game-tester |
| AC-7 (OOM / OOC graceful) | Game-tester scenarios 4 + 5 | game-tester |
| AC-8 (no mid-combat init) | Game-tester scenario 6 + idle-only call site verified | game-tester |
| AC-9 (TDD discipline) | Tests 29.14-29.17 written failing before fix; pass after | c-expert |
| AC-10 (every prereq-met rez succeeds) | Test 29.15 + game-tester scenarios 1, 2 | both |

---

## Rollback Plan

Per PRD `## Rollback`, fixes are independently revertable:

1. **`spells.cpp:2051` rollback (the primary fix):** Revert the `ST_Corpse` extension. NPC companion corpses cannot be rezzed; the bug returns to its current state. Suite 29 tests 29.14, 29.15, 29.17 fail. AC-3 / AC-10 regress. AC-2 (player corpse rez) ALSO regresses if the cleric was rezzing the player via the same idle pipeline (player corpse path uses `IsPlayerCorpse()` which still passes the guard, so AC-2 is INDEPENDENT of this rollback).

2. **`companion_ai.cpp:1861` `FindDeadGroupMemberCorpse` rollback:** Revert the player-corpse search extension. AC-2 regresses (player rez stops working from companion); AC-3 (companion rez) still works. Test 29.16 fails. The two changes are TRULY independent — either can be reverted alone without affecting the other.

3. **Suite 29 test rollback:** The 4 new tests stay in the repo per AC-9 TDD discipline (per companion-rerecruit pattern). If the production fix is reverted, the failing tests document the regression. They are NOT deleted — they become "known broken" markers.

The two changes can be reverted independently and additively. No data corruption risk on revert (no schema changes; no DB writes added).

---

## Open Items / Future Work

The following items are flagged for awareness but are NOT in scope for this fix:

- **Player-commanded `!rez` companion command:** A command that lets the player target a corpse and trigger a manual rez via the cleric companion. PRD explicitly excludes this from scope; this fix delivers the automatic behavior only. Future feature.
- **Effective wall-clock latency tuning:** If 10s post-combat delay + 6-60s idle cadence (worst case ~70s) feels too slow in real play, a future polish pass could short-circuit the idle wait by triggering an immediate `AICastSpell` call from `m_rez_delay_timer.Check()` consumption.
- **Tier preference / multi-target ordering rules:** Currently hardcoded. If real-world play shows the policies need tuning, candidate rules `Companions:RezTierPreference` (string) and `Companions:RezPlayerFirst` (bool) could be added. Out of scope for this fix.
- **Companion mid-cast death (Cleric himself dying while channeling rez):** Standard `InterruptSpell` semantics apply (handled by engine). The downed Cleric's rez is interrupted; player-side recovery proceeds. Already correct.
- **Necromancer / Druid / Paladin auto-rez:** PRD Non-Goals. The existing AI dispatch in `AI_Necromancer` and `AI_Paladin` does include rez logic but is out of scope for this fix's testing. After the spells.cpp fix lands, these classes COULD also auto-rez if they have rez spells in `companion_spell_sets`, but the PRD locks the fix to Cleric verification only. data-expert noted only Cleric (class_id=2) rows currently exist in `companion_spell_sets` with `spell_type=65536`.
- **Shaman auto-rez:** HARD STOP — never. Era violation per lore-master.
- **`Spells:AI_IdleNoSpellMaxRecast` impact:** config-expert flagged that idle AI can wait up to 60s before tick. If perceived UX latency is a problem, separate polish pass to add an explicit "rez-pending" flag that bypasses the idle-tick wait. Not in scope.
- **Quest-state interaction with auto-rez:** Awareness flag only. No code change needed. Future quest designers can add `companion_exclusions` rows if they want to gate behavior, though even those don't affect re-rez of already-recruited companions (Track 1 short-circuits).

---

> **Next step:** Spawn the implementation team with ONLY the agents listed in
> "Required Implementation Agents" above (c-expert, infra-expert, game-tester).
> Do not spawn experts without assigned tasks.

---

# V2: ResurrectFromCorpse Pipeline Fix

> **V2 author:** architect
> **V2 date:** 2026-04-28
> **V2 status:** Approved by user — minus Fix R2 (descoped 2026-04-28; see notice below)
> **V2 advisors:** c-expert (production debug + file:line citations), data-expert (atomicity + DB layer)

---

## V2 Descope Notice (2026-04-28)

**Fix R2 (cross-zone auto-unsuspend at 10% HP in `SpawnCompanionsOnZone()`) is DEFERRED out of V2 scope to a separate future bugfix.**

**Reason:** Fix R2 expands the AC-10 reliability contract beyond what the original PRD locked. The PRD's AC-10 scopes "every prereq-met rez attempt MUST succeed" — a deterministic in-zone Cleric rez. Auto-unsuspending a dead companion at 10% HP without a Cleric cast on zone-in is a *new* capability (a fallback recovery mechanism) that semantically goes beyond the rez invariant. It deserves its own design pass with **game-designer involvement** to settle:

- Whether 10% HP / 0% rez XP is the right player-facing contract, or whether a different recovery semantic (e.g., "summon home at 1% HP", "auto-dismiss with refund of recruit cost", or "queued rez retry on owner return") is more appropriate.
- Whether the recovery should always fire, or be gated by player setting / rule.
- Whether the flavor message ("X has returned from the spirit world") fits the EQ tone.
- How it interacts with future Necromancer/Druid/Paladin auto-rez extensions.

**The user-observed "second companion never rezzed" symptom IS partially closed by V2 minus R2:** with Fix A (group slot leak fixed) + Fix B (Spawn routing) + Fix C (atomic chain), the in-zone rez of multiple companions in sequence works correctly. The specific case where the OWNER zones away mid-rez-cycle remains: dead companion stays `is_suspended=1`, recoverable via manual `!unsuspend`. This is a known-pending follow-up tracked in status.md.

**What V2 (minus R2) DOES close:**
- AC-3 (rez "takes" on NPC companion) — Fix A + B + C
- AC-6 (multi-target sequencing — all corpses rezzed in-zone) — Fix A + B + C
- AC-10 (every prereq-met rez succeeds) — Fix A + B + C + Option D pre-flight
- (New) No dead-caster self-rez — Fix R4
- (New) Atomic rez chain — no stuck "DB alive, no corpse" state — Fix C

**What V2 (minus R2) leaves OPEN for follow-up:**
- Owner-zoned-out-mid-rez recovery — `!unsuspend` is the workaround until R2's successor lands.

The architectural prose for Fix R2 below is preserved as the foundation for the future bugfix — engineers can pick up the design context when the R2 follow-up enters its own design phase. The implementation tasks (V2.6) and test 30.5 are removed from the V2 task list.

---

## V2 Executive Summary

The V1 fix (extending `ST_Corpse` validation at `spells.cpp:2051` + extending `FindDeadGroupMemberCorpse` for AC-2) landed and the rez **cast** now reaches `Companion::ResurrectFromCorpse`. Game-tester reported all 35 server-side test suites PASS. **In-game live play surfaced four deeper bugs** the V1 triage missed because the V1 plan stopped one stack frame too early — at "make the spell reach the handler" rather than verifying "the handler successfully restores the companion to the active group."

The user's verbatim report:
> "I was in a group where NPC companion members died. The cleric appeared to try and rez the first member, which seemed to work but the rez'd member was not in the same zone as us. They should've rezed at the body. They didn't even try to rez the second one." (BUG-001 V2 reopen.)

**Production debug (c-expert) on the live failure traced the bug chain in `Companion::ResurrectFromCorpse` (`companion.cpp:3547-3700`):**

| Bug | Layer | What fails | File:Line |
|-----|-------|-----------|-----------|
| **R-1** | Entity registration + name normalization | `entity_list.AddNPC()` is called instead of `entity_list.AddCompanion()`. New entity is in `npc_list` but NOT `companion_list`. Name normalization (`Spawn():2403-2404`) and immunity strip (`Spawn():2432-2440`) are skipped. Boss-NPC companions retain invulnerability. | `companion.cpp:3647` |
| **R-2** | Group slot leak at death | `Companion::Death()` calls `g->MemberZoned(this)` which clears the `members[i]` pointer but NOT the `membername[i]` string (cross-zone group tracking invariant). On rez, `Group::AddMember()` returns false in BOTH ways: the capacity check (`groups.cpp:235` — `GroupCount() >= 6`) for full groups, and the name-collision check (`groups.cpp:277-280`) for any group size. The new entity then walks into `Suspend()` → `Save()` → DB writes `is_suspended=1` back, **destroying the rez XP restore**, and `Depop()` removes the entity. Player observes "rez succeeded but companion not in zone." | `companion.cpp:713-718` + `groups.cpp:1184,277` |
| **R-3** | Atomicity | If any failure (R-1, R-2, or future) fires after `is_suspended=0` and `corpse->DepopNPCCorpse()`, the system enters a stuck state: DB says alive, no corpse, no entity. `!unsuspend` is the only recovery and may immediately re-fail if the underlying cause persists (e.g., still group-full). | `companion.cpp:3616-3680` |
| **R-4** | Dead caster self-rez | `AI_ResurrectDeadGroupMember()` has no `IsAlive()` / `GetHP() > 0` guard. `Companion::Process()` line 1893 sets `m_suspended=true` on HP=0 but does not return — execution continues to `NPC::Process()` and `Mob::AI_Process()`. A dead Cleric with residual mana (HP→0 before mana→0 from a single big hit) can attempt to rez its own corpse via `FindDeadGroupMemberCorpse()` (matched by `owner->CharacterID()`). Practical severity is bounded by the OOM gate, but the edge case produces undefined behavior. | `companion_ai.cpp:1935` |

**Plus a fifth concern surfaced by the user's report — owner zoned out mid-rez-cycle:** Pending rez state for surviving dead companions does NOT persist when the owner zones away. `SpawnCompanionsOnZone()` skips `is_suspended=1` rows on zone-in (`companion.cpp:4155`), leaving the companion stuck `is_suspended=1` indefinitely. We treat this as **R-2-zone** (not a separate bug, but the same "second companion never rezzed" symptom).

**The V2 fix is four C++ changes — all in `eqemu/zone/companion.cpp` and `eqemu/zone/companion_ai.cpp`:**
- **Fix A (prerequisite):** Free the dead companion's group name slot at `Companion::Death()`.
- **Fix R4 (independent, lands with A):** Add `IsAlive()` guards to `AI_ResurrectDeadGroupMember` and `Companion::Process`.
- **Fix B (depends on A):** Route `ResurrectFromCorpse` entity creation through `Spawn(owner)` instead of manual `AddNPC` + setup.
- **Fix C (depends on B):** Make the rez chain atomic — defer `corpse->DepopNPCCorpse()` until after `Spawn()` + `CompanionJoinClientGroup()` confirm success; rollback DB write on failure; pre-flight group-capacity check at the top of `AI_ResurrectDeadGroupMember` (defense-in-depth Option D).
- **(Fix R2: DEFERRED to future bugfix — see Descope Notice above.)**

**Plus 4 new TDD tests in a new Suite 30** of `cli_companion_tests.cpp`. **No DB schema changes. No Lua changes. No protocol changes. No new rules. Engine `MAX_GROUP_MEMBERS=6` cap retained.**

BUG-028 (entity id=0 at death) stays out of V2 scope — both c-expert and data-expert independently verified that `m_companion_id` is independent of entity ID, the existing fallback at `companion.cpp:662-701` correctly persists `is_suspended=1`, and BUG-028 does not corrupt corpse metadata or amplify the rez issue.

---

## V2 Existing System Analysis

### What V1 Built (still correct)

The V1 fix established that the rez spell now reaches `Companion::ResurrectFromCorpse`:

```
Cleric AI tick → AI_ResurrectDeadGroupMember → AIDoSpellCast(rez_spell, target_corpse)
  → CastSpell → DetermineSpellTargets(ST_Corpse) ← V1 fix admits IsCompanionCorpse()
  → SpellFinished → SpellOnTarget → ApplySpellEffects
  → SpellEffect::Revive (spell_effects.cpp:1707-1730) ← branches on IsCompanionCorpse()
  → Companion::ResurrectFromCorpse (companion.cpp:3547-3700) ← V2 work happens here
```

V1 made the spell **reach** the handler. V2 makes the handler **succeed end-to-end**.

### What V2 Found Broken Inside ResurrectFromCorpse

**Live in-game failure trace from c-expert's production debug (zone log evidence):**

1. Cleric companion targets dead Warrior corpse, casts Resurrection — spell completes, animation fires, log line "X has been resurrected by Y" emits.
2. `ResurrectFromCorpse` writes DB UPDATE `is_suspended=0`, restores XP, sets `IsRezzed(true)`, depops corpse (`companion.cpp:3624-3630`).
3. `new Companion()` constructed; `entity_list.AddNPC(new_comp)` adds to `npc_list` and `mob_list` (line 3647) — **but NOT to `companion_list`** (because `AddCompanion` was the correct entry, not `AddNPC`).
4. Manual `AI_Start` + `Load` + `LoadEquipment` + `CalcBonuses` + `ScaleStatsToLevel` (lines 3650-3657) — bypasses `Spawn()` which would have done name normalization and immunity strip.
5. `CompanionJoinClientGroup()` → `Group::AddMember()` returns false — the dead companion's name string is still in `membername[]` (because `MemberZoned()` only cleared the pointer at `groups.cpp:606` per the cross-zone tracking invariant). Either capacity (`GroupCount() >= 6`) or name-collision (`Strings::EqualFold(membername[i], new_member_name)` at `groups.cpp:277-280`) trips.
6. `Suspend()` fires (`companion.cpp:2467-2481`) — `SetSuspended(true)` + `Save()` writes `is_suspended=1` BACK over the step-2 write. **The XP restore is permanently lost.**
7. `Depop()` removes the new entity from zone (line 2478).
8. Player observes: cleric cast completed, log line emitted, but companion is gone. Looks like "rez happened in a different zone" because no entity is visible locally.

**Owner-zoned-out path (the "second companion never rezzed" symptom):**

9. While step 6 was unfolding for the first companion, owner zoned to next area (`ZonePC Client [Chelon]` in zone log).
10. Surviving cleric AI tick on next call to `GetCompanionOwner()` returns nullptr (`companion.cpp:3903-3906` — `entity_list.GetClientByCharID()` only returns clients in current zone).
11. Companion AI for both surviving and dead companions fizzles: rez never re-attempted in old zone, new zone's `SpawnCompanionsOnZone()` skips `is_suspended=1` rows at `companion.cpp:4155`.
12. Dead companion stays `is_suspended=1` until `m_death_despawn_timer` fires (30 minutes) and auto-dismisses, OR until player runs `!unsuspend` manually.

### V2 Gap Analysis

| PRD Requirement | V1 State | V2 State | V2 Gap |
|-----------------|----------|----------|--------|
| AC-3: Rez "takes" on NPC companion target | Spell reaches handler; handler runs but corrupts state via R-1/R-2 | Handler succeeds end-to-end via Fix A+B+C | **CLOSED by V2** |
| AC-10: Reliability — every prereq-met rez attempt succeeds | Fails on group slot leak (R-2) for ANY group size, on registration mismatch (R-1), and stuck-state on partial failure (R-3) | Atomic rez: succeeds or no state change. Pre-flight group check prevents most common failure mode at the top. | **CLOSED by V2** |
| AC-6: Multi-target sequencing — all corpses rezzed | First rez fails silently → later rez attempts proceed but fail same way; if owner zones, all subsequent rezzes lost | Each in-zone rez succeeds atomically. (Owner-zoned-out cross-zone case = future bugfix per descope.) | **CLOSED for in-zone case by V2; cross-zone case = future bugfix** |
| AC-2: Player rez window appears for player targets | Works (no V2 regression — player corpse path uses `CastRezz`, not `ResurrectFromCorpse`) | Unchanged | None |
| AC-7: OOM / OOC graceful behavior | Existing `m_rez_meditation_announced` works | Unchanged | None |
| AC-8: No mid-combat rez initiation | Existing idle-only call site holds | Unchanged | None |
| (New invariant) No dead caster self-rez | Not enforced — dead Cleric with residual mana could attempt self-rez | Fix R4 adds `IsAlive()` guards | **NEW V2 invariant** |
| ~~(New invariant) Cross-zone resilience~~ | None — dead companions stuck `is_suspended=1` if owner zones away | (Fix R2 DEFERRED) — `!unsuspend` remains the recovery path until future bugfix | **DEFERRED — separate future bugfix** |

---

## V2 Technical Approach

### V2 Architecture Decision

Least-invasive-first applied per layer:

| Layer | Considered? | Decision | Rationale |
|-------|-------------|----------|-----------|
| Rule values | Yes | **No change** | The bugs are in entity lifecycle, not tunable parameters. No rule could explain `AddNPC` vs `AddCompanion` registration mismatch. |
| Server config | Yes | **No change** | Not a config-layer issue. |
| Lua scripts | Yes | **No change** | No Lua hooks in the rez entity lifecycle path; lua-expert v1 audit confirmed pure C++. |
| SQL data | Yes | **No change** | data-expert v2 audit: existing `is_suspended` column is sufficient persistence for cross-zone state; no new columns needed; corpse `m_companion_id` is independent of entity id (BUG-028 is non-issue for rez). |
| C++ source | Yes | **Five narrowly-scoped changes** | Two functions in `companion.cpp` + one in `companion_ai.cpp` carry every bug. Each fix is between 2 and ~30 lines. |

The V2 fix surface is decisively **C++-only and within two files**. No new abstractions, no schema migrations, no protocol changes.

### V2 Group Cap Policy Decision

**Keep `MAX_GROUP_MEMBERS=6` (engine default, defined in `eq_packet_structs.h:892`).**

The team-lead asked whether the 6/6 cap should be expanded for companions specifically given the "1-3 player + small companion party" target. **Decision: keep the engine default.** Reasoning:
- The user's observed failure is NOT genuine over-capacity (1 player + 5 companions = 6, exactly at cap). It's the **leaked dead slot** masquerading as over-capacity. Fix R-2 returns the slot, restoring real capacity.
- The engine `MAX_GROUP_MEMBERS=6` constant flows through dozens of code paths, packet structures, client UI assumptions, and group-management logic. Expanding it touches client/server boundary assumptions and Titanium client compatibility. Out of scope and risky.
- 1 player + 5 companions is exactly the design target for small-group play. With the leak fixed, there is no real-world capacity issue.
- If real-world feedback later shows 6 isn't enough for the target experience, that's a separate feature with its own architecture pass.

### V2 Cross-Zone Rez Persistence Decision

**In scope. Implement via Fix R2 (auto-unsuspend at 10% HP in `SpawnCompanionsOnZone()`). No schema change.**

The user's verbatim report explicitly mentions "they didn't even try to rez the second one" — owner-zoned-out is the proximate cause and addressing it is essential for closing BUG-001 V2. data-expert v2 confirmed `is_suspended=1` is sufficient persistence. c-expert v2 recommends the auto-unsuspend approach as the minimal fix. PRD framing supports it (the rezzed companion comes back at low HP, just like a Reanimation rez — no XP restore, but the death penalty already taken stays applied; the player gets their party member back without manual `!unsuspend`).

The flavor message ("Your companion X has returned from the spirit world.") is a one-line `Message` to the owner so the player knows what happened.

### V2 BUG-028 Scope Decision

**Out of V2 scope. Stays in backlog.** Both c-expert and data-expert independently verified:
- `m_companion_id` is a plain integer member of `Companion`, set at construction via `SetCompanionID()`. Independent of entity-list ID.
- `corpse->SetCompanionData()` at `attack.cpp:2908` reads `m_companion_id` and `m_owner_char_id` — neither uses entity ID.
- `IsCompanionCorpse()` checks `m_companion_id > 0` — unaffected by entity id=0.
- `ResurrectFromCorpse`'s DB lookup uses `companion_id` — unaffected.
- The existing fallback at `companion.cpp:662-701` (BUG-028 V1 fix) handles the DB save correctly when entity id=0.

BUG-028's root cause (whatever produces entity id=0 at death) is a separate pre-existing issue in the entity list / spawn pipeline. It does NOT cause or amplify the rez bugs. Scoping it into V2 would expand surface without closing any V2-relevant failure mode.

### V2 Atomicity Approach

**Option D (pre-flight group-capacity check) + Option C (defer corpse depop until after group join confirms).** Per data-expert v2 — **NOT** Option B (MariaDB transaction) and **NOT** pure Option A (defer DB UPDATE):

- **Option B rejected:** All companion tables are InnoDB and support transactions, but transactions don't help here. The DB always ends in a valid state (`is_suspended=0` on success, `is_suspended=1` via Suspend on failure). The actual problem is the in-memory corpse entity is permanently gone after `DepopNPCCorpse()`. A ROLLBACK can restore the DB but cannot un-depop the corpse.
- **Pure Option A rejected:** Deferring the DB UPDATE until after entity spawn introduces a worse crash window — a crash between spawn and UPDATE leaves a companion in zone with no DB record, and `!unsuspend` cannot recover it. The current crash window (UPDATE → entity creation gap) IS recoverable via `!unsuspend`.
- **Adopted: Option D + Option C.** Option D = pre-flight group-capacity check at the top of `AI_ResurrectDeadGroupMember` so we never start the chain when the slot is missing. Option C = defer corpse depop and roll back DB write via direct UPDATE on Spawn/group failure. Together they close all known failure modes without a worse crash window.

### V2 Code Changes

All five fixes are in `eqemu/zone/companion.cpp` (4 fixes) and `eqemu/zone/companion_ai.cpp` (Fix R4 + Fix C pre-flight). Sequence and dependency:

```
Fix A (group slot at death)      ──┐
                                   ├──→ Fix B (Spawn routing) ──→ Fix C (atomic rez)
Fix R4 (alive guards) ─────────────┘
Fix R2 (cross-zone auto-unsuspend) — DEFERRED to future bugfix
```

#### Fix A — Free the dead companion's group name slot at death (PREREQUISITE)

**File:line:** `eqemu/zone/companion.cpp:713-718` — immediately after `g->MemberZoned(this)` in `Companion::Death()`.

**What:** Iterate `g->membername[]` and null-terminate the slot whose value equals `GetCleanName()`. The MemberZoned semantic ("clear pointer, keep name for cross-zone tracking") is correct for living players who zone out — they will return as the same entity, so the name must persist. **For dead companions it is wrong:** they will return as a brand-new entity with a new entity ID, so the name slot must be released.

**Engineer note:** Implement in `companion.cpp` only — do NOT modify `groups.cpp`. The `groups.cpp:606` comment ("should NOT clear the name") is correct for the general MemberZoned contract; we are adding a companion-death-specific override above it. Match `GetCleanName()` (this is what `AddMember` stored in `membername[]` per `groups.cpp:260`).

**Dependencies:** None. Lands first.

**Subtlety:** `HasGroup()` check before iterating. After clearing, `GroupCount()` will correctly decrement and the rez entity's `AddMember` will pass both capacity and name-collision checks.

#### Fix R4 — IsAlive guards on companion AI for dead entities (INDEPENDENT)

**File:line 1:** `eqemu/zone/companion_ai.cpp:1935` (top of `AI_ResurrectDeadGroupMember`).

```cpp
if (GetHP() <= 0) return false;
```

**File:line 2:** `eqemu/zone/companion.cpp:1908` (after the HP=0 safety net block, before despawn timer check in `Companion::Process()`).

```cpp
if (GetHP() <= 0) return NPC::Process();
```

The second line prevents ALL companion AI (not just rez) from firing on dead entities. NPC::Process() is still called so the despawn timer and standard NPC cleanup continues to function.

**Why both lines:** Line 1 closes the specific R-4 self-rez path. Line 2 is broader — it prevents any future companion AI added to `Companion::Process()` from running on dead entities. Defense-in-depth at minimal cost (~6 lines total).

**Dependencies:** None. Independent of Fix A/B/C. Can land alongside Fix A.

**Verification:** c-expert traced the full call chain (`AI_ResurrectDeadGroupMember` → `Companion::Process` → `NPC::Process` → `Mob::AI_Process` → `Mob::CastSpell`) and confirmed no existing alive guard. The OOM gate at `AI_ResurrectDeadGroupMember:1997` prevents the rez from firing in the typical case (dead entity has 0 mana), but the mana-at-death edge case (HP→0 from a single hit before mana drained) leaves residual mana and the cheapest rez (Reanimation, 150 mana) becomes affordable. With Fix R4, the function returns false at the top regardless of mana state.

#### Fix B — Route ResurrectFromCorpse entity creation through Spawn() (DEPENDS ON A)

**File:line:** `eqemu/zone/companion.cpp:3632-3680` — replace the manual entity construction block.

**Current broken sequence:**
```
new Companion → SetCompanionID/etc → AddNPC → AI_Start → Load → LoadEquipment
              → CalcBonuses → ScaleStatsToLevel → CompanionJoinClientGroup
```

**Replacement sequence (mirrors `SpawnCompanionsOnZone()` lines 4183-4201):**
```
new Companion → SetCompanionID/etc → Load(companion_id) → Spawn(owner)
              → LoadEquipment → CalcBonuses → ScaleStatsToLevel
              → set post-rez HP (rez% of max) → set 0 mana → BuffFadeAll
```

`Spawn(owner)` (`companion.cpp:2390+`) already does:
- Name normalization (`clean_name[0]='\0'; strcpy(name, GetCleanName())`) at line 2403-2404 — fixes the Titanium-client group-window targeting bug.
- `AI_Start()` at line 2418 — **must NOT be called separately** by the rez path.
- Immunity strip (8 special abilities + Invul) at lines 2432-2440 — fixes boss-NPC retains-invulnerability bug.
- `entity_list.AddCompanion(new_comp)` (correct list — `companion_list` + `mob_list`, NOT `npc_list`) at `companion.cpp:3993-4022`.
- `CompanionJoinClientGroup()` — succeeds now that Fix A has freed the dead companion's name slot.

**Dependencies:** Fix A must land first (`Spawn()` calls `CompanionJoinClientGroup()` → `AddMember` which fails until Fix A is in).

**Subtlety 1:** `Load()` BEFORE `Spawn()` — pattern from `SpawnCompanionsOnZone`. Restores stance, equipment refs needed at spawn time.

**Subtlety 2:** `LoadEquipment`, `CalcBonuses`, `ScaleStatsToLevel` AFTER `Spawn()` — entity needs valid entity ID for item attachment.

**Subtlety 3:** Set post-rez HP (rez%, e.g. 75% for Restoration) AFTER `ScaleStatsToLevel` so the percentage is computed against correct max HP.

#### Fix C — Atomic rez chain (DEPENDS ON B)

**File:line:** `eqemu/zone/companion.cpp:3616-3680` — reorder the DB UPDATE / corpse depop / entity creation sequence.

**Current ordering (broken):**
```
1. corpse->IsRezzed(true)                  ← race guard, in-memory only
2. CompanionDataRepository::UpdateOne     ← DB WRITE: is_suspended=0, XP restored
3. corpse->DepopNPCCorpse()               ← CORPSE GONE
4. new Companion + AddNPC + setup...
5. CompanionJoinClientGroup               ← can fail; on failure → Suspend → DB writes is_suspended=1 back
```

**Fix C ordering (atomic):**
```
1. corpse->IsRezzed(true)                  ← stays early as race guard (per c-expert steel-man)
2. (already in Fix B) new Companion + Load + Spawn + post-spawn setup
3. After Spawn() returns true and entity is in companion_list with group:
   a. CompanionDataRepository::UpdateOne   ← DB WRITE: is_suspended=0, XP restored (only after success)
   b. corpse->DepopNPCCorpse()             ← corpse goes ONLY after rez confirms
4. On Spawn() failure or AddMember failure (which Fix A should prevent but defense-in-depth):
   a. delete new_comp (or Depop() if already added to entity_list)
   b. corpse->IsRezzed(false)              ← reset race guard so corpse remains targetable
   c. (no DB rollback needed because no UPDATE was run yet)
   d. log warning, AI tick will retry next cycle
```

**Plus pre-flight group-capacity check (Option D) at top of `AI_ResurrectDeadGroupMember` (before any of the above runs):**
```cpp
Group* g = entity_list.GetGroupByClient(GetCompanionOwner());
if (g && g->GroupCount() >= MAX_GROUP_MEMBERS) {
    // Defense in depth — Fix A should make this unreachable, but cap the chain
    // before any state mutates if the group is somehow still full
    return false;
}
```

**Dependencies:** Fix B.

**Subtlety 1 (per c-expert steel-man):** `corpse->IsRezzed(true)` STAYS at the early position as a race guard — prevents two clerics from concurrently casting on the same corpse. Reset to `false` ONLY on rez chain failure (so the corpse becomes targetable again). On success, the `IsRezzed(true)` is moot because the corpse is depopped immediately after.

**Subtlety 2:** This re-orders existing operations; it doesn't introduce new operations. The `CompanionDataRepository::UpdateOne` and `DepopNPCCorpse` calls remain — just moved to after the entity confirms successful spawn + group join.

**Subtlety 3:** The crash-safety property of the original code (acknowledged at `companion.cpp:3617-3620`) is preserved: a crash between Step 3a and 3b leaves DB at `is_suspended=0` but no entity in zone — `!unsuspend` recovers. A crash between Spawn() success and Step 3a leaves DB at `is_suspended=1` (no UPDATE ran) and corpse intact — next rez attempt picks up from corpse. Both windows recoverable.

**Subtlety 4 (per c-expert v2 final review):** If the implementation ever needs to roll back a `companion_data` write (e.g., a future refactor moves the `UpdateOne` call back before `Spawn()`), the rollback **MUST be a direct targeted SQL UPDATE**, NOT a call to `Companion::Suspend()`. `Suspend()` (`companion.cpp:2467`) calls `Save()` at line 2470, which writes the FULL ORM object state (HP, mana, position, equipment, etc.) — and those fields may be garbage or partially-initialized on a brand-new entity that failed group-join. Use a direct `database.QueryDatabase("UPDATE companion_data SET is_suspended=1, experience=experience-{xp_restore} WHERE id={companion_id}")` so only the rez-specific fields are touched. This same pattern is already used by the BUG-028 fallback at `companion.cpp:662-701`. Engineer note: with the Fix C ordering above (UPDATE moved AFTER Spawn() success), no rollback is needed in the normal path — this subtlety is forward-looking guidance for any future reordering.

#### Fix R2 — Cross-zone auto-unsuspend at 10% HP — **DEFERRED FROM V2**

> **DESCOPE NOTICE (2026-04-28):** Fix R2 is deferred to a separate future bugfix per user direction. The reasoning and design context are preserved below as the foundation for that future work — but Fix R2 is NOT part of V2 implementation. Implementation team should skip V2.6 and not touch `SpawnCompanionsOnZone()` at line 4155 in this pass.

**File:line:** `eqemu/zone/companion.cpp:4155` — replace the silent `continue` for `is_suspended=1` companions in `SpawnCompanionsOnZone()`.

**Current:**
```cpp
if (cd.is_suspended) { continue; }   // skip dead companions on zone-in
```

**Fix R2 replacement (when `is_suspended=1 AND is_dismissed=0`):**
- Spawn the companion normally via the existing path (Load → Spawn → LoadEquipment → CalcBonuses → ScaleStatsToLevel — same pattern as living-companion path).
- After spawn: set HP to 10% of max HP (Reanimation-equivalent — 0% XP rez, but the death penalty was already applied at death).
- Set 0 mana.
- BuffFadeAll.
- Update `companion_data.is_suspended=0` (companion is alive again).
- Send a message to the owner: "Your companion {name} has returned from the spirit world." (Match the existing flavor tone — silent on OOM; this is a one-time per-companion message on zone-in, not chat spam.)

**Dependencies:** None. Fix R2 is independent of A/B/C/R4.

**Subtlety:** Fix R2 only fires when the owner zones into a NEW zone with `is_suspended=1` companions in their roster. It does NOT change the in-zone rez flow (a Cleric in zone with a corpse still rezzes via the normal Fix B path). This is the safety net for "owner zoned away mid-rez-cycle, no Cleric came back to handle the rez" — which is exactly the user's "second companion never rezzed" symptom.

**Edge case — owner zones with a still-alive Cleric companion AND dead companions:** The Cleric will zone with the owner. On zone-in, Fix R2 auto-unsuspends the dead companions at 10% HP before the Cleric can attempt a rez. This is acceptable — the owner gets their party back faster, and the auto-unsuspend simulates a Reanimation-equivalent rez (0% XP returned, 10% HP). No conflict with the Cleric's normal in-zone rez flow.

### V2 TDD — New Suite 30

Per AC-9 (TDD discipline retained from V1). Add a new `Suite 30` to `eqemu/zone/cli/tests/cli_companion_tests.cpp` with the following failing-first tests. The engineer writes them first (red), implements the fixes, verifies green.

| Test | What it asserts | Pre-fix behavior | Post-fix behavior |
|------|-----------------|------------------|-------------------|
| **30.1** | After `ResurrectFromCorpse`, the new entity is in `entity_list.companion_list` (not just `npc_list` / `mob_list`). | FAILS — `AddNPC` does not register in `companion_list` | PASSES — `Spawn()` → `AddCompanion` registers correctly |
| **30.2** | After rez, the new entity's `name` field equals `GetCleanName()` (no MakeNameUnique suffix in the spawn-packet name). | FAILS — name normalization skipped | PASSES — Spawn() at line 2403-2404 normalizes |
| **30.3** | After `Companion::Death()`, the dead companion's `membername[]` slot is cleared; a new entity with the same clean_name can `AddMember` successfully. | FAILS — name slot not cleared; AddMember returns false on name-collision check | PASSES — Fix A clears slot |
| **30.4** | If `Spawn()` (or `CompanionJoinClientGroup()`) fails after `ResurrectFromCorpse` initiated, the corpse remains in zone (not depopped), DB `is_suspended` is unchanged, and `corpse->IsRezzed()` is reset to false. | FAILS — corpse depopped, DB written, no rollback | PASSES — Fix C atomic ordering |
| ~~30.5~~ | ~~(Structural-only) `SpawnCompanionsOnZone()` Fix R2 path~~ — **DEFERRED with Fix R2.** | — | — |
| **30.5** (formerly 30.6) | `AI_ResurrectDeadGroupMember()` returns false when the calling companion's `GetHP() <= 0`. (R-4 alive guard.) | FAILS — no alive guard | PASSES — Fix R4 line 1 returns false at top |

**Engineer note on test 30.5:** Per c-expert steel-man, owner-zones-out cannot be simulated in the unit test harness. Test 30.5 is a structural no-crash guard mirroring how V1 test 29.16 was handled. Live validation belongs to game-tester (Scenario 8 below).

**Existing Suite 29 (V1) tests must continue to pass.** The V2 changes do not touch the `ST_Corpse` validation or `FindDeadGroupMemberCorpse` (V1 fixes); those are independent. Engineer verifies all 17 pre-V2 tests (13 original + 4 V1 = 17 in Suite 29) still pass after V2 lands.

---

## V2 Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| V2.1 | Write 5–6 new failing tests in Suite 30 of `cli_companion_tests.cpp` per the test table above. Build the test binary inside the akk-stack container and run via `./bin/zone tests:companion`. Verify all V2 tests fail. Verify Suite 29 still passes. | c-expert | — | ~150 lines C++ test code |
| V2.2 | Implement Fix A: clear `membername[]` slot in `Companion::Death()` at `companion.cpp:713-718`. | c-expert | V2.1 | ~10 lines C++ |
| V2.3 | Implement Fix R4: `IsAlive()` guard at `companion_ai.cpp:1935` (`AI_ResurrectDeadGroupMember`) AND `companion.cpp:1908` (`Companion::Process`). | c-expert | V2.1 | ~6 lines C++ |
| V2.4 | Implement Fix B: route `ResurrectFromCorpse` entity creation through `Spawn(owner)` at `companion.cpp:3632-3680`. Match the `SpawnCompanionsOnZone` pattern. Don't double-call AI_Start. | c-expert | V2.2 | ~30 lines C++ (replaces ~30 existing) |
| V2.5 | Implement Fix C: atomic rez chain — defer `DepopNPCCorpse` until after `Spawn()` and group-join confirm; reset `IsRezzed(false)` on failure. Add Option D pre-flight group-capacity check at top of `AI_ResurrectDeadGroupMember` at `companion_ai.cpp:1935`. | c-expert | V2.4 | ~25 lines C++ (reordering + new check) |
| ~~V2.6~~ | ~~Implement Fix R2~~ — **DEFERRED to future bugfix per user (2026-04-28).** Removed from V2 task list. | — | — | — |
| V2.7 | Rebuild zone binary (`docker exec akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`). Re-run Suite 29 + Suite 30 — verify all 17 V1 tests still PASS and all 4 V2 tests now PASS. Run full companion test suite (35 suites). | c-expert | V2.2, V2.3, V2.4, V2.5 | runtime |
| V2.8 | `make restart` from akk-stack/, then full server stack startup (loginserver / world / 8 dynamic_NN zones per documented procedure). | infra-expert | V2.7 | runtime |
| V2.9 | In-game validation per V2 Validation Plan (8 scenarios). User confirms BUG-001 closed. | game-tester | V2.8 | manual |
| V2.10 | Commit and push V2 changes on `bugfix/companion-rez` in eqemu and claude repos. (akk-stack and spire have no V2 changes.) | c-expert | V2.7 | git |

**Dependency graph:**

```
V2.1 (failing tests) ──┬──→ V2.2 (Fix A: name slot) ──┐
                       │                              ├──→ V2.4 (Fix B: Spawn routing) ──→ V2.5 (Fix C: atomic) ──┐
                       └──→ V2.3 (Fix R4: alive guards) ──────────────────────────────────────────────────────────┤
                                                                                                                  │
                                                                                                                  ▼
                                                                                                       V2.7 (rebuild + verify)
                                                                                                                  ↓
                                                                                                       V2.8 (server restart)
                                                                                                                  ↓
                                                                                                       V2.9 (in-game validation)
                                                                                                                  ↓
                                                                                                       V2.10 (commit + push)
```

V2.2 and V2.3 are independent and can be implemented in parallel after V2.1. V2.4 depends on V2.2 (Spawn() calls CompanionJoinClientGroup which needs Fix A's slot release). V2.5 depends on V2.4 (atomic ordering only matters once Spawn-path is the entity-creation path). (V2.6 / Fix R2 deferred — see Descope Notice.)

---

## V2 Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| **c-expert** | V2.1, V2.2, V2.3, V2.4, V2.5, V2.7, V2.10 | All C++ source and test runner. Owns `companion.cpp`, `companion_ai.cpp`, `cli_companion_tests.cpp`. Production debug agent for this fix. (V2.6 deferred per descope.) |
| **infra-expert** | V2.8 | Server restart + full-stack startup procedure. Same as V1. |
| **game-tester** | V2.9 | Live in-game validation. Same as V1. |

**Not needed for V2:**
- **lua-expert:** No Lua changes. Pure C++ entity lifecycle fix.
- **data-expert:** No DB changes. Already provided architecture-phase atomicity guidance; no implementation tasks.
- **config-expert:** No rule changes. Existing rules are correct.
- **protocol-agent:** No client packet changes. The Spawn/AddCompanion path emits the standard OP_NewSpawn / OP_DeleteSpawn pair; no Titanium-client packet modifications.
- **perl-expert:** No Perl involved.

---

## V2 Risk Assessment

### V2 Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Fix A clears the wrong `membername[]` slot (e.g., another companion with same clean_name) | Very Low | Low | Companion clean_name is constructed from owner_char_id + base name, so duplicate clean_names are not possible within a single owner's group. Match function uses exact string equality. |
| Fix B's `Spawn()` call has side effects we missed | Low | Medium | `Spawn()` is well-documented and used by `SpawnCompanionsOnZone()` daily — battle-tested path. The rez path is now consistent with normal companion zone-in behavior, which has been working since companion-rerecruit. |
| Fix C atomic reordering breaks other concurrent callers of `ResurrectFromCorpse` | Very Low | Low | `ResurrectFromCorpse` is called only from `SpellEffect::Revive` at `spell_effects.cpp:1720` for IsCompanionCorpse targets. Single call site. No other callers. |
| Fix R4 `if (GetHP() <= 0) return NPC::Process()` in `Companion::Process()` skips a companion-specific cleanup we need | Low | Medium | The companion-specific code in Process() above line 1908 is the HP=0 safety net (already fired its DB write); below line 1908 are death timer + AI dispatch. Returning `NPC::Process()` keeps the despawn timer working. Engineer verifies during implementation that no companion-specific cleanup below line 1908 must run on dead entities. |
| Fix R2 auto-unsuspend at 10% HP is too generous (player's reaction is "wait, my companion just came back for free?") | Low | Low | Death XP penalty was applied at death and stays applied (Fix R2 does NOT restore XP, only HP). The 10% HP is intentionally low so the companion is fragile and the player still feels the death cost. Reanimation rez (in-era spell) gives 0% XP and ~10% HP — Fix R2 mirrors this in flavor. If real-world play feels too generous, the HP percentage can be tuned via a future rule (`Companions:CrossZoneAutoUnsuspendHpPct`). Out of scope for V2. |
| `Spawn()` calls `CompanionJoinClientGroup()` internally, conflicting with the rez path's manual call | Low | Low | After Fix B, the rez path no longer calls `CompanionJoinClientGroup` manually — Spawn() does it. The existing manual call at `companion.cpp:3680` is removed. |
| Fix R2 fires for companions that were genuinely dismissed long ago (`is_suspended=1, is_dismissed=0` from a stale state) | Very Low | Low | The combination `is_suspended=1 AND is_dismissed=0` is exactly the death state per companion-rerecruit semantics. Dismissed companions have `is_dismissed=1`. Long-stale rows (companion died, owner never returned) self-clean via `m_death_despawn_timer` (30 min) which sets `is_dismissed=1`. Fix R2 only fires on rows that are legitimately "dead-awaiting-rez." |
| Test 30.4 (atomic rollback) is hard to simulate in unit tests | Low | Low | Suite 29 already has corpse-metadata tests (29.13, etc.). Engineer can construct a synthetic Companion entity with a forced-fail Spawn() path for the test (similar to existing structural tests). If fully automatable proves too costly, keep 30.4 as a "structural no-crash" test like 30.5 and rely on game-tester for the integration check. |

### V2 Compatibility Risks

- **V1 fixes (`spells.cpp:2051` ST_Corpse extension, `FindDeadGroupMemberCorpse` player-corpse priority):** Untouched. V2 is downstream of the cast pipeline — V1 is upstream. They are orthogonal.
- **Charm pets, swarm pets, mercenaries, bots:** None of these go through `Companion::ResurrectFromCorpse` or `SpawnCompanionsOnZone`. None of them have `IsCompanionCorpse()` true. V2 changes are scoped to `Companion` class methods. No regression.
- **Existing companion data (live `companion_data` rows):** No schema migration. `is_suspended=1, is_dismissed=0` rows that exist today are exactly what Fix R2 targets — they auto-unsuspend on next zone-in. Existing alive companions are unaffected.
- **BUG-028 fallback:** `companion.cpp:662-701` is in `Companion::Death()` and remains unchanged. Fix A inserts new code AFTER `g->MemberZoned(this)` at line 713-718, well below the BUG-028 fallback. No interaction.

### V2 Performance Risks

None. All five fixes are infrequent code paths:
- Fix A runs once per companion death.
- Fix R4 runs once per AI tick on dead entities (which now early-exit, saving cycles).
- Fix B runs once per rez attempt.
- Fix C reorders existing operations (no new operations, no new allocations).
- Fix R2 runs once per zone-in per dead companion in the owner's roster — capped at 5 companions per player per zone-in, negligible.

---

## V2 Review Passes

### V2 Pass 1: Feasibility

**Can we actually build this?** Yes. Five C++ changes within two files, each between 6 and 30 lines. Standard Docker-exec rebuild. Existing CLI test runner. No new dependencies.

**c-expert verification:** All file:line citations confirmed code-grounded (Stage 5 + Stage 6 of c-expert's dev-notes). The `Spawn()` call signature, `AddCompanion()` semantics, `MemberZoned()` invariant, and `SpawnCompanionsOnZone()` pattern are all well-established in the codebase.

**data-expert verification:** No DB schema changes. No transactions. Existing `is_suspended` column is sufficient for cross-zone state. Pre-flight group-capacity check is implementable from `AI_ResurrectDeadGroupMember` context.

### V2 Pass 2: Simplicity

**Is this the simplest approach?** Yes. Considered and rejected:
- New `companion_corpses` DB table — rejected. data-expert v2: corpses are entity-only by design, no DB persistence makes sense at our scale.
- New `pending_rez` column on `companion_data` — rejected. Existing `is_suspended=1` row is sufficient persistence.
- MariaDB transactions wrapping the rez chain — rejected. The problem is in-memory entity lifecycle, not DB consistency. Transactions cannot un-depop the corpse.
- New rule `Companions:CrossZoneAutoUnsuspendHpPct` — rejected (YAGNI). Hardcoded 10% follows the Reanimation-equivalent flavor.
- New rule `Companions:RezAtomicityMode` — rejected. Atomicity is correctness, not configurability.
- Modifying `Group::MemberZoned()` to take an `is_dead` parameter — rejected per c-expert recommendation. Localizing the fix to companion.cpp avoids touching the cross-zone group tracking comment and keeps the Group class semantics unchanged.
- Expanding `MAX_GROUP_MEMBERS` from 6 — rejected. Touches client/server boundary; out of scope.
- Splitting V2 into multiple bugfix branches — rejected. The five fixes are tightly coupled (B depends on A, C depends on B). One branch, one architecture pass, one validation cycle.

### V2 Pass 3: Antagonistic

**What could go wrong?**

- **Edge: Two clerics rez the same corpse simultaneously.** `IsRezzed(true)` is set early as race guard before any DB write or entity creation. Second cleric's `FindDeadGroupMemberCorpse` skips rezzed corpses (existing logic at `entity.cpp:2059`). Single-corpse / single-rez invariant holds.
- **Edge: Cleric dies between the spell-cast initiation and `ResurrectFromCorpse` reaching the entity-creation step.** With Fix R4, the AI guard prevents the rez attempt from initiating in the first place if the Cleric is dead. If the Cleric dies AFTER initiating but before completing, `InterruptSpell` semantics handle the cancel — `ResurrectFromCorpse` never runs. Standard EQ rez-cast-interrupt behavior.
- **Edge: Owner zones out at the exact moment Spawn() is running.** `Spawn()` calls `GetCompanionOwner()` internally to resolve the owner client. If owner is gone mid-Spawn, `Spawn()` returns false (no owner = no group to join). Fix C catches this: `Spawn()` failure = no DB write, no corpse depop. Player zones into new zone, Fix R2 auto-unsuspends. Recoverable.
- **Edge: Player has 5 companions + 1 mercenary in group (non-companion).** `MAX_GROUP_MEMBERS=6` cap is across all member types. If the player has 5 companions + a merc, group is full. A dead companion frees its name slot per Fix A (clean_name match). New rezzed companion attempts to AddMember — passes name-collision check (slot is empty), passes capacity check (count is now 5 since dead companion's slot freed). Successful.
- **Edge: User runs `!unsuspend` during Fix R2's auto-unsuspend.** Both paths converge on the same Spawn() flow. The first to acquire the companion record wins; the second sees `is_suspended=0` and either no-ops or returns the same already-spawned entity. No double-spawn.
- **Edge: Companion at 10% HP from Fix R2 immediately re-engages a mob and dies again.** Standard companion death flow re-applies. Death penalty fires again. Player learns to give the companion a beat to regen. Acceptable game-design behavior — the auto-unsuspend is a safety net, not a "godmode" guarantee.
- **Edge: Concurrent zone-in (multiple companions auto-unsuspending in same tick).** Each call to Fix R2 spawns one companion. The order is `companion_data` row order. No race condition because all operations are on the single zone process's main thread.
- **Edge: Fix B's Load() before Spawn() finds stale equipment that no longer exists.** The companion was dead, not deleted — its equipment refs in DB are valid. `LoadEquipment()` is the same call used by `SpawnCompanionsOnZone()` for living companions; equipment is preserved through death per `Companions:EquipmentPersistsThroughDeath=true`.
- **Performance: 5 companions all dead, owner zones in.** Fix R2 spawns 5 entities sequentially during the zone-in handler. Each spawn is the standard companion spawn cost (~milliseconds). No throughput concern at the 1-3 player target.
- **Player exploit: kill all companions on purpose, zone, get them all back at 10% HP "for free."** Death penalty is ~10% XP per companion (per `Companions:XPDeathPenaltyPct`). Player kills 5 companions = -50% XP across roster. Auto-unsuspend at 10% HP returns 0% rez XP. Net: massive XP loss across companions, no benefit. Not an exploit.
- **Player exploit: train mobs onto companions, zone away, repeat.** Same XP penalty applies. Companions come back at 10% HP, instantly killable again. The player is just losing XP cycles — they're not gaining anything. Not an exploit.

**Protocol-level edge cases:** None. The rez path emits standard `OP_NewSpawn` / `OP_DeleteSpawn` / `OP_GroupUpdate` packets. Fix B routes through `Spawn()` which emits the SAME packets `SpawnCompanionsOnZone` emits — no new packet types, no new struct shapes. protocol-agent's V1 audit covered this surface.

**DB boundary conditions:** No new DB writes. Existing `CompanionDataRepository::UpdateOne` still issues the same UPDATE; only timing changes. No schema migration. data-expert v2 confirmed no transaction needed.

### V2 Pass 4: Integration

**How do the pieces fit together?**

The dependency graph is short and the fixes compose cleanly:

```
[ V2.1 — write 5–6 failing Suite 30 tests ]
            ↓
   ┌────────┼────────┐
   ↓        ↓        ↓
[ A: name  ] [ R4:  ] [ R2:    ]   ← independent leaf fixes
[ slot at ] [alive ] [cross- ]
[ death   ] [guards] [zone   ]
[         ] [      ] [unsusp ]
   │        │        │
   ↓
[ B: Spawn routing ]   ← depends on A (Spawn calls CompanionJoinClientGroup)
   │
   ↓
[ C: atomic rez chain + Option D ]   ← depends on B (Spawn return value drives atomicity)
   │
   └─→ ┌─────────────────────────┐
       │ V2.7 — rebuild + verify │
       │ V2.8 — server restart   │
       │ V2.9 — game-tester      │
       │ V2.10 — commit + push   │
       └─────────────────────────┘
```

**Cross-cutting integration with V1 and companion-rerecruit:**
- V1's `spells.cpp:2051` extension and `FindDeadGroupMemberCorpse` AC-2 player-corpse path remain in production untouched.
- companion-rerecruit's death-state semantic (`is_suspended=1, is_dismissed=0` row preserved on death) is the foundation for both Fix C (the DB UPDATE the rez chain rolls back to) and Fix R2 (the auto-unsuspend trigger). Without companion-rerecruit, V2 has no meaningful state to recover.
- BUG-028's entity-id-0 fallback at `companion.cpp:662-701` continues to fire on death-with-id-0 cases. V2 doesn't touch it. Independent.

**Each engineer task is self-contained.** c-expert has the file:line for every fix in dev-notes Stage 5+6. No "TBD" / "engineer figures out" in any task description.

---

## V2 Validation Plan

### What game-tester should verify in-game (post-V2 implementation)

1. **Scenario V2-1 (PRIMARY — BUG-001 V2 closure):** Player + Cleric + Warrior + 3 other NPC companions (full party of 6 = player + 5 companions). Engage a fight. Warrior dies during fight. Win the fight. Within ~10–15 seconds, Cleric casts rez on Warrior corpse, corpse depops, **Warrior reappears IN ZONE in the active group at the rez spell's HP/mana percentage**. Group window shows Warrior with normalized name (no `MakeNameUnique` suffix). Player can target Warrior via group window click. **PRIMARY V2 REGRESSION TEST.**

2. **Scenario V2-2 (multi-target sequencing — second companion now rezzed):** Same setup as V2-1, but two NPC companions die during the fight. Cleric rezzes companion 1 (~10s after combat ends), then waits ~20s (recast timer), then rezzes companion 2. Both back in zone, both in active group. **Closes the user's verbatim "didn't even try to rez the second one" symptom.**

3. ~~**Scenario V2-3 (cross-zone resilience — Fix R2):**~~ **DEFERRED with Fix R2.** Cross-zone auto-unsuspend behavior is a separate future bugfix; in V2, owner-zoned-out + dead companions = `!unsuspend` recovery (status quo).

4. **Scenario V2-4 (atomicity — synthetic group-full):** Manually construct a scenario where group is genuinely full of LIVING members (player + 5 alive companions). One companion dies. Cleric attempts rez. Pre-flight group-capacity check (Option D) kicks in — rez does not fire, corpse stays as targetable corpse, DB unchanged. Player dismisses one living companion. On next AI tick, rez fires successfully. **Validates Fix C atomic invariant.**

5. **Scenario V2-5 (R-4 self-rez prevention):** Cleric dies during a fight with residual mana (engineer may need to script-set HP via `#kill` after Cleric burst-mana'd a Yaulp etc.). Verify: Cleric's corpse does NOT cast a rez spell on itself. No log spam, no errant cast. Standard `m_death_despawn_timer` path runs.

6. **Scenario V2-6 (immunity strip — boss-NPC companion):** Recruit a boss-NPC companion (one with `MeleeImmunity` or `MagicImmunity` in its source NPCType). Engage a fight. Companion dies. Cleric rezzes. Verify: rezzed companion can be hit and can take damage (immunities stripped, just like a non-rez Spawn would). Without Fix B's immunity strip, the rezzed boss-NPC would be invulnerable.

7. **Scenario V2-7 (V1 regression check):** All V1 game-tester scenarios (Single companion down post-fight; Player rez prompt; Multi-target; OOM; Cleric down; Back-to-back fights; Range/LoS) MUST continue to PASS after V2. V2 does not regress V1. Game-tester re-runs the V1 test plan.

8. **Scenario V2-8 (no leak across many cycles):** Player engages 5–10 fights in a row, with companion deaths and rezzes each time. Verify: no DB row leaks (companion_data rows stay clean), no entity_list leaks (zone tick rate stable), no group_id table corruption. (`docker exec` queries to confirm DB cleanliness.)

### Engineer-side validation (V2.7)

Before declaring V2.7 complete, c-expert MUST verify:
- All 5–6 new Suite 30 tests PASS.
- All 17 existing tests in Suite 29 (13 V0 + 4 V1) still PASS.
- Full companion test suite (35 suites total) exits cleanly with status 0.
- Build artifacts in `eqemu/build/bin/` are fresh.
- No new compiler warnings.

### V2 Acceptance Criteria coverage

| AC (PRD) | V2 Validation method | Owner |
|----------|----------------------|-------|
| AC-3 (rez "takes" on NPC companion) | Suite 30.1+30.2+30.3 + game-tester V2-1 | c-expert + game-tester |
| AC-6 (multi-target sequencing) | game-tester V2-2 | game-tester |
| AC-10 (every prereq-met rez succeeds) | Suite 30.4 + game-tester V2-1, V2-2, V2-4 | c-expert + game-tester |
| (V1 ACs) AC-1, AC-2, AC-4, AC-5, AC-7, AC-8, AC-9 | Suite 29 + game-tester V2-7 (V1 regression) | c-expert + game-tester |
| ~~(New invariant) Cross-zone resilience~~ | DEFERRED with Fix R2 — separate future bugfix | — |
| (New invariant) No dead caster self-rez | game-tester V2-5 | game-tester |
| (New invariant) Immunity strip on rez | game-tester V2-6 | game-tester |

---

## V2 Rollback Plan

Per V1 PRD `## Rollback`, fixes are independently revertable. V2 maintains the same property:

1. ~~**Fix R2 (cross-zone auto-unsuspend) rollback:**~~ **NOT APPLICABLE** — Fix R2 is DEFERRED, not in V2. (When the R2 successor bugfix lands, its own rollback plan will live in that bugfix's architecture doc.)

2. **Fix R4 (alive guards) rollback:** Revert the two `IsAlive()` guards. R-4 self-rez edge case re-opens (low practical severity). AC-3 / AC-10 unaffected. Test 30.6 fails.

3. **Fix C (atomic rez) rollback:** Revert the reordering and the Option D pre-flight check. Fix B still works as long as Fix A is in. Stuck-state re-opens for any post-Spawn failure. Test 30.4 fails.

4. **Fix B (Spawn routing) rollback:** Revert. R-1 re-opens (rezzed entity not in companion_list, name not normalized, immunities not stripped). AC-3 regresses. Tests 30.1 + 30.2 fail. Fix A's group slot release is still correct but not exercised by the rez path.

5. **Fix A (group slot at death) rollback:** Revert. R-2 re-opens (dead companion's name slot leaks). AC-3 regresses. Test 30.3 fails. **Fix A is the load-bearing fix — it must NOT be reverted alone.** If V2 needs to be fully rolled back, revert in the order: R2, R4, C, B, A.

The five reverts are independent (can be applied in any subset). Reverting one does not require reverting the others. The TDD test suite stays in the repo even on rollback per AC-9 — the failing tests document the regressed behavior.

---

## V2 Resolved Open Questions (team-lead's three)

### Q1 — Group cap policy (keep 6/6 or expand?)

**Resolution: Keep `MAX_GROUP_MEMBERS=6` (engine default).** Expanding the constant touches Titanium client compatibility, dozens of code paths, packet structures, and group UI assumptions. Out of scope. Fix A (returning the leaked slot) addresses the perceived capacity issue — the user was at 6/6 because of a leaked dead slot, not genuine over-capacity. With Fix A, real capacity is restored.

### Q2 — Cross-zone rez persistence (in scope or not?)

**Resolution (revised 2026-04-28): DEFERRED to a separate future bugfix.** Initial v2 plan included Fix R2 (auto-unsuspend at 10% HP in `SpawnCompanionsOnZone()`); user reviewed v2 plan and chose to descope R2 because it expands the AC-10 contract beyond the original PRD's locked scope. The cross-zone resilience symptom remains as a known-pending follow-up; the recovery path is `!unsuspend` until the R2 successor lands. The R2 design context is preserved in this document for the future bugfix's design phase, which will involve game-designer.

### Q3 — BUG-028 entity-id-0 (in scope or not?)

**Resolution: Out of V2 scope.** Both c-expert and data-expert verified that:
- `m_companion_id` is independent of entity ID — corpse metadata is correct even when entity id=0.
- The existing fallback at `companion.cpp:662-701` correctly persists `is_suspended=1` regardless of entity ID.
- BUG-028 does not cause or amplify the rez bugs.

BUG-028 stays in backlog as a separate investigation into the entity list / spawn pipeline. Pulling it into V2 would expand surface without closing any V2 failure mode.

---

## V2 Open Items / Future Work

- **Tunable rule for cross-zone auto-unsuspend HP percentage:** Currently hardcoded at 10% (Reanimation-equivalent). If real-world play suggests this is too generous or too punishing, candidate rule `Companions:CrossZoneAutoUnsuspendHpPct` could be added. Out of scope for V2.
- **Tunable rule for cross-zone auto-unsuspend XP restoration:** Currently 0% (penalty stays applied). If real-world play wants partial XP restore, candidate rule `Companions:CrossZoneAutoUnsuspendXpPct`. Out of scope.
- **Rez-pending state in `data_buckets` for cross-zone fidelity:** Option B from data-expert v2 — write `companion_pending_rez_<id>` = `spell_id` when rez fires with owner not in zone; on zone-in, retry the rez at the original spell's quality. Higher fidelity than Fix R2's flat 10%. Out of scope; Fix R2 is the minimum viable closure for the user's symptom.
- **Extend MAX_GROUP_MEMBERS from 6 to 8 or 10 for companion-only roster:** Touches client/server boundary, packet structs, Titanium compat. Major scope expansion. Out of scope.
- **BUG-028 entity-id-0 root cause investigation:** Separate bugfix. Stays in backlog.
- **Companion mid-cast death when rezzing:** Fix R4's `IsAlive()` guard at the top of `AI_ResurrectDeadGroupMember` plus standard `InterruptSpell` semantics handle this. Already correct after V2.
- **Bonus: AC-5 tier preference unit tests** (mentioned in V1 as optional): still optional. If c-expert wants to add them while in `cli_companion_tests.cpp`, fine. Not required for V2 closure.

---

> **Next step (V2 — minus R2):** Spawn the implementation team with c-expert (V2.1, V2.2, V2.3, V2.4, V2.5, V2.7, V2.10), infra-expert (V2.8), and game-tester (V2.9). Do NOT spawn lua-expert / data-expert / config-expert / protocol-agent / perl-expert — they have no V2 implementation tasks. The four fixes can land in 1-2 commits if the engineer prefers (Fix A + R4 in one commit; Fix B + C in another) or as individual commits per fix — c-expert's call. Fix R2 is DEFERRED — see Descope Notice at the top of the V2 section.

---

# V3: Visibility & Regen Regression Fix

> **V3 author:** architect
> **V3 date:** 2026-04-28
> **V3 status:** Drafted — awaiting user review before implementation team is spawned
> **V3 advisors:** c-expert (regression triage + file:line citations), protocol-agent (heartbeat protocol trace), lua-expert (gsay reporting cadence audit + DB-backed regen math)

---

## V3 Executive Summary

V2 (`17662d4ba`) closed BUG-001 in-game (rez works end-to-end). The user then reported two regressions of previously-fixed behavior:

- **BUG-002** — NPC companions vanish from screen during combat when stationary (a previously-fixed "heartbeat" bug returning).
- **BUG-003** — HP/mana regen reports show "1%/report" when sitting (used to closely match the player's own pace).

Three independent advisor triages converge on a single, narrow root cause for **BUG-002**, a **likely-non-regression for BUG-003** that needs an empirical confirmation step before any code change, and one fourth-bug latent issue worth flagging.

| Bug | Verdict | Root cause | Fix surface |
|-----|---------|-----------|-------------|
| BUG-002 (visibility) | **CONFIRMED REGRESSION** | V2 Fix R4's `if (GetHP() <= 0) return NPC::Process();` at `companion.cpp:1933-1935` short-circuits the prior heartbeat (`m_ping_timer` → `SentPositionPacket`) at `companion.cpp:2128-2142`. Pre-V2, dead-but-still-rendered companion entities (kept in zone via `SetDepop(false)` after `Companion::Death()`) ran the full `Companion::Process()` body, so the heartbeat fired every 5s and the Titanium client kept the entity in its render set. Post-V2, dead entities skip the heartbeat block entirely; Titanium client culls them after ~5–10s — the player perceives "companion vanished mid-combat" because the entity that died seconds earlier disappears from screen instead of remaining as a visible body until rez or despawn. | **Single C++ change in `companion.cpp` Process() top-section.** Two equivalent options (architect picks **Option A** below). |
| BUG-002 alt | **HYPOTHESIS — STILL OPEN** | protocol-agent flagged: `NPC::AI_Process` may set `moving = true` on combat ticks via face-tracking rotation; if so, the heartbeat block's `IsMoving()` check at `companion.cpp:2133` repeatedly disables `m_ping_timer` before it can fire, leaving alive-companion combat heartbeats silently dead. c-expert did not confirm this in static analysis and the dead-companion explanation accounts for the user's symptom on its own. **V3 fix addresses this defensively (see Option A subtlety #2).** | Same fix as primary. |
| BUG-003 (regen reporting) | **LIKELY NOT A V2 REGRESSION** | All regen / report-cadence code is unchanged from before V2. lua-expert's empirical math (level 54 cleric, meditate=295 → `final_regen=36/tick` per live `CalcManaRegen` log lines, 6s tic) shows that the user's "1%/report at 15s cadence" is numerically consistent with a freshly-rezzed companion (post-rez `SetMana(0)`) climbing from 0 toward a large `max_mana` pool — the first few reports show 4-6% increments that *feel* slow because the absolute baseline starts at 0%. **No code change yet.** Empirical verification step required before any code change. | **Diagnostic-first.** game-tester observes a non-rezzed sitting companion baseline; data-expert verifies no duplicate `rule_values` rows (DB shows duplicates for `NPC:OOCRegen` and `Character:RestRegenTimeToActivate` — concerning lint). If empirical verification confirms a real regen rate regression, **escalate to a separate V3 follow-up** with new data; do not bundle with the V3 visibility fix. |
| Fourth-bug A | **LATENT (pre-existing, not V2)** | `entity.cpp:2044` `GetCorpseByOwnerWithinRange` uses `< range` (raw distance squared compared against a non-squared range argument). V1 fix passes `rez_range * rez_range = 40000`; effective range comes out to sqrt(40000)=200, accidentally correct at `RezRange=200`. Fragile if the rule is changed. | Not in V3 scope. Filed as a separate latent bug for future investigation. |
| Fourth-bug B | **LATENT (V2 contract risk)** | Fix A's `membername[]` clear at `Companion::Death()` could disrupt world-side cross-zone group records if a companion dies during a zone transition. Companions are zone-local (no cross-zone tracking in practice) — low real-world risk. | Not in V3 scope. Documented for future awareness. |

**The V3 implementation surface is one targeted C++ change** + an empirical observation step for BUG-003. No DB changes. No Lua. No protocol changes. No new rules.

---

## V3 Existing System Analysis

### What V2 left intact and what V2 broke

**Heartbeat mechanism (prior fix `9e4b7dfd1`, 2026-03-09):**
- **Constructor:** `m_ping_timer(5000)` initialized in `Companion::Companion(...)` at `companion.cpp:56`; `Disable()` at line 131.
- **Process body:** `companion.cpp:2128-2142`:
  ```cpp
  if (IsMoving()) {
      m_ping_timer.Disable();
  } else {
      if (!m_ping_timer.Enabled()) {
          m_ping_timer.Start(5000);
      }
      if (m_ping_timer.Check()) {
          SentPositionPacket(0.0f, 0.0f, 0.0f, 0.0f, 0);
      }
  }
  ```
- **Packet wire:** `Mob::SentPositionPacket` at `mob.cpp:1714` emits `OP_ClientUpdate` with `PlayerPositionUpdateServer_Struct`, broadcast via `entity_list.QueueClients(this, &outapp, send_to_self == false, false)`. Titanium client culls entities ~10s after the last position update; the 5s cadence provides 2× margin.
- **Bot precedent:** `bot.cpp:1737-1748` uses the same pattern with `BOT_KEEP_ALIVE_INTERVAL=5000`.

**V2 Fix R4 break-of-contract:**
- Inserted at `companion.cpp:1928-1935`:
  ```cpp
  if (GetHP() <= 0) {
      return NPC::Process();
  }
  ```
- This guard sits **above** the heartbeat block at line 2128 in the function body. **For HP=0 entities, the guard returns before the heartbeat block can run.**
- Pre-V2 baseline: `Companion::Death()` calls `SetDepop(false)` (`companion.cpp:627`) so the dead companion entity stays in the zone for the rez window. The pre-V2 `Companion::Process()` had **no `GetHP() <= 0` guard at the top**; dead entities ran the full body, the heartbeat fired every 5s, and Titanium kept rendering the dead entity as a visible body until either (a) the rez completed and replaced it, or (b) `m_death_despawn_timer` fired (30 min) and cleaned it up.
- Post-V2: dead entity hits the guard at line 1933 → returns early → heartbeat at line 2128 never runs → Titanium client culls the entity from its render set after 5–10s → player perceives "the companion vanished mid-combat."
- **Secondary contract break (caught during V3 review):** the same Fix R4 guard also bypasses the `m_death_despawn_timer.Check()` block at `companion.cpp:1937-1964`. Pre-V2, the despawn timer check ran on every tick for dead companions and fired at 30 minutes (`Companions:DeathDespawnS=1800`) to mark the row dismissed and trigger entity cleanup. Post-V2, this timer never gets checked for HP=0 entities. **A dead companion that is never rezzed will leak its entity reference indefinitely** (until zone restart) instead of self-cleaning at the 30-min mark. This is a pollution issue, not yet user-visible because zones recycle frequently and companions usually do get rezzed.

**Regen path (intact):**
- `NPC::Process()` at `npc.cpp:630` ticks `tic_timer` (6s cadence). At `npc.cpp:692-696`, when `GetMana() < GetMaxMana()` and `IsCompanion()`, it calls `CastToCompanion()->CalcManaRegen()` and applies the result via `SetMana()`.
- `Companion::CalcManaRegen()` at `companion.cpp:1512` uses the meditate formula `(((meditate/10) + (level - level/4))/4) + 4`, then multiplies by `RuleI(Character, ManaRegenMultiplier)/100` and `RuleI(Companions, CompanionManaRegenMult)/100`.
- Both rules confirmed live in DB: `Character:ManaRegenMultiplier=175`, `Companions:CompanionManaRegenMult=100`, `Companions:AlwaysMeditateRegen=true`.
- For an alive companion (level 54 cleric, meditate 295 — sample from live `CalcManaRegen` diagnostic log lines): `final_regen = 36/tick`. At 6s tics × 15s report cadence = ~2.5 ticks per report = ~90 mana per report = ~5% of a 1800-mana pool.
- The user's "1%/report" math: 1% of 1800 = 18 mana per 15s — half of one tick's regen. lua-expert's read: this is consistent with a freshly-rezzed companion at `cur_mana=0` (post-rez `SetMana(0)`) for the first few report intervals, where each report reads mana **before** the next regen tick fires (the report-then-regen ordering at `companion.cpp:2162-2168` predates V2; was always true).
- **Empirical verification still required** before declaring this not a regression — see V3 Validation Plan.

**Gsay reporting (intact):**
- `m_mana_report_timer(15000)` initialized at `companion.cpp:57`, `Disable()` at line 133.
- Started in `Companion::Sit()` at `companion.cpp:4012`; disabled in `Companion::Stand()` at line 4018.
- Fires inside `Companion::Process()` at lines 2028-2034 (PASSIVE stance) and 2162-2168 (BALANCED/AGGRESSIVE) on `IsSitting() && !IsEngaged() && GetMaxMana() > 0` — emits `CompanionGroupSay(this, "Mana: %d%%", static_cast<int>(GetManaRatio()))`.
- V2 made no change to `Sit()`, `Stand()`, the report timer, or the report block. **Cadence is unchanged.**

**Spawn() shared-path verification (c-expert):**
- `Companion::Spawn(Client* owner)` at `companion.cpp:2410` is called from THREE sites:
  1. `lua_client.cpp:3666` — first-time recruit (always was `Spawn()`)
  2. `companion.cpp:4255` — `Client::SpawnCompanionsOnZone()` (zone-in; always was `Spawn()`)
  3. `companion.cpp:3703` — `Companion::ResurrectFromCorpse()` (V2 Fix B added this call)
- `Spawn()` itself was NOT modified by V2. Fix B only added Spawn() as a call site for the rez path (replacing the broken manual `AddNPC` sequence).
- Implication: a regression caused by `Spawn()` would affect **all three call sites**, not just rez. The user reports only the visibility/regen symptoms; first-recruit and zone-in both rendered companions correctly during V2-era live play. **Therefore the visibility regression is not in `Spawn()`** — it is in the dead-entity Process() path (Fix R4).

### Gap Analysis (V3)

| Symptom | Pre-V2 | Post-V2 | V3 Gap |
|---------|--------|---------|--------|
| Dead companion entity visible to client until rez/despawn | YES (heartbeat ran for HP=0 entities) | NO (Fix R4 short-circuits heartbeat) | **CLOSED by V3 Fix V** |
| Dead companion auto-dismiss after 30min `DeathDespawnS` | YES (despawn timer ran in Process body) | NO (Fix R4 short-circuits despawn timer) | **CLOSED by V3 Fix V** (same fix; reorder Fix R4 to gate ONLY the AI dispatch path, not the heartbeat or despawn timer) |
| Alive companion heartbeat in combat | YES | YES (Fix R4 doesn't fire for HP>0) | None directly. **Defensive option** — also bypass the `IsMoving()` gate when `m_hold_combat_position=true` so caster face-tracking via NPC::AI_Process can never disable the timer mid-combat (covers protocol-agent's open hypothesis). |
| Mana regen rate (alive sitting companion) | Working at ~36/tick (level 54 cleric) | Working at same rate (no V2 change) | **Likely no gap.** Empirical verification required (see Validation Plan). |
| Mana report cadence | 15s in `Sit()` → `Stand()` window | Unchanged | None. |
| Sitting HP regen bonus (`m_sitting_regen_timer`) | 6s cadence; HP additive bonus | Unchanged | None. |
| Adjacent V2-touched functionality (aggro broadcast, group buffs, follow, pet movement, spell casting non-rez) | Working | Verified working post-V2 by c-expert fourth-bug scan | None. |

**Two concrete gaps:**

1. **`companion.cpp:1928-1935`** — Fix R4's blanket early-return for HP=0 entities is too coarse. It correctly skips AI dispatch (the original R-4 self-rez intent) but unintentionally skips the heartbeat (line 2128) and the despawn timer (line 1937), both of which are correct-and-necessary for dead companion entity lifecycle. **Fix V** restructures this to gate only the AI dispatch path.
2. **BUG-003 empirical verification** — game-tester scenario observing a NON-rezzed sitting companion's mana progression vs a NON-rezzed player Cleric's mana progression (controlled, same level, same meditate). If the rates match, BUG-003 is closed as misperception. If they don't, escalate to a follow-up bugfix with new data.

No other gaps. No Lua changes. No protocol changes. No DB schema changes. No new rules.

---

## V3 Technical Approach

### V3 Architecture Decision

Least-invasive-first per layer, applied with regression discipline:

| Layer | Considered? | Decision | Rationale |
|-------|-------------|----------|-----------|
| Rule values | Yes | **No change** | No rule could explain the heartbeat-bypass for HP=0 entities. config-expert / data-expert previously confirmed regen rules are sane. (BUG-003 may surface a duplicate `rule_values` row issue — flagged for data-expert if BUG-003 empirical verification confirms regression.) |
| Server config | Yes | **No change** | Not a config-layer issue. |
| Lua scripts | Yes | **No change** | lua-expert audit confirmed no gsay/reporting/sitting logic in Lua. |
| SQL data | Yes | **No change** | No schema or data change. |
| C++ source | Yes | **One targeted change in `Companion::Process()` top-section** | Restructure Fix R4 to gate only the AI dispatch path so the heartbeat and despawn timer continue to run for dead entities (matching pre-V2 semantics for those two responsibilities while preserving the R-4 self-rez block from V2). |

The V3 fix surface is decisively **C++-only and within one function** (`Companion::Process()`).

### V3 Code Changes

**Single targeted change. No new tests file; one new test in Suite 36.**

#### Fix V — Restructure Fix R4 to preserve heartbeat and despawn timer for dead entities

**File:line:** `eqemu/zone/companion.cpp:1928-1935`

**Current (broken):**
```cpp
// Fix R4 (BUG-001 V2): skip ALL companion AI for dead entities.  NPC::Process() is
// still called so the despawn timer and standard NPC cleanup (p_depop flag) continues
// to function.  This prevents dead companions from entering the AI dispatch path in
// NPC::Process() → Mob::AI_Process() → AI_IdleCastCheck(), which can trigger rez
// attempts, buff casts, or movement on a dead entity.
if (GetHP() <= 0) {
    return NPC::Process();
}

// Check death despawn timer
if (m_death_despawn_timer.Enabled() && m_death_despawn_timer.Check()) { ... }
// ... rest of Companion::Process body, including heartbeat at line 2128 ...
```

The above guard's COMMENT is wrong — `NPC::Process()` does NOT run "the despawn timer." The despawn timer is at line 1938 inside `Companion::Process()` body, AFTER the guard. `NPC::Process()` runs ticking, regen, `AI_Process()`, etc. — none of which fire `SentPositionPacket()` or check `m_death_despawn_timer`.

**Option A (RECOMMENDED — targeted, minimal):** Move the dead-entity AI gate from "early-return at top" to "narrow gates around AI dispatch in `NPC::Process()` call, with explicit heartbeat + despawn-timer + group-zoned-cleanup runs preserved."

```cpp
// V3 Fix V: replace the V2 Fix R4 blanket early-return with narrow gates.
// V2 Fix R4 correctly identified that AI dispatch (rez self-cast, buff casting,
// movement) must not fire on dead entities.  But the blanket early-return ALSO
// bypassed the visibility heartbeat (line 2128 below) and the death-despawn timer
// check (line 1938 below) — both of which MUST run for dead entities so the
// Titanium client keeps rendering the body and so the 30-min auto-dismiss fires.
//
// New approach: let dead entities run the responsibilities that are part of their
// lifecycle (heartbeat, despawn check, group-cleanup), and short-circuit ONLY the
// AI dispatch path at the bottom of this function. NPC::Process() at line 2254
// already gates AI_Process internally via IsAIControlled() — but companions stay
// AIControlled even when dead, so we explicitly bypass the AI portion below by
// returning early from the BALANCED/AGGRESSIVE stance scanning, melee triple-attack,
// and AI cast-check paths when GetHP() <= 0.

bool is_dead = (GetHP() <= 0);
```

Then, after the existing Process() body responsibilities (death-despawn timer, rez-delay timer, retention timer, replacement-spawn timer, FleeingImmunity sync) complete normally for both alive and dead, **wrap the AI-dispatch-only sections in `if (!is_dead)` guards** at:
- The PASSIVE stance branch returning early at line 2010 (already short-circuits AI; no change needed)
- The BALANCED/AGGRESSIVE stance scanning at lines 2040-2126 (wrap in `if (!is_dead)`)
- The triple-attack interception at lines 2203-2218 (wrap in `if (!is_dead)`; dead entities do not auto-attack)
- The class-positioning + AI dispatch path that includes UpdateCombatPositioning at line 2194 (wrap in `if (!is_dead)`)

Leave the heartbeat block at lines 2128-2142 and the sitting regen / mana report blocks **unguarded** (they already gate on alive-only conditions: `IsSitting()`, `!IsEngaged()`, `GetMaxMana() > 0`, etc., which a dead entity will not satisfy in normal practice).

The final `return NPC::Process()` at line 2254 stays unchanged — `NPC::Process()` runs the BuffProcess + tic_timer + corpse-or-cleanup logic that dead entities legitimately need.

**Option B (FALLBACK — simpler, slightly larger blast radius):** Keep the early-return guard, but add the heartbeat call inline before delegating. Two lines:

```cpp
if (GetHP() <= 0) {
    // Visibility heartbeat for dead companion entities — Titanium client culls
    // entities without position updates after ~10s.  Pre-V2 the heartbeat at
    // line 2128 ran for HP=0 entities; V2 Fix R4's early-return regressed it.
    // Same 5s cadence as the alive heartbeat (BOT_KEEP_ALIVE_INTERVAL parity).
    if (!m_ping_timer.Enabled()) { m_ping_timer.Start(5000); }
    if (m_ping_timer.Check()) {
        SentPositionPacket(0.0f, 0.0f, 0.0f, 0.0f, 0);
    }
    // Despawn timer must still fire for the 30-min auto-dismiss path.
    if (m_death_despawn_timer.Enabled() && m_death_despawn_timer.Check()) {
        // duplicate the existing despawn-timer body from line 1938-1963 OR
        // refactor it into a private method called from both alive and dead branches
    }
    return NPC::Process();
}
```

Option B is uglier (code duplication of the despawn timer body) and the ugliness scales if more companion-lifecycle responsibilities are added in future. Option A is the cleaner long-term shape.

**Architect recommendation: Option A.** Engineer (c-expert) chooses the final form during implementation; both options resolve BUG-002 and the secondary despawn-timer leak. The implementation MUST verify both heartbeat-for-dead and despawn-timer-for-dead by writing the failing tests below first.

#### Defensive subtlety #2 — protocol-agent's `IsMoving()` hypothesis

protocol-agent flagged that `NPC::AI_Process()` may set `moving = true` on combat ticks via face-tracking rotation, which could repeatedly disable `m_ping_timer` before its 5s window elapses, leaving alive-companion combat heartbeats silently dead. c-expert did NOT confirm this in static analysis, and the dead-entity explanation accounts for the user's symptom on its own.

**Defensive layer (recommended in same Fix V):** at the heartbeat block (line 2128), keep the `IsMoving()` gate but ALSO bypass it when `m_hold_combat_position == true` (caster/healer at range, holding position):

```cpp
// V3 Fix V defensive layer: caster/healer companions hold combat position via
// m_hold_combat_position even though NPC::AI_Process may briefly set moving=true
// during face-tracking rotation each tick.  The IsMoving gate would repeatedly
// Disable the ping timer before it fires, leaving combat heartbeats silently dead.
// Bypass the gate when explicitly holding position so the heartbeat is guaranteed
// to fire on its 5s cadence regardless of moving-flag noise.
bool actually_moving = IsMoving() && !m_hold_combat_position;
if (actually_moving) {
    m_ping_timer.Disable();
} else {
    if (!m_ping_timer.Enabled()) {
        m_ping_timer.Start(5000);
    }
    if (m_ping_timer.Check()) {
        SentPositionPacket(0.0f, 0.0f, 0.0f, 0.0f, 0);
    }
}
```

This change is independent of Option A vs B; it lands in the same fix block and closes protocol-agent's open hypothesis without waiting for empirical confirmation that combat AI sets `moving=true`. Risk is zero — `m_hold_combat_position` is set only by `UpdateCombatPositioning()` (`companion.cpp:1669-1902`) for caster/healer roles at range, which are exactly the scenarios where stationary heartbeat is most needed.

#### V3 TDD — New tests in Suite 36

Per AC-9 (TDD discipline retained from V1/V2). Add to `eqemu/zone/cli/tests/cli_companion_tests.cpp` Suite 36 (the V2 suite); the engineer may choose to start a new Suite 37 if Suite 36 grows unwieldy.

| Test | What it asserts | Pre-fix behavior | Post-fix behavior |
|------|-----------------|------------------|-------------------|
| **V3.1 (heartbeat for dead entity)** | After `Companion::Death()` and the next `Process()` tick, `m_ping_timer` is enabled and a `SentPositionPacket` was queued (verify via spawn-packet-counter or by polling `m_ping_timer.Check()` after a 5-second timer-advance). | FAILS — Fix R4 returns before the ping-timer block runs | PASSES — Option A's structural change ensures the heartbeat block runs for dead entities |
| **V3.2 (despawn timer for dead entity)** | After `Companion::Death()` simulating 1801 seconds of `Process()` ticks (or by directly setting `m_death_despawn_timer` to fire), the dead companion is correctly marked dismissed (`m_is_dismissed = true`) and `Save()` runs. | FAILS — Fix R4 returns before the despawn-timer check runs | PASSES — Option A preserves the despawn timer check |
| **V3.3 (defensive heartbeat in held position)** | Set `m_hold_combat_position = true` and `IsMoving() = true` (mock `moving` flag). On the next `Process()` tick, the ping timer is enabled (NOT disabled) and `SentPositionPacket` queued on its 5s cadence. | FAILS — current `IsMoving()` gate disables the timer | PASSES — defensive layer bypasses the gate when holding position |
| **V3.4 (alive companion regression guard)** | An alive companion in combat (HP > 0, `IsEngaged()=true`, BALANCED stance) still runs the heartbeat block and emits `SentPositionPacket` on 5s cadence — i.e., the V3 restructure does not break alive heartbeat for any stance. | PASSES (alive heartbeat was never broken) | PASSES (regression guard for V3) |

**Existing Suite 36 (V2) tests must continue to pass** unchanged after V3. The V3 change touches only the `Companion::Process()` top-section AI gate; it does NOT change the rez chain, group slot release, or atomicity logic from V2. Engineer verifies all 17+ V1 + V2 tests still pass after V3 lands.

#### V3 BUG-003 Diagnostic-First Approach

**No code change yet.** game-tester runs the following empirical observation BEFORE any BUG-003 code change is contemplated:

1. **Setup:** a single non-rezzed sitting Cleric companion at full mana, sitting next to the player who is also a sitting Cleric of similar level. (Both must have similar gear and meditate skill caps for a fair comparison.)
2. **Polling:** record absolute `cur_mana` values from both via the `!status` companion command (player) and the gsay mana report (companion) every 15s for 5 minutes.
3. **Comparison:** plot or tabulate the absolute mana progression. If the companion's mana climbs at the same per-tick rate as the player's mana climbs, BUG-003 is misperception (closed).
4. **Secondary lint (data-expert):** scan `rule_values` for any duplicate rows of `Companions:CompanionManaRegenMult`, `Companions:AlwaysMeditateRegen`, `Character:ManaRegenMultiplier`. The DB output during c-expert's V3 audit showed duplicates for `NPC:OOCRegen` and `Character:RestRegenTimeToActivate` — which is concerning lint regardless of whether it affects BUG-003. data-expert confirms or denies any regen-rule duplicates.

**If verification confirms a real regen rate regression:** scope a separate V3-followup bugfix with new evidence. Do NOT bundle the regen fix with the visibility fix in this V3 round — the visibility fix has a clean code-grounded root cause; bundling a speculative regen fix dilutes the V3 review and risks introducing regressions in regen logic that may not need any change.

**If verification confirms "1%/report" is a freshly-rezzed-companion artifact:** close BUG-003 with a documentation note in the companion runbook explaining post-rez mana climbing.

---

## V3 Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| V3.1 | Write 4 new failing tests in Suite 36 of `cli_companion_tests.cpp` per the table above (V3.1, V3.2, V3.3, V3.4). Build the test binary inside the akk-stack container and run via `./bin/zone tests:companion`. Verify V3.1, V3.2, V3.3 fail; V3.4 passes (regression guard). | c-expert | — | ~120 lines C++ test code |
| V3.2 | Implement Fix V Option A in `companion.cpp` `Companion::Process()` top-section: remove the V2 Fix R4 blanket early-return; introduce `bool is_dead = (GetHP() <= 0);` capture; wrap AI-dispatch-only sections (BALANCED/AGGRESSIVE stance scanning, triple-attack interception, UpdateCombatPositioning + AI cast-check) in `if (!is_dead)` guards; leave the death-despawn timer check, heartbeat block, sitting regen, mana report, and fleeing-immunity sync unguarded (they already gate on alive-only conditions). Implement defensive subtlety #2 at the heartbeat block: bypass `IsMoving()` when `m_hold_combat_position=true`. | c-expert | V3.1 | ~25 lines C++ (mostly indentation / wrapping) |
| V3.3 | Rebuild zone binary (`docker exec akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`). Re-run Suite 36 — verify V3.1, V3.2, V3.3 now PASS and all V1/V2 tests still pass. Run full companion test suite to confirm no regression elsewhere. | c-expert | V3.2 | runtime |
| V3.4 | `make restart` from akk-stack/, then full server stack startup (loginserver / world / 8 dynamic_NN zones per the documented procedure). | infra-expert | V3.3 | runtime |
| V3.5 | In-game validation per V3 Validation Plan below (3 sustained-play scenarios + BUG-003 diagnostic baseline). User confirms BUG-002 closed and reports BUG-003 verification result. | game-tester | V3.4 | manual |
| V3.6 | If BUG-003 verification confirms regression: scope a separate V3-followup bugfix with the new evidence. Do NOT extend V3 to handle it. If misperception: close BUG-003 with a runbook note. | architect (decision-maker) + game-tester (data) | V3.5 | analysis |
| V3.7 | Commit and push V3 changes on `bugfix/companion-rez` in eqemu and claude repos. (akk-stack and spire have no V3 changes.) | c-expert | V3.3 | git |

**Dependency graph:**

```
V3.1 (failing tests) ──→ V3.2 (Fix V Option A + defensive layer) ──→ V3.3 (rebuild + verify) ──→ V3.4 (server restart) ──→ V3.5 (validate) ──┬──→ V3.6 (BUG-003 decision)
                                                                                                                                              └──→ V3.7 (commit + push)
```

**Ordering matters:** Tests MUST be written before the fix (TDD discipline retained). V3.6 BUG-003 decision is informed by V3.5 game-tester data; if regression is confirmed, that becomes a separate bugfix branch — NOT part of V3.7's commit.

---

## V3 Required Implementation Agents

| Agent | Task(s) | Rationale |
|-------|---------|-----------|
| **c-expert** | V3.1, V3.2, V3.3, V3.7 | All C++ source and test runner work. Owns `companion.cpp`, `cli_companion_tests.cpp`. Production debug agent for this V3 fix; produced the V3 triage. |
| **infra-expert** | V3.4 | Server restart and full-stack startup procedure. |
| **game-tester** | V3.5 | Live in-game validation, plus BUG-003 baseline diagnostic. |
| **architect** | V3.6 | BUG-003 follow-up scoping decision based on V3.5 data. |

**Not needed for V3:**
- **lua-expert:** No Lua changes. V3 triage already complete.
- **data-expert:** No DB schema/data changes for the V3 fix. Optional `rule_values` duplicate-row scan if BUG-003 verification fires.
- **config-expert:** No rule changes.
- **protocol-agent:** No client packet changes. V3 triage already complete.
- **perl-expert:** No Perl involved.

---

## V3 Risk Assessment

### V3 Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Option A's `is_dead` guards miss an AI-dispatch path that should NOT run on dead entities (e.g., a future companion AI feature added below the BALANCED/AGGRESSIVE blocks) | Low | Medium | Engineer adds a defensive comment block at the top of `Companion::Process()` documenting the intent: "Dead entities run heartbeat + despawn + group cleanup; AI dispatch must be `is_dead`-guarded." Future contributors guard new AI dispatch sections by the same flag. |
| Option A's restructure accidentally re-enables a self-rez path (the original R-4 issue from V2) | Low | High | The R-4 self-rez path was specifically `AI_ResurrectDeadGroupMember` called from `AI_IdleCastCheck`. V2 added an explicit `if (GetHP() <= 0) return false;` guard at the TOP of `AI_ResurrectDeadGroupMember` (`companion_ai.cpp:1935`) — that guard remains in place after V3 and protects the self-rez path independently. Option A's `if (!is_dead)` wrapping of `UpdateCombatPositioning + AI cast-check` is defense-in-depth on top of that. **Both layers must remain intact.** |
| Defensive heartbeat layer (subtlety #2) over-fires when companion is genuinely moving and `m_hold_combat_position` is stale | Very Low | Low | `m_hold_combat_position` is reset to `false` at the top of `UpdateCombatPositioning()` every tick (`companion.cpp:1672`). Stale state cannot persist beyond one tick. Worst case: one extra `SentPositionPacket(0,0,0,0,0)` on a moving caster — already redundant with the real position update from movement, harmless. |
| Heartbeat-for-dead introduces network noise (one extra packet per dead companion every 5s for up to 30 min) | Very Low | Negligible | Packet size is 24 bytes. 1 dead companion × 1 packet × 5s × 360 ticks (30 min) × N nearby clients = a few hundred KB total over the death lifecycle. At the small-group target (1-3 players) and ~5 dead companions max per player, this is well under any noticeable bandwidth. |
| Despawn-timer-for-dead actually fires now and exposes a bug in the despawn body that was previously masked | Low | Medium | The despawn-timer body at `companion.cpp:1938-1964` is unchanged code that pre-V2 was reaching its `Save()` and `MemberZoned` calls correctly for dead entities. V3 simply restores that behavior. Test V3.2 explicitly validates the despawn body fires correctly post-V3. |
| Tests V3.1-V3.3 cannot be written with high fidelity in the unit test harness (no zone tick advance) | Low | Low | The cli test runner already handles this for V2 Suite 36 tests (e.g., 36.5 R4 alive guard). The same pattern applies: invoke methods directly, mock `GetHP()` returns, assert on observable state changes (e.g., a counter incremented inside a wrapped `SentPositionPacket` mock). c-expert chooses the test fidelity vs effort tradeoff. |

### V3 Compatibility Risks

- **V1 + V2 fixes:** V3 does not touch V1's `spells.cpp:2051` extension, V1's `FindDeadGroupMemberCorpse` player-corpse priority, V2's Fix A (group slot at death), V2's Fix B (Spawn() routing), V2's Fix C (atomic rez chain), or V2's Fix R4 alive guard at `companion_ai.cpp:1935`. V3 ONLY restructures the V2 Fix R4 line at `companion.cpp:1933-1935` — the other Fix R4 line at `companion_ai.cpp:1935` stays. Independent.
- **Fresh-recruit + zone-in companions:** unchanged. V3 affects only the dead-entity path inside `Companion::Process()`. Alive companions go through the same branch as before V3.
- **Charm pets, swarm pets, mercenaries, bots:** None of these go through `Companion::Process()`. No interaction. Bot's heartbeat is independent at `bot.cpp:1737-1748` and uses the same pattern V3 mirrors.
- **Existing companion data:** No DB changes. No migration. Existing dead companion entities (if any are left in zones at V3 land time) immediately benefit from the restored heartbeat + despawn timer.

### V3 Performance Risks

None. V3 reorders existing `Companion::Process()` body without adding new operations. The restored heartbeat for dead entities is one 24-byte packet broadcast per 5s per dead companion — negligible at the 1-3 player + 5 companion target.

---

## V3 Review Passes

### V3 Pass 1: Feasibility

**Can we actually build this?** Yes. One C++ change in `Companion::Process()` top-section (~25 lines of indentation/wrapping for Option A; even less for Option B). Standard Docker-exec rebuild. Existing CLI test runner. No new dependencies.

**c-expert verification:** Full code-grounded triage in `c-expert/dev-notes.md` Stage 6. File:line citations for every claim. Pre-V2 vs post-V2 diff verified via `git show 17662d4ba`.

**protocol-agent verification:** Heartbeat protocol mechanism confirmed. `OP_ClientUpdate` wire format pass-through (no Titanium translation). Position-update dedup system at `25826c668` does NOT block the heartbeat path (heartbeat uses `entity_list.QueueClients()` directly, bypassing the `m_last_seen_mob_position` dedup). Defensive `m_hold_combat_position` layer recommended pending c-expert confirmation that combat AI sets `moving=true`.

**lua-expert verification:** No Lua/quest hooks in regen, gsay, or sitting paths. BUG-003 is entirely a C++ concern. Empirical math (level 54 cleric, meditate=295, `final_regen=36/tick` from live `CalcManaRegen` log) shows "1%/report" is consistent with freshly-rezzed-companion-at-zero-mana climb pattern.

### V3 Pass 2: Simplicity

**Is this the simplest approach?** Yes. The fix surface is one logical change to one function (Option A: structural restructure of one Process() top-section) plus one defensive line at one heartbeat block. Considered and rejected:

- **Revert V2 Fix R4 entirely:** rejected. The R-4 self-rez prevention is correct and the test 36.5 covers it. Reverting would re-open the dead-Cleric-self-rez edge case.
- **Add a separate `Companion::ProcessDead()` method:** rejected. Premature abstraction; the dead-entity path is small and reads cleanly inline.
- **Move the heartbeat to NPC::Process():** rejected. The heartbeat is companion-specific (Bot has its own at `bot.cpp:1737-1748`). Generalizing would touch NPC base class semantics for all NPCs and break the bot/companion isolation.
- **Add a new rule `Companions:DeadHeartbeatIntervalS`:** rejected. The 5s interval is a Titanium client constraint, not a tunable. Hardcoded matches the existing pattern.
- **Bundle a BUG-003 fix speculatively:** rejected. The user's regression-discipline feedback explicitly warns against speculative changes. Empirical verification first; code change only if the verification confirms.
- **Bundle the latent `GetCorpseByOwnerWithinRange` range fix:** rejected. Not user-visible. Files separately.

### V3 Pass 3: Antagonistic

**What could go wrong?**

- **Edge: companion dies, owner immediately zones away. Dead companion entity persists with heartbeat + despawn timer. Owner returns to zone 31 minutes later.** Despawn timer fired at minute 30, dismissed the companion. Owner sees "X has returned home" message and a clean state. Acceptable.
- **Edge: companion dies during combat, NEXT companion rez fires within 5 seconds and replaces the dead entity.** The dead entity's `m_ping_timer` runs once or not at all (depending on tick alignment). The replacement entity (new Companion via Fix B `Spawn()`) takes over. No visible glitch.
- **Edge: 5 companions die in rapid succession.** Each dead entity emits one heartbeat packet every 5s. At 5 dead × 1 packet × 5s = 1 packet/s of dead-entity heartbeat traffic per nearby client. Trivial.
- **Edge: companion dies in a zone with 50 nearby clients (raid context).** Heartbeat packets broadcast to all 50 clients per dead entity. 5 dead × 1 packet × 50 clients × 5s = 50 packets/s. Still trivial; well under standard zone packet rates. Not a real concern at 1-3 player target.
- **Edge: `m_hold_combat_position` is inadvertently set on a moving companion (bug in `UpdateCombatPositioning`).** Defensive heartbeat layer would over-fire `SentPositionPacket` redundantly with movement updates. Harmless duplicate.
- **Edge: companion is HP=0 but `IsEngaged()=true` (transient state during the Death() call).** Heartbeat fires once, then `IsEngaged()` resets when hate is cleared. No issue.
- **Edge: Death() is called on a companion that has not yet received an entity ID (entity_id=0 case from BUG-028 fallback).** The dead entity stays in zone with id=0. Heartbeat block calls `SentPositionPacket(0,0,0,0,0)` which uses `GetID()` for `spu->spawn_id`. `spu->spawn_id=0` is a no-op for the client (no entity to update). Harmless.
- **Edge: Despawn timer fires while a rez is mid-cast.** The rez `IsRezzed(true)` race guard at `companion.cpp:3640` prevents another cleric from targeting the same corpse, but the despawn-timer body at line 1938-1963 marks the dead entity dismissed and saves to DB independently. This could create a window where the rez completes, replaces the entity, but the DB row was just marked dismissed by the despawn timer. **Mitigation:** the despawn timer body sets `m_is_dismissed=true` then `Save()`; `ResurrectFromCorpse` later writes `is_suspended=0, is_dismissed=0` (it explicitly clears both per V2 Fix B at companion.cpp:3656). Last-write-wins; rez clobbers the dismissal. **Acceptable.** If the rez is faster than the despawn timer (always — 30 min vs the AI-tick rez cadence of seconds), no race.
- **Antagonistic re: BUG-003 deferral:** What if game-tester verifies regen IS broken and the fix needs to ship in the same V3 round to keep the user productive? The V3 plan explicitly does not block on this — the visibility fix lands; if regen is real, a V3-followup is scoped. The user's regression-discipline feedback explicitly says "be extremely careful not to break existing functionality" — bundling a speculative regen fix violates that exact principle.

**Protocol-level edge cases (protocol-agent consult):** addressed by defensive `m_hold_combat_position` bypass.

**DB boundary conditions (data-expert consult):** No DB writes added by V3. Existing DB writes in the despawn-timer body now fire correctly for dead entities (they were silently broken by V2 Fix R4 — V3 restores correctness).

### V3 Pass 4: Integration

**How do the pieces fit together?** The fix is shorter and more linear than V1 or V2:

```
[ V3.1 — write 4 failing Suite 36 tests ]
             ↓
[ V3.2 — Fix V Option A + defensive heartbeat layer ]
             ↓
[ V3.3 — rebuild + verify all tests pass + no regressions ]
             ↓
[ V3.4 — server restart ]
             ↓
[ V3.5 — game-tester (BUG-002 in-game + BUG-003 baseline) ]
             ↓
[ V3.6 — architect decides BUG-003 close vs followup ]
             ↓
[ V3.7 — commit + push V3 to bugfix/companion-rez ]
```

**Cross-cutting integration with V1 + V2 + companion-rerecruit:**
- V1's `spells.cpp:2051` extension and `FindDeadGroupMemberCorpse` player-corpse priority — untouched.
- V2's Fix A (group slot at death), Fix B (Spawn routing), Fix C (atomic rez), and Fix R4 alive-guard at `companion_ai.cpp:1935` — untouched.
- V3 ONLY restructures `Companion::Process()` body; it preserves V2 Fix R4's intent (dead entities don't dispatch AI) while restoring pre-V2 invariants for heartbeat + despawn timer.
- companion-rerecruit's death-state semantic (`is_suspended=1, is_dismissed=0` row preserved) — untouched. V3 makes the despawn-timer auto-dismiss path work again, which is the correct behavior for dead companions that are never rezzed.

**Sustained-play validation is mandatory.** V2's tests covered brief encounters; V3 must validate at the time-scales where the regressions manifest — see Validation Plan.

**Each engineer task is self-contained.** c-expert has the file:line for the fix in dev-notes Stage 6 (V3 Regression Triage). No "TBD" / "engineer figures out" in any task description.

---

## V3 Validation Plan — Sustained-Play Mandatory Scenarios

The user's regression-discipline feedback explicitly flagged that V2's brief-encounter validation missed the sustained-play regressions. **V3 validation explicitly includes sustained, long-duration scenarios.** game-tester runs ALL of the following, in order, before declaring V3 closed.

### Mandatory game-tester scenarios

1. **Scenario V3-1 (PRIMARY — BUG-002 closure, sustained combat):** Player + Cleric companion + Wizard companion + Warrior companion engage a 5+ minute combat encounter (multi-pull, sustained DPS race). At least one companion dies in the first half of the encounter. Verify: the dead companion's BODY remains visible on the player's screen for the full duration of the encounter (until rez or until the player exits the encounter), with no "vanish on stationary" symptom. Verify: the cleric continues to heal the alive companions; if Cleric companion is the one that died, observe a different healer attempt rez per V2 logic. **PRIMARY V3 REGRESSION TEST.**

2. **Scenario V3-2 (BUG-002 in held-position combat, caster):** Player + Wizard companion engage a fight where the Wizard holds combat range and casts spells without moving. After 60+ seconds of stationary casting, verify the Wizard remains visible on screen (no vanish). Move the Wizard intentionally (target switch via aggro). Stationary again for 60+ seconds. Wizard remains visible throughout. **Defensive heartbeat layer validation.**

3. **Scenario V3-3 (BUG-002 dead entity persistence — 30 min lifecycle):** Recruit a low-level Warrior companion. Have it die in a low-level zone with no other clerics nearby (so no rez fires). Sit at the corpse / dead entity. Observe the dead Warrior body remains on screen for the full 30-minute despawn window. At ~30 min, verify the death-despawn-timer auto-dismiss fires: player gets the "X has returned home. You can recruit them again when you find them." message; the dead entity is removed from screen cleanly. **Despawn timer regression test (the secondary V2 Fix R4 break documented in V3 Pass 2).**

4. **Scenario V3-4 (alive companion regression guard):** All V1 + V2 game-tester scenarios MUST continue to PASS after V3. Game-tester re-runs the V1 + V2 test plan (V2-1 PRIMARY rez closure, V2-2 multi-target sequencing, V2-4 atomicity, V2-5 dead-caster self-rez, V2-6 immunity strip, V2-7 V1 regression, V2-8 no-leak-many-cycles).

5. **Scenario V3-5 (BUG-003 empirical baseline — sustained sit):** Recruit a fresh non-rezzed Cleric companion at full mana. Sit player + companion side-by-side for 5 minutes. Record `cur_mana` from gsay reports every 15s and `!status` snapshots every 60s. Compare to the player's own mana progression at the same level / meditate. **If rates match within 10%, BUG-003 is misperception.** **If companion regen is materially slower (>30% gap), file V3-followup bugfix.**

6. **Scenario V3-6 (BUG-003 post-rez baseline — confirm "1%/report" hypothesis):** Repeat scenario V3-5 but with a freshly-rezzed companion (cur_mana=0 from rez `SetMana(0)`). Observe the first 5 reports. **If the rate matches the alive baseline once mana climbs above 0**, the user's "1%/report" was the freshly-rezzed climb-from-zero pattern. Document the runbook note: "Post-rez companions start at 0 mana; first few mana reports show 4-6% increments climbing toward full pool, which can feel slow."

7. **Scenario V3-7 (multi-zone-cycle regression check):** Player recruits 2 companions, fights, dies, returns to bind, rebuilds, zones to a different area, fights again, zones back. Verify: companions follow correctly across zones, heartbeat fires for sitting companions in the new zone, no visibility regression in any zone, no DB row leaks (data-expert verifies `companion_data` row count stable).

8. **Scenario V3-8 (multi-rez-cycle regression check):** Same companions die and are rezzed 5+ times in rapid succession (deliberately test the V2 Fix B rez path under sustained load). Verify: each rez restores a visible-and-heartbeat-firing entity, no leak of dead entities, group slots correctly cycled per V2 Fix A.

### Engineer-side validation (V3.3)

Before declaring V3.3 complete, c-expert MUST verify:
- All 4 new Suite 36 V3 tests PASS.
- All 17+ existing tests in Suite 29 (V0 + V1) and Suite 36 (V2) still PASS.
- Full companion test suite (35+ suites total) exits cleanly with status 0.
- Build artifacts in `eqemu/build/bin/` are fresh.
- No new compiler warnings.

### V3 Acceptance Criteria coverage

| Symptom | V3 Validation method | Owner |
|---------|----------------------|-------|
| BUG-002 visibility heartbeat (combat, stationary, sustained) | Suite 36 V3.1 + V3.3 + V3.4 + game-tester V3-1 + V3-2 | c-expert + game-tester |
| BUG-002 dead-entity 30-min despawn | Suite 36 V3.2 + game-tester V3-3 | c-expert + game-tester |
| BUG-002 alive companion regression guard | Suite 36 V3.4 + game-tester V3-4 (V1+V2 re-run) | both |
| BUG-003 regen reporting | game-tester V3-5 + V3-6 (empirical) | game-tester (data) → architect (decision) |
| Sustained-play discipline (regression discipline feedback) | game-tester V3-1 (5 min) + V3-3 (30 min) + V3-7 (multi-zone) + V3-8 (multi-rez) | game-tester |
| Adjacent functionality (aggro, group buffs, follow, pet movement, spell casting) | game-tester V3-4 (V1+V2 re-run includes these) + V3-1 sustained encounter | game-tester |

---

## V3 Rollback Plan

Per V1 + V2 PRD `## Rollback`, fixes are independently revertable. V3 maintains the same property:

1. **V3 Fix V Option A (Process() restructure) rollback:** Revert the restructure. V2 Fix R4's blanket early-return restored. BUG-002 re-opens (dead entity heartbeat + despawn timer skipped). Tests V3.1, V3.2, V3.3 fail. AC for visibility / dead-entity persistence regresses. **The V2 Fix R4 alive guard at `companion_ai.cpp:1935` STAYS in place** (independent change; not part of V3 rollback). The dead-Cleric-self-rez edge case from V2 stays closed.

2. **V3 defensive heartbeat layer rollback:** Revert just the `m_hold_combat_position` bypass in the heartbeat block. Heartbeat goes back to gating only on `IsMoving()`. Test V3.3 fails. If protocol-agent's `IsMoving()` hypothesis is real, alive-companion combat heartbeat could silently fail (no current empirical evidence this is happening — defensive layer was preventative).

3. **TDD test rollback:** The 4 new Suite 36 V3 tests stay in the repo even on rollback per AC-9 — failing tests document any regressed behavior.

The two changes (V3 Option A + defensive heartbeat) can be reverted independently. V3 introduces no schema changes; no DB migration; no rule additions — rollback is purely C++ revert.

---

## V3 Resolved Open Questions

### Q1 — Was V2's Fix B path shared with normal recruit?

**Resolution: YES.** c-expert traced all `Companion::Spawn()` callers: `lua_client.cpp:3666` (first-recruit), `companion.cpp:4255` (zone-in), `companion.cpp:3703` (V2 Fix B rez). `Spawn()` itself was NOT modified by V2 — Fix B only added the rez call site. **Implication:** a `Spawn()`-side regression would affect all three call sites; the user reports neither recruit nor zone-in regressions, so the visibility regression is NOT in `Spawn()`. The regression is in the dead-entity Process() path (Fix R4).

### Q2 — What was the prior heartbeat fix?

**Resolution:** Commit `9e4b7dfd1` (2026-03-09), "fix(companions): enable caster spell casting and prevent client-side vanishing." Added `m_ping_timer(5000)` + `SentPositionPacket(0,0,0,0,0)` keepalive at what became `companion.cpp:2128-2142`. Mirrors `Bot::Process()` pattern at `bot.cpp:1737-1748`. **The code is intact in HEAD post-V2** — V2 did not modify it. But V2 Fix R4's blanket early-return at `companion.cpp:1933` short-circuits the heartbeat block for HP=0 entities. **V3 restores the pre-V2 invariant.**

### Q3 — Is BUG-003 actual regen broken or reporting cadence broken?

**Resolution: Likely neither — likely a freshly-rezzed-companion artifact.** lua-expert's empirical math (level 54 cleric, meditate=295, `final_regen=36/tick` from live `CalcManaRegen` diagnostic logs) shows that "1%/report at 15s cadence" is consistent with a post-rez companion (`SetMana(0)` applied) climbing from 0 mana toward a 1800-mana pool. The first few reports show 4-6% increments which the user perceives as "slow." V2 made NO changes to `CalcManaRegen`, `tic_timer`, `m_mana_report_timer`, `Sit()`, `Stand()`, or any regen-tick or report-cadence code. **Empirical verification step (V3-5 + V3-6) required before any code change.** If verification confirms a real regression, scope a V3-followup bugfix; do NOT bundle with V3 visibility fix.

### Q4 — Is there a fourth bug?

**Resolution: TWO LATENT items, neither in V3 scope:**
1. `entity.cpp:2044` `GetCorpseByOwnerWithinRange` uses `< range` against squared distance, with V1 calling-convention passing `range²`. Effective range = sqrt(range²) = range — accidentally correct at `RezRange=200`. Fragile if rule is changed. Pre-existing latent bug; not a V2 regression. Filed separately.
2. V2 Fix A's `membername[]` clear at `Companion::Death()` could disrupt world-side cross-zone group records if companion dies during a zone transition. Companions are zone-local (no cross-zone tracking in practice) — low real-world risk. Documented in V2 Fix A subtleties.

Neither item is a V3 fix scope; both are documented for future awareness.

---

## V3 Open Items / Future Work

- **Latent range bug at `entity.cpp:2044`:** Pass `rez_range` (not `rez_range * rez_range`) to `GetCorpseByOwnerWithinRange()` — pre-existing, accidentally correct at default rule value. File as a separate latent bug.
- **Duplicate `rule_values` rows lint:** DB output during c-expert's V3 audit showed duplicate rows for `NPC:OOCRegen` and `Character:RestRegenTimeToActivate`. Concerning regardless of BUG-003. data-expert investigates if BUG-003 verification fires; otherwise filed for future cleanup.
- **BUG-003 follow-up bugfix:** Conditional on V3-5 / V3-6 verification result. Architect decides post-V3.5.
- **Sustained-play test scaffold:** Multiple V2/V3 lessons argue for adding sustained-play test scenarios to the standard validation pipeline going forward — not just brief-encounter unit tests. game-tester scope expansion. Out of V3 scope.
- **`Companion::ProcessDead()` extraction:** If the dead-entity Process() path grows, refactor into a separate method. Currently small enough to read inline. Out of scope.
- **NPC base-class heartbeat generalization:** Both Bot and Companion implement nearly identical heartbeat patterns. A future refactor could move the heartbeat into a shared NPC method. Out of V3 scope; touches Bot.

---

> **Next step (V3):** Spawn the implementation team with **c-expert** (V3.1, V3.2, V3.3, V3.7), **infra-expert** (V3.4), and **game-tester** (V3.5). Do NOT spawn lua-expert / data-expert / config-expert / protocol-agent / perl-expert — they have no V3 implementation tasks. **All V3 changes can land in a single commit on `bugfix/companion-rez` per c-expert's call.**
>
> **Architect (V3.6) decides BUG-003 follow-up** based on V3.5 game-tester data — close-as-misperception vs scope a V3-followup bugfix.

---

---

## V3 Amendment — IsMoving() Hypothesis Ruled Out (2026-04-29)

> **Author:** architect
> **Status:** Supersedes V3 Fix V Subtlety #2 (defensive heartbeat layer) and V3 test 30/36-V3.3
> **Source:** c-expert post-triage analysis with code-grounded RotateToCommand math

### What changed

protocol-agent's open hypothesis ("`NPC::AI_Process` may set `moving=true` via face-tracking rotation, leaving the ping timer continuously disabled in combat") was investigated by c-expert with full file:line citations. **Hypothesis is RULED OUT.**

c-expert's empirical math:
- `RotateToCommand` at running speed (`rotate_to_speed=200`): per-frame turn capacity `td = 200 × 19 × frame_time ≈ 380` heading units
- Maximum heading delta is 256 units (full circle in heading-encoding terms)
- Since `td ≈ 380 ≥ dist ≤ 256`, the rotation completes in ONE movement-manager tick — `SetMoving(false)` is called inside the same `RotateToCommand::Process()` that set `moving = true`
- Main loop ordering verified at `eqemu/zone/main.cpp:601-617`:
  1. `entity_list.MobProcess()` runs → `Companion::Process()` → `NPC::Process()` → `AI_Process()` queues `RotateToCommand`
  2. `zone->Process()` → `mMovementManager->Process()` runs the queued command AND completes it → `SetMoving(false)`
- At the top of the NEXT `Companion::Process()` tick: `IsMoving() == false`. Heartbeat block runs, `m_ping_timer` ticks normally.

For caster/healer companions explicitly holding combat position (`m_hold_combat_position = true`), `FaceTarget` only fires when `!IsMoving()` (`mob_ai.cpp:1361`). If the target is stationary, `current_heading == new_heading` (`mob.cpp:4951`) and `FaceTarget` does nothing — no rotation, no `SetMoving` toggle. If the target moved, the rotation completes in one tick. **Either way, `IsMoving() == false` at the top of the next Process() tick.**

The hypothesis would have been pre-V2 behavior — there is no V2 change that could have made it worse. The ping timer was working correctly for alive companions before V2 and continues to work correctly post-V2.

### Implications for V3 Fix V

**Subtlety #2 (defensive `m_hold_combat_position` heartbeat bypass) is REMOVED from V3 scope.**

Reasoning: per the user's regression-discipline feedback ("be extremely careful not to break existing functionality"), defensive layers without empirical justification add risk surface for zero gain. With the `IsMoving()` hypothesis ruled out, the bypass would change `IsMoving()` semantics at the heartbeat block for no closed bug. **YAGNI** — drop it.

**V3 Fix V is now strictly:** restructure `Companion::Process()` top-section to capture `bool is_dead = (GetHP() <= 0);` instead of early-returning, wrap AI-dispatch-only sections in `if (!is_dead)` guards, leave heartbeat / despawn timer / sitting regen / mana report / fleeing-immunity sync unguarded. Option A as originally specified, **without** Subtlety #2.

The heartbeat block at `companion.cpp:2128-2142` is left exactly as-is post-V3 (no `m_hold_combat_position` bypass). For dead entities, the heartbeat now reaches them (via the Option A restructure). For alive entities, no change from current behavior.

### V3 Implementation Surface (Updated)

| Test | What it asserts | Status |
|------|-----------------|--------|
| **V3.1 (heartbeat for dead entity)** | After Death(), the next Process() tick reaches the heartbeat block; `m_ping_timer` is enabled and `SentPositionPacket` is queued on its 5s cadence for HP=0 entities. | KEEP — primary regression guard |
| **V3.2 (despawn timer for dead entity)** | After Death() simulating 1801s of Process() ticks, dead companion is correctly marked dismissed and Save() runs. | KEEP — secondary regression guard |
| ~~**V3.3 (defensive heartbeat in held position)**~~ | ~~Set `m_hold_combat_position=true` and `IsMoving()=true`; verify ping timer fires on 5s cadence anyway.~~ | **REMOVED** — hypothesis ruled out by c-expert; defensive layer no longer in Fix V |
| **V3.4 (alive companion regression guard)** | Alive companion in combat (HP > 0, IsEngaged=true, BALANCED stance) still runs the heartbeat block on 5s cadence — V3 restructure does not break alive heartbeat. | KEEP — renumber to V3.3 |

**Net V3 implementation surface is now 3 new tests + 1 C++ change** (down from 4 new tests + 1 C++ change with subtlety). Smaller, cleaner, and aligned with regression-discipline feedback.

### V3.6 BUG-003 follow-up decision is unchanged

The empirical-first approach to BUG-003 stands. game-tester runs V3-5 (non-rezzed sit baseline) and V3-6 (post-rez sit baseline) before any code change is contemplated. Architect decides at V3.6.

### Updated implementation team list

No change. **c-expert** owns V3.1 (3 tests), V3.2 (Fix V Option A — without Subtlety #2), V3.3 (rebuild + verify, formerly V3.4), V3.7 (commit + push). **infra-expert** owns V3.4 (server restart, formerly V3.5). **game-tester** owns V3.5 (8 sustained-play scenarios + BUG-003 baselines, formerly V3.6). **architect** rejoins at V3.6 (BUG-003 follow-up decision, formerly V3.7).

---

> **V3 plan is now FINAL.** All advisor input (c-expert + protocol-agent + lua-expert) consolidated. Awaiting user review before implementation team is spawned.



---

# V3 Re-Triage Architecture (2026-04-29) — SUPERSEDES Prior V3 Plan

> The prior V3 architecture cycle above is **SUPERSEDED** as of 2026-04-29.
> The user directed a complete re-process of BUG-002, BUG-003, and BUG-004
> together, with explicit emphasis on the customized NPC and Spawn systems
> and their downstream consumers. The prior V3 plan was scoped only to
> BUG-002 + BUG-003 and was produced before the architect agent definition
> was updated with customized-system awareness discipline.
>
> This V3 Re-Triage section is the new ground truth. Prior V3 plan content
> remains on disk above as historical reference but is NOT to be implemented
> as-is.

## Executive Summary

The V3 Re-Triage analyzed three reported bugs (BUG-002 visibility heartbeat, BUG-003 regen "1%/report", BUG-004 player AoE hits own companions) as a triage cluster per V3R Architecture Mandate 2. Five-advisor enumeration over Round 1 (c-expert, lua-expert, config-expert, data-expert; protocol-agent contributed substantive pre-findings P-1/P-2/P-3) **refuted** the working hypothesis that all three bugs share a single V2 root cause. Three independent root causes emerged, plus a NEW BUG-005 (auto-dismiss timer broken for dead companions) discovered during the customized-system enumeration that the prior V3 plan missed.

The V3R fix surface comprises **two C++ changes** (Fix V Option A restructure + Fix W α two-site IsCompanion exclusion) addressing BUG-002 + BUG-005 + BUG-004, plus an **empirical-first BUG-003 workflow** that may produce a one-line rule UPDATE (Branch B-rule) or close BUG-003 with a runbook note (Branch B-misperception) or escalate to a follow-up bugfix (Branch A/C/D). Total surface: ~25 lines of C++ across two files + ~10-15 lines of C++ across two more files + 4 new TDD tests + 9 sustained-play game-tester scenarios + a 4-test empirical protocol.

## Customized-System Enumeration (Primary V3R Deliverable)

Per V3R Architecture Mandate 1, this enumeration is the primary architecture deliverable. The fix shapes follow from the enumeration, not vice versa.

The full enumeration is captured across:
- **C++ side (35 consumers):** `architect/context/agent-conversations.md` 2026-04-29 c-expert FORMAL ENUMERATION entry (sections A.1–H.9)
- **Lua side (18 consumers):** agent-conversations.md 2026-04-29 lua-expert FORMAL ENUMERATION entry (sections A–H)
- **Configuration / rules (47 Companions:* rules + Pets:* / Spells:* / Aggro:* / NPC:* / Character:* / Range:* / Combat:* / Group:* / Adventure:* coverage):** agent-conversations.md 2026-04-29 config-expert EXPANDED enumeration entry
- **SQL / data layer (10 categories):** agent-conversations.md 2026-04-29 data-expert Round 1 entry (sections A–J)
- **Protocol layer (3 substantive pre-findings P-1/P-2/P-3):** agent-conversations.md 2026-04-29 protocol-agent ready entry

Full Round 2 synthesis at `architect/context/round-2-joint-root-cause-synthesis.md`.

### Critical enumeration findings

**Working hypothesis REFUTED** (V3R-D1):
- BUG-002 ↔ BUG-004 share NO surface (different functions, different files)
- BUG-003 root cause is at a different layer entirely (likely rule values)
- The shared correlation is "V2 reduced the masking of pre-existing or newly-introduced issues," not "V2 introduced a single bug that manifests three ways"

**NEW BUG-005 discovered** (V3R-D2): c-expert C-5 / B.2 finding. V2 Fix R4 early-return at `companion.cpp:1933-1935` for HP<=0 entities also bypasses `m_death_despawn_timer.Check()` at `companion.cpp:1938-1964`. Since `m_death_despawn_timer` is a Companion-class member, `NPC::Process()` has no knowledge of it. **30-minute auto-dismiss is not enforced for dead-not-rezzed companions post-V2.** Prior V3 plan missed entirely. BUG-005 ships in the same V3R fix as BUG-002 with zero additional code surface.

**Three-advisor convergence on BUG-004 root cause:** c-expert C-2 + config-expert G-3 + data-expert D-3. Companions never call `SetOwnerID()` (they use custom `m_owner_char_id`). The `_NPC(x) = x->IsNPC() && !x->GetOwnerID()` matrix in `Mob::IsAttackAllowed` returns true for companions → Client-vs-NPC branch returns true → companion is hit. **Pre-existing gap, not a V2 regression.** Fix shape α (narrow IsCompanion exclusion) confirmed over β (SetOwnerID with wide blast radius) and γ (Client-side override only). Codebase precedent at `entity.cpp:5636` (cone AoE IsCompanion exclusion) supports the α pattern.

**Four-advisor convergence on BUG-003 verdict:** c-expert C-3 + lua-expert L-1 + config-expert G-5/G-10 + data-expert D-9. Regen code path is unchanged by V2. Strongest hypothesis: **rule-tuning divergence (G-10)** — player has `Character:ManaRegenMultiplier=175` (1.75x), companions have `Companions:CompanionManaRegenMult=100` (no scaling). Testable WITHOUT code change.

## Joint Root-Cause Analysis

| Bug | Root cause | V2 attribution | Convergence |
|---|---|---|---|
| BUG-002 | Fix R4 early-return skips `m_ping_timer` heartbeat → Titanium culls dead/dying stationary companion | V2 Fix R4 (introduced regression) | c-expert C-1 + protocol-agent P-1 (two-advisor) |
| BUG-005 (new) | Same Fix R4 early-return skips `m_death_despawn_timer.Check()` → 30-min auto-dismiss not enforced | V2 Fix R4 (introduced regression) | c-expert C-5 (single-advisor discovery, 90% confidence; antagonistic-pass verification scenario in Validation Plan) |
| BUG-004 | Companions don't `SetOwnerID()`; `_NPC(x)` matrix returns true; Client-vs-NPC branch unconditionally allows attack. Two paths: `Mob::IsAttackAllowed` base + `IsPetOwnerOfClientBot` for ST_TargetAENoPlayersPets | NOT a V2 regression. Pre-existing gap. V2 Fix B may have made it more visible by ensuring rezzed companions are reliably present in entity-list | c-expert C-2 + config-expert G-3 + data-expert D-3 (three-advisor) |
| BUG-003 | Most likely **rule-tuning divergence** (player has 1.75x mana regen multiplier, companions don't). Possible alternative branches: actual code regression / climb-from-zero misperception / buff loss on rez | None directly. Perceived correlation may be coincidental (V2 made rez reliable → sustained-play increased → user noticed pre-existing tuning gap) | All four closed advisors converge on "regen code unchanged"; G-10 is strongest hypothesis |

## Fix Specifications

Detailed fix specs at `architect/context/round-3-fix-proposal-and-task-breakdown.md`.

### Fix V (Option A) — `Companion::Process()` Top-Section Restructure

Addresses **BUG-002 + BUG-005**. Replace Fix R4 blanket early-return with `bool is_dead = (GetHP() <= 0);` capture + `if (!is_dead)` guards on AI-dispatch sections. Keep the heartbeat block (B.1) AND the death despawn timer block (B.2) UNCONDITIONAL.

| Block | File:line | Run when dead? |
|---|---|---|
| `m_ping_timer` heartbeat | `companion.cpp:2128-2142` | YES (UNCONDITIONAL — outside guard) |
| `m_death_despawn_timer.Check()` | `companion.cpp:1938-1964` | YES (UNCONDITIONAL — outside guard) |
| `m_rez_delay_timer` engaged tracking | `companion.cpp:1966-1981` | NO (inside `if (!is_dead)`) |
| `m_retention_check_timer` | `companion.cpp:1984-1986` | NO |
| Sitting sync / stand-when-engage | `companion.cpp:2144-2160` | NO |
| Mana report gsay | `companion.cpp:2162-2168` | NO |
| LOM announcement | `companion.cpp:2171-2188` | NO |
| Combat positioning / formation | `companion.cpp:2190-2218` | NO |
| Attack rounds | `companion.cpp:2203-2218` | NO |

Net: heartbeat fires for dead-but-corpse-visible companions (BUG-002 fixed), despawn timer fires (BUG-005 fixed), AI dispatch correctly skipped for dead entities (Fix R4's intent preserved).

### Fix W (α) — Two-site `IsCompanion`-Aware AoE Exclusion

Addresses **BUG-004**. Two narrowly-scoped C++ checks following codebase precedent at `entity.cpp:5636`.

**Site 1 — `Mob::IsAttackAllowed` `_CLIENT vs _NPC` matrix (`aggro.cpp:732+`):** Insert a check before the matrix returns true: if `mob2->IsCompanion() && CastToCompanion()->GetOwnerCharacterID() == mob1's CharacterID`, return false. **Architect lean: surgical insertion (Option 2 in Round 3)** — auditable, follows precedent, avoids unintended-consequence risk of macro modification.

**Site 2 — `IsPetOwnerOfClientBot` for `ST_TargetAENoPlayersPets` (`effects.cpp:1143-1145`):** Extend the function to also return true if the entity is a Companion owned by a Client/Bot. Or add a sibling check in the filter site. **Architect lean: extend `IsPetOwnerOfClientBot`** — follows the function's intent (is this entity a PC's pet for AoE protection?), and treating an owned companion as equivalent for this purpose only changes behavior in the right direction.

**Cross-owner check is essential:** Both sites verify `m_owner_char_id == caster CharacterID`. PVP behavior preserved (other players' AoE can still hit your companion).

### V3R-Empirical-1 — BUG-003 4-Test Protocol (per Mandate 3)

Per V3R Architecture Mandate 3 (empirical-first on suspected regressions), BUG-003 work in V3R is bounded by an empirical measurement protocol with branched outcomes. NO code change for BUG-003 is contemplated until the protocol runs.

| Test | Setup | Decision |
|---|---|---|
| Test 1 | `#set mana_full` on Lashun. Sit. 4-cycle 60s observation of !status mana + gsay reports | If ≥100 mana/report → Branch B-misperception (close with note) |
| Test 1.5 | If Test 1 ≤50/report: `UPDATE rule_values SET rule_value='175' WHERE rule_name='Companions:CompanionManaRegenMult';` + `#rules reload` (or `#rules set <Rule> <Value>` for transient test). Re-run Test 1 setup. | If now ≥100/report → Branch B-rule (V3R fix is one rule UPDATE) |
| Test 2 | `#set mana 0` on Lashun. Sit. Same 4-cycle observation | Compare to Test 1 — confirms misperception is/isn't the explanation |
| Test 3 | Unsuspend Jimble + `#kill` Jimble + wait for Lashun auto-rez | Compare to Test 2 — Branch C if Jimble post-rez is slower (rez path degrades regen) |
| Test 4 (optional) | Repeat Test 1 with vs without active regen buffs | Branch D if buff state significantly affects regen — escalate to lua-expert |

**SQL polling note:** Per data-expert D-11 finding, `companion_data.cur_mana` is written ONLY at lifecycle-event Save() calls (Death, dismiss, suspend, rez-complete). It does NOT update on regen ticks. **The discriminator is in-game `!status` mana observation**, not SQL polling. SQL is used only for pre/post lifecycle-event setup snapshots.

| Test 1 | Test 1.5 | V3R action |
|---|---|---|
| ≥100/report | (skip) | Close BUG-003 with runbook note. **No V3R code/rule change.** |
| ≤50/report | ≥100/report | V3R fix is ONE rule UPDATE: `Companions:CompanionManaRegenMult` 100 → 175. **No code change.** |
| ≤50/report | ≤50/report | Escalate to c-expert C++ investigation OR descope to follow-up bugfix |

## Implementation Sequence

| # | Task | Agent | Dependencies |
|---|---|---|---|
| V3R.1 | Write 4 failing-first tests in Suite 36: V.1 (heartbeat-for-dead), V.2 (despawn-timer-for-dead), V.3 (alive-companion-regen-regression-guard), W.1 (aoe-excludes-owner-companion). Build the test binary; verify V.1, V.2, W.1 FAIL pre-fix; V.3 PASSES pre-fix. | c-expert | None |
| V3R.2 | Implement Fix V Option A: restructure `Companion::Process()` top-section per the block guard mapping above. ~25 lines C++. | c-expert | V3R.1 |
| V3R.3 | Implement Fix W α: two-site IsCompanion-aware AoE exclusion. Site 1 in aggro.cpp, Site 2 in effects.cpp. ~10-15 lines C++ across both files. | c-expert | V3R.1 (parallel with V3R.2 acceptable) |
| V3R.4 | Rebuild zone binary. Re-run Suite 36 — verify V.1, V.2, W.1 PASS, V.3 still PASSES, all V1/V2 tests unchanged. Run full companion test suite. | c-expert | V3R.2 + V3R.3 |
| V3R.5 | `make restart` + full server stack startup (loginserver / world / 8 dynamic zones per documented procedure). | infra-expert | V3R.4 |
| V3R.6 | In-game validation per V3R Validation Plan: 9 sustained-play scenarios + V3R-Empirical-1 4-test protocol for BUG-003. Branch routing per decision matrix. | game-tester | V3R.5 |
| V3R.7 | Architect rejoins to make BUG-003 final decision based on V3R.6 results. Closes BUG-003 with no V3R action (Branch B-misperception), routes Branch B-rule to V3R.6.5, or files follow-up bugfix (Branch A/C/D). | architect | V3R.6 |
| V3R.6.5 (conditional) | Execute BUG-003 rule UPDATE: `UPDATE rule_values SET rule_value='175' WHERE rule_name='Companions:CompanionManaRegenMult';` + `#rules reload` (or `#rules set <Rule> <Value>` for transient test) + verify. Only runs if Branch B-rule confirmed at V3R.7. | data-expert | V3R.7 |
| V3R.8 | Commit and push V3R changes on `bugfix/companion-rez` in eqemu and claude repos. Includes code commits, the conditional rule UPDATE if applied, architecture/status updates. | c-expert | V3R.7 / V3R.6.5 |

**Spawn list when implementation team is approved:** c-expert (V3R.1, V3R.2, V3R.3, V3R.4, V3R.8), infra-expert (V3R.5), game-tester (V3R.6). Architect rejoins at V3R.7. data-expert is conditionally re-spawned for V3R.6.5 only if Branch B-rule. **Do NOT spawn lua-expert / config-expert / protocol-agent** — they have no V3R implementation tasks.

## Validation Plan

Detailed validation plan at `architect/context/round-4-validation-plan.md`. Three bands:

**Band 1 — Direct symptom validation:**
- V3R-1 BUG-002 visibility heartbeat (PRIMARY)
- V3R-2 BUG-005 auto-dismiss after 30 minutes (PRIMARY, slow scenario)
- V3R-3 BUG-004 AoE friend/foe filter (PRIMARY)
- V3R-4 BUG-003 V3R-Empirical-1 4-test protocol with decision matrix

**Band 2 — Sustained-play coverage (per Mandate 4):**
- V3R-5 Sustained combat encounter (5+ minutes)
- V3R-6 Long-duration sit regen (3+ minutes)
- V3R-7 Multi-zone cycle
- V3R-8 Multi-rez cycle (with C-10 atomic-rez coexistence-window verification)
- V3R-9 Sustained AoE encounter

**Band 3 — Adjacent-system regression coverage (per Mandate 5):**
For each customized subsystem the V3R fix touches (Companion::Process tick, IsAttackAllowed, IsPetOwnerOfClientBot, m_death_despawn_timer, m_ping_timer, conditional CompanionManaRegenMult), at least one consumer beyond the symptom is tested. Full consumer matrix in the validation plan document.

**Aggregate pass criteria:**
1. All Band 1 PRIMARY scenarios pass
2. V3R-4 has a defined outcome routed per the decision matrix
3. All Band 2 sustained-play scenarios pass
4. All Band 3 adjacent-system regression scenarios pass
5. Antagonistic-pass hooks (C-10, NPC:OOCRegen interaction) examined and documented
6. Suite 29 + Suite 36 V1/V2 tests continue to pass

## Risk Assessment

| Risk | Severity | Mitigation |
|---|---|---|
| Fix V breaks alive-companion regen path (`if (!is_dead)` guard placement error) | HIGH if it occurs; LOW probability | V.3 regression-guard test ensures alive-companion regen continues; sustained-play V3R-5 + V3R-6 catch tick-rate regressions |
| Fix W exclusion logic incorrectly blocks legitimate AoE (e.g., on cross-owner companions) | MEDIUM if it occurs; LOW probability | Owner-CharacterID match check ensures cross-owner companions still hit normally; PVP behavior preserved by design |
| BUG-003 empirical test inconclusive (Test 1 borderline) | LOW | 4-test protocol with backup branches B-rule and C/D escalation; if inconclusive, default to descoping BUG-003 to follow-up bugfix per V3R-D6 |
| BUG-005 fix interferes with `!unsuspend` recovery path | LOW probability | E-15 antagonistic check confirmed `!unsuspend` reloads via SpawnCompanionsOnZone path; despawn timer re-initialized to disabled state |
| Fix C atomic-rez coexistence window (C-10) double-AoE | LOW (theoretical only; single-threaded zone tick) | V3R-8 multi-rez cycle includes "cast AoE during rez moment" verification scenario |
| `NPC:OOCRegen` vs `Companions:OOCRegenPct` interaction (G-9) — companions on wrong code path | MEDIUM if it occurs; LOW probability | V3R-6 long-duration sit regen scenario discriminates code paths empirically |
| Implementation surface expands during V3R.6 escalation | LOW | V3R-D6 explicitly defers Branch A/C/D BUG-003 work to follow-up bugfix; V3R surface is bounded at V3R.4 |

## Review-Pass Findings

Detailed at `architect/context/round-5-four-review-passes.md`.

| Pass | Result | Key items |
|---|---|---|
| Feasibility | PASS | All extension points verified by c-expert enumeration; codebase precedent for Fix W; established GM commands for empirical protocol |
| Simplicity | PASS | Fix V minimal (Option A is the cleanest restructure); Fix W two-site is minimum correct; V3R-Empirical-1 minimized to 3-5 tests with conditional escalation; BUG-005 bundled (zero additional surface) |
| Antagonistic | PASS | 20 items considered; no edge case unbroken; no race / performance / exploit / backward-compat concern; 2 items (C-10 + G-9) are validation-time hooks already in plan |
| Integration | PASS | Task dependency graph clean; each expert has sufficient context; validation covers every changed system; order minimizes wasted work |

## Decision Log (V3R)

| # | Decision | Rationale |
|---|---|---|
| V3R-D1 | Three independent root causes for BUG-002 / BUG-003 / BUG-004; not a shared V2 root cause | Three-advisor convergence in Round 1 refuted working hypothesis |
| V3R-D2 | NEW BUG-005 discovered during enumeration: 30-minute auto-dismiss timer broken by Fix R4 | c-expert C-5 / B.2 finding; same root cause as BUG-002, same fix (zero additional surface) |
| V3R-D3 | BUG-002 + BUG-005 fix: Option A pattern with heartbeat + despawn timer kept UNCONDITIONAL | Two-advisor convergence on shape; despawn timer must be unconditional too (the prior V3 plan implicitly required this but didn't enumerate it) |
| V3R-D4 | BUG-004 fix shape α (narrow IsCompanion exclusion at 2 sites) over β (SetOwnerID with wide blast radius) and γ (Client-side override only) | β rejected per Mandate principle of minimum blast radius; γ insufficient (doesn't address Site 2); α follows codebase precedent at entity.cpp:5636 |
| V3R-D5 | BUG-003 empirical-first via D-13 4-test protocol + G-11 rule-bump as Test 1.5 | Mandate 3; strongest hypothesis (G-10 rule-tuning divergence) is testable without code change |
| V3R-D6 | BUG-003 fix is conditional: Branch B-rule (rule UPDATE only) is the most likely outcome; Branch A/C/D escalate to follow-up bugfix | Per regression-discipline feedback: do not bundle speculative code changes with confirmed code changes |
| V3R-D7 | BUG-005 documented in V3R architecture; orchestrator owns BUG-005 report file creation | Per CLAUDE.md, the orchestrator (not architect) creates BUG-NNN report files |
| V3R-D8 | C-10 atomic-rez coexistence window flagged for game-tester awareness in V3R-8; no fix needed | Single-threaded zone tick eliminates real race; verification-only scenario |
| V3R-D9 | Optional rule `Companions:AoEExcludesCompanions` (config-expert G-7 proposal) NOT added | Per minimum-surface principle, hardcoded is preferred over an operator-tuning toggle for behavior that should always be the correct default |
| V3R-D10 | Fix V Option A's `if (!is_dead)` guards include B.3 / B.4 / B.7 / B.8 / B.9 / B.10 / B.11 (all AI dispatch); B.1 heartbeat + B.2 despawn timer stay UNCONDITIONAL | Per c-expert enumeration each block correctly mapped; preserves Fix R4's intent (no AI dispatch for dead) while restoring heartbeat + despawn timer |

## Open Questions

| # | Question | Owner | Status | Notes |
|---|---|---|---|---|
| V3R-Q1 | `Companions:CompanionManaRegenMult` history audit (was it ever higher than 100?) | c-expert | Pending git audit | Documentation-only; not load-bearing for fix |
| V3R-Q2 | HP regen parallel question: does companion HP regen have a similar tuning gap to mana regen? | config-expert | Pending follow-up 2 | Affects whether V3R rule fix extends to a parallel HP regen bump |
| V3R-Q3 | data-expert SQL column name verification (`owner_id` vs `owner_char_id`) for V3R-4 setup query | data-expert | Pending | Affects validation plan SQL snippet correctness |
| V3R-Q4 | `NPC:OOCRegen` vs `Companions:OOCRegenPct` code-path interaction | (validation-time discrimination via V3R-6) | Empirical | If V3R-6 reveals companions on wrong path, escalate to c-expert |
| V3R-Q5 | protocol-agent formal structured enumeration (B/F sections) | protocol-agent | Pending | Pre-findings P-1/P-2/P-3 cover substantive needs; formal enumeration would add depth without changing conclusions |

## Handoff to Implementation Team (Pending User Approval)

Implementation team will be spawned ONLY after the user reviews and approves this V3R Architecture section per the V3R brief.

**Implementation sequence:**
1. V3R.1 (TDD red tests) → c-expert
2. V3R.2 (Fix V Option A) → c-expert
3. V3R.3 (Fix W α two-site) → c-expert
4. V3R.4 (rebuild + verify) → c-expert
5. V3R.5 (server restart) → infra-expert
6. V3R.6 (in-game validation + V3R-Empirical-1) → game-tester
7. V3R.7 (architect rejoins for BUG-003 decision)
8. V3R.6.5 (conditional rule UPDATE) → data-expert (only if Branch B-rule confirmed)
9. V3R.8 (commit + push) → c-expert

**Assigned experts:** c-expert, infra-expert, game-tester. data-expert conditionally re-spawned for V3R.6.5 only. architect rejoins at V3R.7.

**Do NOT spawn:** lua-expert, config-expert, protocol-agent — they have no V3R implementation tasks. Round 1 advisory work is complete.

**Bug report file flag:** BUG-005 (newly discovered) needs a formal report file at `claude/project-work/companion-rez/bugs/BUG-005-companion-auto-dismiss-timer-broken/report.md`. Per CLAUDE.md, the orchestrator (not architect) owns BUG-NNN file creation. Architect documents the discovery here in the V3R architecture section and surfaces the file-creation need to the orchestrator via the architecture-complete summary.


---

## V3R Architecture Refinements (Post c-expert Formal Addendum, 2026-04-29 late)

After the V3R architecture sections above were written, c-expert delivered a comprehensive Round 2 formal enumeration addendum (logged in agent-conversations.md as findings C-11 through C-16) that addresses the four open questions (Q1 fix-shape α/β/γ, Q2 dead-entity skips, Q3 regen scaling, Q4 group-operations ordering) and closes the G-5a git-audit carry-forward. This refinements section captures the corrections to the V3R architecture without rewriting the prior content. The refinements supersede where they conflict.

### Refinement R-1 — Fix W is ONE site, not two (supersedes Fix Specifications / Fix W α section)

c-expert C-11 (D.1, D.4, D.5) confirmed:
- `EntityList::AESpell()` (effects.cpp:1198) calls `caster->IsAttackAllowed(target, true)`
- `SpellOnTarget` (spells.cpp:3920) ALSO calls `caster->IsAttackAllowed(spelltar, true)`
- **Both call sites resolve through the same base `Mob::IsAttackAllowed` function.** Fixing the base function once covers both call sites.

c-expert D.4 explicitly: "`IsPetOwnerOfClientBot()` filter — Not applicable as a standalone fix — too narrow (only covers one spell target type). Fix α covers all detrimental AoE."

**Updated Fix W spec:** ONE site, not two. Implementation surface reduced from "~10-15 lines C++ across 2 sites" to "~10-15 lines C++ at 1 site."

**Updated Implementation Sequence — V3R.3 task description:** "Implement Fix W α: single-site IsCompanion-aware AoE exclusion in `Mob::IsAttackAllowed` `_CLIENT vs _NPC` matrix at aggro.cpp:867. Both `EntityList::AESpell` and `SpellOnTarget` call this function — single fix covers all detrimental AoE paths. ~10-15 lines C++ in one file."

### Refinement R-2 — Fix W α code sketch with cross-group-member-companion exclusion (supersedes prior Fix W α Site 1 spec)

c-expert C-12 provided a precise code sketch for Fix W at `aggro.cpp:867` that handles BOTH "owner's own companion" AND "group member's companion" via the same branch:

```cpp
else if(_NPC(mob2)) {
    // Block client from attacking its own companion or a group member's companion
    if (mob2->IsCompanion() &&
        mob2->CastToNPC()->CastToCompanion()->GetOwnerCharacterID() != 0) {
        if (mob1->IsClient()) {
            auto* c = mob1->CastToClient();
            auto* grp = c->GetGroup();
            Companion* comp = mob2->CastToNPC()->CastToCompanion();
            if (comp->GetOwnerCharacterID() == c->CharacterID()) {
                return false;
            }
            if (grp && grp->IsGroupMember(mob2)) {
                return false; // companion of a group member
            }
        }
    }
    return true;
}
```

This is BETTER than the prior Round 3 architect specification which only checked the immediate owner. Cross-group-member companion exclusion is the correct extended behavior — a multi-player party A's caster shouldn't AoE-hit party member B's companion either.

**c-expert is NOT writing the final fix code** — the sketch shows the pattern and scope for engineer reference. The exact line edit is for V3R.3 implementation.

### Refinement R-3 — Fix shape β fully ruled out with 9-side-effect enumeration (extends V3R-D4)

c-expert C-11 enumerated NINE unintended side-effects of fix shape β (SetOwnerID on companions during Spawn):

| β risk | Surface | Impact |
|---|---|---|
| 1 | `Mob::GetOwner()` requires `GetPetID()==GetID()` mismatch | Permanent inconsistency between `HasOwner()` and `GetOwner() != null` |
| 2 | `attack.cpp:2631-2656` kill credit | Companion kills give NO XP to player (existing comment at line 2657 explicitly notes the workaround for the gap β re-introduces) |
| 3 | `npc.cpp:2239-2262` FillSpawnStruct | `SetPetOwnerClient(true)` set as side-effect of `is_pet=1` path |
| 4 | `entity.cpp:708-713` AddNPC zone-load | `owner->SetPetID(npc->GetID())` overwrites real pet's petid |
| 5 | `npc.cpp:583-594` NPC::Process depop | Clears petid on companion during depop |
| 6 | `spells.cpp:2413` CazicTouch | Cazic Touch on companion redirects to owner client |
| 7 | `spells.cpp:4075-4087` blocked pet buffs | Blocked pet buffs would fire for companions |
| 8 | `spells.cpp:3761` buff sync packet | Every buff applied to companion triggers `SendPetBuffsToClient()` |
| 9 | `npc.cpp:672` HP regen branch | Companions fall into owned-pet regen branch instead of NPC OOC regen branch |

**V3R-D4 reaffirmed with stronger backing.** The 9-side-effect enumeration is exactly the V3R Architecture Mandate "fix that subtly breaks adjacent functionality" pattern in microcosm. β rejected.

### Refinement R-4 — BUG-003 narrative refinement (supersedes Joint Root-Cause Analysis BUG-003 row)

c-expert C-14 ran the git audit on `Companions:CompanionManaRegenMult`. **Result: the rule has been at default value 100 across ALL commits in git history.** It was never set to a higher value and reset.

This refines the BUG-003 narrative:
- The G-10 hypothesis ("rule-tuning divergence — player has 1.75x, companion has 1.0x") still stands as the leading explanation for the structural gap
- The user's "back to being extremely slow" framing is now SHARPER: it's NOT "a prior fix was reset." It's likely "the user's perception of regen parity has degraded over time as the player's `Character:ManaRegenMultiplier=175` was tuned higher without matching the companion multiplier"
- **Branch B-rule fix narrative is "introducing parity," not "restoring a regressed value"**

c-expert C-15 confirmed at the C++ level: NO scaling factor in `Companion::CalcManaRegen()` depends on V2-touched state. `spellbonuses.ManaRegen` and `itembonuses.ManaRegen` are restored by Load() → CalcBonuses() in the rez path. `aabonuses.ManaRegen` is always 0 for companions. Group membership and owner pointer are NOT consulted by `CalcManaRegen`. **Four-advisor convergence on BUG-003 cleanly closed at the C++ level.**

### Refinement R-5 — Q4 confirms Fix A has zero Lua blast radius (extends V3R-D7 / closes lua-expert L-2)

c-expert C-16 enumerated `Group::AddMember`, `MemberZoned`, `GroupMessage`, `GroupCount`:

- `Group::GroupMessage` iterates `members[]` (pointer array) via `ValidateMember(i)` — does NOT iterate `membername[]`
- `Group::GroupCount` counts non-empty `membername[i]` slots — does NOT check `members[]`
- `Group::IsGroupMember`, `Group::GetMember` ALL use `members[]` (pointer array)
- Fix A's `membername[i]` clear ONLY affects `GroupCount` over-counting and `AddMember` name-collision-check blocking re-join (both correct fixes)

**lua-expert L-2 carry-forward CLOSED.** Fix A has zero Lua-callable blast radius. All Lua-exposed group methods use the pointer array, not the string array.

---

## Updated Open Questions (post c-expert addendum)

| # | Question | Status |
|---|---|---|
| V3R-Q1 | `Companions:CompanionManaRegenMult` history audit | **CLOSED** (C-14): Always 100 across git history. Branch B-rule narrative is "introducing parity," not "restoring." |
| V3R-Q2 | HP regen parallel question | Still pending config-expert follow-up 2 |
| V3R-Q3 | data-expert SQL column name verification | Still pending data-expert |
| V3R-Q4 | NPC:OOCRegen vs Companions:OOCRegenPct interaction | Still empirical at V3R-6 validation time |
| V3R-Q5 | protocol-agent formal structured enumeration | Still pending; pre-findings P-1/P-2/P-3 cover substantive needs; non-blocking |
| **V3R-Q6 (NEW)** | Q4 Fix A Lua blast radius | **CLOSED** (C-16): Zero Lua blast radius confirmed |
| **V3R-Q7 (NEW)** | β risk vs α scope | **CLOSED** (C-11): β fully ruled out with 9-side-effect enumeration |


---

## V3R Architecture Refinements II (Post config-expert Follow-ups, 2026-04-29 late)

config-expert delivered Follow-ups 1 and 2 with a **critical correction to the G-10 hypothesis** plus a confirmed HP regen gap (also predates V2 but materially affects V3R BUG-003 scope). This refinements section supersedes the prior BUG-003 narrative where it conflicts.

### Refinement R-6 — G-10 hypothesis REFUTED: companions already get `Character:ManaRegenMultiplier` (supersedes BUG-003 row in Joint Root-Cause Analysis)

config-expert read `Companion::CalcManaRegen()` at `companion.cpp:1548-1549`:

```cpp
regen = (regen * RuleI(Character, ManaRegenMultiplier)) / 100;
regen = (regen * RuleI(Companions, CompanionManaRegenMult)) / 100;
```

Companions apply BOTH multipliers sequentially. The 1.75x player multiplier IS already being applied to companion mana regen. The G-10 hypothesis ("companions miss the 1.75x because that rule only applies to Characters") is INCORRECT.

**Updated BUG-003 diagnosis tree:**
- ~~Branch (d): Rule-tuning divergence~~ — REFUTED by code inspection
- Branch (a): Actual server-side regen broken at code level — **RANKED HIGHER** (no longer LOW)
- Branch (b): Misperception / freshly-rezzed climb from 0 mana — Still PLAUSIBLE
- Branch (c): Indirect via buff loss (lua-expert L-8) — Still PLAUSIBLE-LOW

### Refinement R-7 — Test 1.5 RE-FRAMED as code-path diagnostic, not fix candidate (supersedes V3R-Empirical-1 Test 1.5 + decision matrix)

The `Companions:CompanionManaRegenMult` rule bump is no longer a fix candidate — bumping it to 175 would over-scale (1.75x × 1.75x = 3.06x effective). **The bump test is now a DIAGNOSTIC** for whether the companion is hitting `Companion::CalcManaRegen()` at all post-V2.

**Revised Test 1.5:** Bump `CompanionManaRegenMult` from 100 to 200 (giving 2x scaling on top of existing 1.75x — clear visible signal). `#rules reload` (or `#rules set <Rule> <Value>` for transient test). Observe.

| Test 1 | Test 1.5 (corrected) | Verdict |
|---|---|---|
| ≥100/report | (skip Test 1.5) | **Branch B-misperception** — regen working correctly. Close BUG-003 with runbook note. No V3R action. |
| ≤50/report | Regen DOUBLES at bumped value | CalcManaRegen() being hit correctly. Branch (b) misperception or freshly-rezzed-from-zero is the explanation. **Restore rule to 100; close BUG-003 as misperception.** |
| ≤50/report | Regen UNCHANGED at bumped value | CalcManaRegen() being BYPASSED. V2 broke the custom regen path. **Branch (a) confirmed — escalate to c-expert for full NPC::Process() regen-path trace; descope from V3R to follow-up bugfix.** |

**There is NO Branch B-rule outcome anymore for mana regen.** The rule bump is purely diagnostic. The mana fix path collapses to: misperception (close) or actual code regression (follow-up bugfix).

### Refinement R-8 — HP regen gap is REAL and predates V2 (NEW finding to add to BUG-003 / V3R scope)

config-expert grep'd `HPRegenMultiplier` across all zone source files:

| Entity | Source file | Multiplier applied? |
|---|---|---|
| Client | client_mods.cpp:295, :311 | YES — `Character:HPRegenMultiplier` |
| Bot | bot.cpp:6334, :6731 | YES |
| Merc | merc.cpp:444, :453 | YES |
| **Companion** | `Companion::CalcHPRegen()` at companion.cpp:1493-1506 | **NO — NOT applied** |

This is a real structural gap. Bots, Mercs, and Clients ALL apply `Character:HPRegenMultiplier=200` (2x). Companions don't. The user's report explicitly mentions both HP and mana being slow ("Mana and health regen seem to be screwed up again"). **HP regen has a real, asymmetric gap; mana regen does not.**

**This gap predates V2** (CalcHPRegen has never applied this multiplier), but the user noticed it during sustained-play windows post-V2 alongside BUG-002/003/004.

| Entity | HP regen multiplier | Mana regen multiplier |
|---|---|---|
| Player (Client) | 2x (applied) | 1.75x (applied) |
| Bot | 2x (applied) | 1.75x (assumed) |
| Merc | 2x (applied) | 1.75x (assumed) |
| Companion | **1x (NOT applied)** | 1.75x (applied) |

### Refinement R-9 — V3R-D12 (NEW): Add HP regen parity fix to V3R scope conditional on empirical confirmation

**Architect decision V3R-D12:** Add HP regen parity fix to V3R scope, but ONLY as an empirical-confirmed fix per Mandate 3. The V3R-Empirical-1 protocol must include an HP regen Test 1 + Test 1.5 parallel to the mana regen tests. If empirical confirms the user perceives slow HP regen, the fix is small. If empirical shows HP regen perception is fine, descope to follow-up.

**Fix shape options for HP regen:**

| Option | Surface | Pros | Cons |
|---|---|---|---|
| **α-HP (PREFERRED)** | One-line C++ in `Companion::CalcHPRegen()` to apply `Character:HPRegenMultiplier` | Matches Bot/Merc/Client pattern; zero new rules; minimum surface | Removes ability to tune companion HP regen separately from player |
| β-HP | New `Companions:CompanionHPRegenMult` rule + apply in `CalcHPRegen()` | Parallel to `CompanionManaRegenMult`; operator-tunable | Introduces new rule + ruletypes.h entry + rule_values INSERT |

**Architect lean: Option α-HP (one-line C++).** Per V3R minimum-surface principle. The `Character:HPRegenMultiplier` rule already exists; companions should be aligned with Bot/Merc/Client behavior pattern.

### Refinement R-10 — V3R-Empirical-1 protocol expanded to cover BOTH HP and mana

The protocol now has 8 substantive tests (not 4):

| Test | Purpose |
|---|---|
| Test 1-mana | Mana regen at full mana, current rules — establish baseline |
| Test 1.5-mana (diagnostic) | Bump `CompanionManaRegenMult` to 200; does mana regen double? |
| Test 1-hp | HP regen at full HP, current rules — establish baseline |
| Test 1.5-hp (proposed fix verification) | If V3R-D12 α-HP fix is applied, re-run Test 1-hp; does HP regen now scale at 2x? |
| Test 2 | Drain-and-climb (`#set mana 0` / `#damage`) — discriminates climb-from-zero |
| Test 3 | Post-rez (Jimble auto-rez) — discriminates rez-path degraded regen |
| Test 4 (optional) | Buff state — discriminates buff-loss contribution |

The mana side discriminates among Branch B-misperception / Branch A-code-regression. The HP side discriminates whether α-HP fix is needed and effective. Combined, the protocol covers both halves of the user's "Mana and health regen seem to be screwed up" report.

### Refinement R-11 — V3R Implementation Sequence updated for V3R-D12

**Conditional V3R.3.5 (HP regen parity fix):** If V3R-Empirical-1 HP test confirms user perceives slow companion HP regen, c-expert applies α-HP one-line change in `Companion::CalcHPRegen()` to apply `Character:HPRegenMultiplier`. Tested via Test 1.5-hp post-fix.

**This task is conditional and architect-decided at V3R.7.** It does NOT extend the current V3R surface unless empirical validates the gap. Per V3R-D6, code regressions confirmed by empirical test go to follow-up bugfix; only the α-HP one-line C++ change for the structural gap (not a regression) ships in V3R if confirmed.

### Updated Open Questions (post config-expert follow-ups)

| # | Question | Status |
|---|---|---|
| V3R-Q1 (history audit) | CLOSED (C-14): always 100 in git history |
| V3R-Q2 (HP regen parallel) | **CLOSED (G-16):** YES — real gap; α-HP one-line C++ fix in `Companion::CalcHPRegen()` to apply `Character:HPRegenMultiplier`, conditional on V3R-Empirical-1 HP test confirmation |
| V3R-Q3 (SQL column name) | Still pending data-expert |
| V3R-Q4 (NPC:OOCRegen interaction) | Still empirical at V3R-6 |
| V3R-Q5 (protocol-agent formal) | Still pending; non-blocking |
| V3R-Q6 (Q4 Lua blast radius) | CLOSED (C-16): zero |
| V3R-Q7 (β risk enumeration) | CLOSED (C-11): 9 side-effects, β rejected |
| **V3R-Q8 (NEW)** | G-10 mana hypothesis | **REFUTED (G-14):** companions DO get `Character:ManaRegenMultiplier`; no mana tuning gap; Test 1.5 reframed as diagnostic |
| **V3R-Q9 (NEW)** | HP regen parity fix shape (α-HP vs β-HP) | **DECIDED (V3R-D12):** α-HP one-line C++ preferred over β-HP new rule |


---

## V3R Architecture Refinements III (Post protocol-agent Formal Enumeration, 2026-04-29 late)

protocol-agent delivered the formal Round 1 structured enumeration (26 consumers across 7 areas). **Round 1 is now FULLY CLOSED for all five advisors.** The formal enumeration independently confirms all prior advisor convergences and surfaces one new gap.

### Refinement R-12 — Five-advisor convergence reaffirmed for all four bugs

| Bug | Convergence at Round 1 close |
|---|---|
| BUG-002 | c-expert C-1 + protocol-agent P-1 + protocol-agent A.1/G.1 — three independent reads |
| BUG-005 | c-expert C-5 only (single-advisor discovery, 90% confidence; protocol-agent did not enumerate the timer specifically because it's an internal timer state, not a wire-format consumer) |
| BUG-004 | c-expert C-2 + config-expert G-3 + data-expert D-3 + protocol-agent C.1/F.1 — four independent reads |
| BUG-003 | c-expert C-3 + lua-expert L-1 + config-expert G-5 + data-expert D-9 + protocol-agent D.3/G.5 — five independent reads |

All Round 1 verdicts hold. The architecture is on a five-advisor consensus.

### Refinement R-13 — NEW gap flagged: A.3 SendArmorAppearance on rez path

protocol-agent finding A.3: `EntityList::AddCompanion()` at `entity.cpp:4047-4076` does NOT call `SendArmorAppearance()`. `EntityList::AddNPC()` at `entity.cpp:737` does. Pre-V2 rez path used `AddNPC` (→ SendArmorAppearance) → companion appearance correct post-rez. Post-V2 rez path uses `AddCompanion` (→ NO SendArmorAppearance) → companion may render naked/default after rez.

**This is NOT a V3R-scope bug.** It's a visual/cosmetic concern not reported by the user. The rezzed companion's combat behavior, regen, AoE filtering, etc. are all unaffected. Decision: V3R-D13 (NEW) — flag for V3R-8 multi-rez cycle game-tester scenario verification only. NOT a V3R fix surface.

**V3R-D13 (NEW):** A.3 SendArmorAppearance gap is NOT in V3R scope unless either:
1. V3R-8 multi-rez cycle scenario reveals visible armor regression in-game → file follow-up bugfix or expand V3R
2. c-expert confirms `ResurrectFromCorpse` does NOT handle armor appearance elsewhere → file follow-up bugfix

Adding to V3R-8 scenario: "After each rez cycle, observe companion's visual appearance — does the companion render its equipped armor, or does it appear naked/default?"

### Refinement R-14 — P-7 finding: V2 Fix B is a NET protocol correctness IMPROVEMENT

protocol-agent finding P-7: V2 Fix B brought three protocol-correctness improvements to the rez path:
- `NPC=0` override now applied (was `NPC=1` via AddNPC pre-V2)
- `is_pet=0` override applied
- Name normalization applied

These are CORRECTNESS improvements, not regressions. Pre-V2 rezzed companions had `NPC=1` and `is_pet` undefined — a less-correct wire-format state.

**Architecture impact:** Strengthens V3R-D4 (fix shape α over β) — β (SetOwnerID) would NOT be "restoring a pre-V2 state." Companions have NEVER called SetOwnerID(). The 9-side-effect blast radius c-expert enumerated in C-11 is the full unmitigated risk.

### Refinement R-15 — P-6 question RESOLVED via cross-reference

protocol-agent flagged: "did pre-V2 manual AddNPC path call SetOwnerID on companions? If yes → V2 regression. If no → pre-existing gap."

**Resolution via cross-reference to c-expert C-11 β-risk-2:** The comment at `attack.cpp:2657` explicitly notes "Companions use m_owner_char_id / GetCompanionOwner() rather than the standard Mob ownerid field, so HasOwner() returns false for them." This is a long-standing design choice — companions have NEVER called `SetOwnerID()` since the system was designed.

**P-6 verdict: BUG-004 is a PRE-EXISTING gap, NOT a V2 regression.** Reaffirmed via five-advisor convergence at Round 1 close.

### Updated Open Questions (Round 1 fully closed)

| # | Question | Status |
|---|---|---|
| V3R-Q1 | History audit | CLOSED (C-14) |
| V3R-Q2 | HP regen parallel | CLOSED (G-16) |
| V3R-Q3 | SQL column name | Still pending data-expert |
| V3R-Q4 | NPC:OOCRegen interaction | Still empirical at V3R-6 |
| V3R-Q5 | protocol-agent formal enumeration | **CLOSED (P-4 through P-8)** |
| V3R-Q6 | Q4 Lua blast radius | CLOSED |
| V3R-Q7 | β risk enumeration | CLOSED |
| V3R-Q8 | G-10 mana hypothesis | REFUTED (G-14) |
| V3R-Q9 | HP regen fix shape | DECIDED (V3R-D12 α-HP) |
| **V3R-Q10 (NEW)** | A.3 SendArmorAppearance gap | **FLAGGED for V3R-8 game-tester scenario verification (V3R-D13)** |

### V3R Round 1 Close Summary

**All five advisors fully closed.** No outstanding advisor work. No outstanding open questions block V3R implementation. Three substantive late refinements absorbed (data-expert D-11/D-13 SQL polling correction during Round 1, c-expert C-11–C-16 formal addendum, config-expert G-14–G-17 G-10 refutation + HP regen gap, protocol-agent P-4–P-8 formal enumeration with A.3 gap discovery). All refinements either confirmed prior decisions or surfaced new findings that have been integrated into the architecture without changing the strategic shape.

The V3R architecture is **MAXIMALLY CONSOLIDATED** across all advisor inputs and ready for user approval.


---

## V3R Architecture Refinements IV (Post c-expert Section D Supplement, 2026-04-29 late)

c-expert delivered the Section D supplement closing out the lua-expert L-5 cross-reference question with definitive code-grounded specificity. This is the **last analytical close-out on BUG-004** before user approval.

### Refinement R-16 — `Mob::IsAttackAllowed` and `EntityList::AESpell` BOTH have ZERO group-membership reads

c-expert C-17 traced the full execution flow of `Mob::IsAttackAllowed` (15 sequential checks). c-expert C-18 traced the full per-mob filter chain in `EntityList::AESpell` (11 sequential checks). **Neither calls `IsGroupMember`, `SameGroup`, `GetGroup`, `members[]`, `membername[]`, or any Group struct.** The AoE filter is purely type-matrix + ownerid/petid + faction + LoS.

### Refinement R-17 — Fix A is COMPLETELY IRRELEVANT to BUG-004 (DEFINITIVE)

c-expert C-19: BUG-004 reproduces identically for live recruited companions (group state fully populated), rezzed companions post-V2 (group state restored via Spawn), AND dead companions pre-V2 (hypothetical, group state stale). The AoE filter is blind to group membership for any entity type.

**No dead-then-rezzed transient case exists in the AoE pipeline.** Fix A's `membername[]` clear has zero effect on BUG-004's reproduction. The lua-expert L-5 cross-reference question is definitively closed: Fix A is irrelevant.

### Refinement R-18 — Fix α is NECESSARY AND SUFFICIENT at single site

c-expert C-20: Fix α at `aggro.cpp:867` (within the `_CLIENT vs _NPC` matrix branch) is the complete fix. The fix only needs to address the alive case because dead-companion-as-corpse is excluded by earlier `_NPCCORPSE` macro filters before reaching `IsAttackAllowed`.

This validates the Round 3 fix-shape decision and the c-expert C-12 code sketch as the canonical implementation.

### Refinement R-19 — `entity.cpp:5636` cone AoE precedent is structural inspiration, NOT implementation reference

c-expert C-21: `GetTargetsForConeArea` at `entity.cpp:5636` DOES have `!ptr->IsCompanion()` filter. But this is a DIFFERENT code path from `AESpell` — used only by cone-shaped AoE spells.

**Existing inconsistency:** cone AoE excludes companions (entity.cpp:5636 path) while `AESpell` doesn't (effects.cpp:1199 path). **Fix α brings AESpell into consistency with the cone path.** After V3R ships, both AoE paths will uniformly exclude owner's companions.

The cone AoE precedent is structural inspiration for the IsCompanion-exclusion pattern, not an implementation reference. The actual implementation site is `aggro.cpp:867`, not `entity.cpp:5636`.

### Updated Open Questions (final close-out)

| # | Question | Status |
|---|---|---|
| V3R-Q1 | History audit | CLOSED |
| V3R-Q2 | HP regen parallel | CLOSED |
| V3R-Q3 | SQL column name | Still pending data-expert |
| V3R-Q4 | NPC:OOCRegen interaction | Empirical at V3R-6 |
| V3R-Q5 | protocol-agent formal | CLOSED |
| V3R-Q6 | Q4 Lua blast radius | CLOSED |
| V3R-Q7 | β risk enumeration | CLOSED |
| V3R-Q8 | G-10 mana hypothesis | REFUTED |
| V3R-Q9 | HP regen fix shape | DECIDED (V3R-D12 α-HP) |
| V3R-Q10 | A.3 SendArmorAppearance | FLAGGED for V3R-8 |
| **V3R-Q11 (NEW)** | **L-5 / AoE filter group-awareness** | **CLOSED (R-17): zero group reads, Fix A irrelevant** |
| **V3R-Q12 (NEW)** | **Fix α coverage scope (alive vs dead-rezzed transient)** | **CLOSED (R-18): alive case only is sufficient** |

### V3R Round 1 + Round 2 + All Refinements: COMPLETELY CLOSED

**All advisor analytical work is complete.** Five-advisor Round 1 closed; lua-expert L-5 sharpened question routed and definitively answered; all 12 open questions resolved or routed to empirical/follow-up. The V3R architecture is at FINAL consolidation. No further analytical refinements anticipated before implementation.

The architecture document now contains:
- Initial V3R section (post-Round-1)
- Refinements I (post c-expert formal addendum C-11–C-16)
- Refinements II (post config-expert follow-ups G-14–G-17)
- Refinements III (post protocol-agent formal enumeration P-4–P-8)
- Refinements IV (post c-expert Section D supplement C-17–C-21) ← this section

Plus full Round 1 enumeration text in agent-conversations.md, working artifacts in architect/context/ for rounds 2-5.


---

## V3R Architecture Refinements V (Post protocol-agent Round 1 Targeted Follow-up, 2026-04-29 final)

protocol-agent delivered FU-1 through FU-5 in response to the heartbeat-fan-out / group-update / m_owner / spawn-struct queries. **Two prior decisions are CORRECTED:** A.3 retracted, C-10 resolved. Two new positive findings further validate Fix B and the α fix-shape decision.

### Refinement R-20 — V3R-D13 REVERSED: A.3 SendArmorAppearance is NOT a real gap

protocol-agent's FU-1 retracts the earlier P-5 / R-13 / V3R-D13 finding. The rez path calls `Load()` → `LoadEquipment()` at `companion.cpp:3693` BEFORE `Spawn()` → `FillSpawnStruct()` at `companion.cpp:3703`. `LoadEquipment()` populates `m_equipment[]`; `FillSpawnStruct` reads `GetEquipmentMaterial()` from `m_equipment[]`. **The initial spawn packet already includes equipment textures via `equipment.Slot[i].Material`.**

The `SendArmorAppearance` call in AddNPC sent a follow-on `OP_WearChange` update, but the initial spawn packet from AddCompanion already carries the data. **Functionally equivalent for visual rendering — no naked rezzed companion regression.**

**V3R-D13 REVERSED.** No V3R-8 verification scenario needed for visual armor rendering. The A.3 line item in V3R-Q10 is closed as a non-issue.

### Refinement R-21 — C-10 atomic-rez coexistence concern RESOLVED

protocol-agent's FU-5 resolves c-expert's C-10 antagonistic-pass uncertainty. Corpses live in `corpse_list`, NOT `mob_list`. `EntityList::AESpell` iterates `GetCloseMobList()` on `mob_list`. The corpse is NOT in the AoE sweep target set during the Fix C coexistence window.

**No doubled AoE hit risk from the atomic-rez window.** C-10 is closed. The V3R-8 multi-rez cycle scenario can drop the "verify no double-AoE during rez moment" verification (low-priority defensive observation only).

### Refinement R-22 — NEW positive finding: Fix B fixed pre-V2 group-window-targeting name divergence

protocol-agent's FU-2 reveals an UNDOCUMENTED net positive of Fix B:
- Pre-V2: spawn packet `name = "Guard_Liben001"` (raw `MakeNameUnique` name); group window `membername = "Guard Liben"` (GetCleanName). **Diverged.** Titanium click-to-target in the group window silently failed.
- Post-V2 Fix B: `Companion::Spawn()` calls `strcpy(name, GetCleanName())` at `companion.cpp:2430-2431` BEFORE `AddCompanion`. **Names match.**

This is an additional protocol-correctness improvement that V2 brought. Provides further evidence that V2 was a net positive on the rez path. β (SetOwnerID) would not have addressed this issue; only Fix B's name-normalization did.

### Refinement R-23 — m_owner_char_id feeds ZERO packet-emission paths

protocol-agent's FU-3: `m_owner_char_id` is used only for AI logic, group join, `IsFriendlyTarget`, and DB queries. **No packet-emission paths.** Server-side ownership awareness for companions is purely internal to the AI/group/spell system; the Titanium client has no wire-format signal of companion ownership.

**Architectural implication:** The BUG-004 fix is necessarily purely server-side (Fix W α at `aggro.cpp:867`). No Titanium client changes possible or needed. V3R-D4 (α over β) reaffirmed yet again.

### Updated Open Questions (FINAL close-out)

| # | Question | Status |
|---|---|---|
| V3R-Q1 | History audit | CLOSED |
| V3R-Q2 | HP regen parallel | CLOSED |
| V3R-Q3 | SQL column name | Still pending data-expert (non-blocking) |
| V3R-Q4 | NPC:OOCRegen interaction | Empirical at V3R-6 (non-blocking) |
| V3R-Q5 | protocol-agent formal | CLOSED |
| V3R-Q6 | Q4 Lua blast radius | CLOSED |
| V3R-Q7 | β risk enumeration | CLOSED |
| V3R-Q8 | G-10 mana hypothesis | REFUTED |
| V3R-Q9 | HP regen fix shape | DECIDED |
| **V3R-Q10** | **A.3 SendArmorAppearance** | **CLOSED (R-20): not a real gap, V3R-D13 REVERSED** |
| V3R-Q11 | L-5 / AoE filter group-awareness | CLOSED |
| V3R-Q12 | Fix α coverage scope | CLOSED |
| **V3R-Q13 (NEW)** | **C-10 atomic-rez coexistence** | **CLOSED (R-21): corpses in corpse_list not mob_list, no AoE doubling possible** |

### V3R Architecture FINAL CONSOLIDATION POINT

**All advisor analytical work is complete.** Five-advisor Round 1 + Round 2 + five waves of refinements (I, II, III, IV, V) all integrated. **Two prior architecture decisions REVERSED based on late corrections** (V3R-D13 retracted; C-10 resolved). The architecture now reflects the most code-grounded, advisor-converged state achievable.

The architecture document contains:
- Initial V3R section (post-Round-1)
- Refinements I (post c-expert formal addendum C-11–C-16)
- Refinements II (post config-expert follow-ups G-14–G-17)
- Refinements III (post protocol-agent formal enumeration P-4–P-8)
- Refinements IV (post c-expert Section D supplement C-17–C-21)
- Refinements V (post protocol-agent Round 1 targeted follow-up P-9–P-13) ← this section

The strategic shape of the V3R fix is unchanged from the initial summary; the refinements only tightened scope (Fix W 2→1 site), corrected hypotheses (G-10 refuted), discovered new bugs (BUG-005), surfaced and then retracted concerns (A.3 / C-10), and added a conditional new fix (V3R-D12 α-HP). **No further refinements anticipated.**


---

## V3R Architecture Refinements VI (Post data-expert close-out, 2026-04-29 final-final)

data-expert delivered the last close-out items for V3R: SQL column name verification and a critical GM-command correction.

### Refinement R-24 — `owner_id` SQL column name VERIFIED CORRECT (V3R-Q3 closed)

data-expert confirmed via live schema query that the column in `companion_data` is `owner_id` (INT UNSIGNED, NOT NULL, indexed). The SQL snippets in D-13 / V3R-Empirical-1 are correct as written. **V3R-Q3 closed.**

### Refinement R-25 — `#reloadrules` DOES NOT EXIST; corrected to `#rules` family

**Architecture-document-wide correction.** I had documented `#reloadrules` across multiple V3R artifacts based on a guess. data-expert confirmed via `gm_commands/rules.cpp` that the correct command family is `#rules`:

| Subcommand | Behavior |
|---|---|
| `#rules set [Rule] [Value]` | in-memory only, reverts on zone restart (PREFERRED for transient testing) |
| `#rules setdb [Rule] [Value]` | in-memory + persists to DB (must be manually reverted) |
| `#rules reload` | reloads current ruleset from DB into memory |
| `#rules get [Rule]` | reads current in-memory value (use to verify) |

**Recommended Test 1.5 sequence (transient, safe):**

```
#rules set Companions:CompanionManaRegenMult 175
#rules get Companions:CompanionManaRegenMult   ← verify = 175
[run 4-cycle observation]
#rules set Companions:CompanionManaRegenMult 100
#rules get Companions:CompanionManaRegenMult   ← verify reverted = 100
```

**All instances of `#reloadrules` in V3R artifacts have been globally replaced with `#rules reload` (or `#rules set <Rule> <Value>` for transient test) via mechanical substitution.** Verification: 0 remaining `#reloadrules` references in architecture.md, status.md, round-3-fix-proposal-and-task-breakdown.md, round-4-validation-plan.md.

**Architect note — this was a `feedback_never_guess_commands.md` violation.** Per the user's standing feedback, "Never guess commands; check `claude/docs/gm-commands-reference.md` first or ask the user." The architect documented `#reloadrules` across the V3R artifacts without verifying. data-expert's catch is the discipline working as designed; the correction is mechanical and the V3R artifacts are now command-name-correct.

### Updated Open Questions (FINAL FINAL FINAL close-out)

| # | Question | Status |
|---|---|---|
| V3R-Q1 | History audit | CLOSED |
| V3R-Q2 | HP regen parallel | CLOSED |
| V3R-Q3 | SQL column name | **CLOSED (R-24): owner_id verified correct** |
| V3R-Q4 | NPC:OOCRegen interaction | Empirical at V3R-6 (non-blocking) |
| V3R-Q5 | protocol-agent formal | CLOSED |
| V3R-Q6 | Q4 Lua blast radius | CLOSED |
| V3R-Q7 | β risk enumeration | CLOSED |
| V3R-Q8 | G-10 mana hypothesis | REFUTED |
| V3R-Q9 | HP regen fix shape | DECIDED |
| V3R-Q10 | A.3 SendArmorAppearance | CLOSED (V3R-D13 reversed) |
| V3R-Q11 | L-5 / AoE filter group-awareness | CLOSED |
| V3R-Q12 | Fix α coverage scope | CLOSED |
| V3R-Q13 | C-10 atomic-rez coexistence | CLOSED |
| **V3R-Q14 (NEW)** | **#reloadrules existence** | **CLOSED (R-25): does not exist; replaced with `#rules reload` / `#rules set` family** |

### V3R Architecture FINAL FINAL FINAL CONSOLIDATION

**All 14 open questions resolved or routed to empirical.** All 5 advisors fully closed (Round 1 + Round 2 + all targeted follow-ups). The V3R architecture is at maximum consolidation; no further analytical refinements anticipated; all command names verified.

The architecture document contains:
- Initial V3R section (post-Round-1)
- Refinements I (post c-expert formal addendum C-11–C-16)
- Refinements II (post config-expert follow-ups G-14–G-17)
- Refinements III (post protocol-agent formal enumeration P-4–P-8)
- Refinements IV (post c-expert Section D supplement C-17–C-21)
- Refinements V (post protocol-agent Round 1 targeted follow-up P-9–P-13)
- Refinements VI (post data-expert close-out D-14–D-15) ← this section


---

## V3R Architecture Refinements VII (Post c-expert G-5a Git Audit, 2026-04-29 final)

c-expert ran the final close-out audit on `Companions:CompanionManaRegenMult` history.

### Refinement R-26 — V3R-Q1 / G-5a CLOSED definitively: rule was always at 100

Three independent git audit queries:

| Query | Finding |
|---|---|
| ruletypes.h diff history | Single commit `d553ed62d` (2026-03-10) introduces rule at default=100. No prior value; no subsequent change. |
| `git log -S 'CompanionManaRegenMult' --all` | Two commits total: `d553ed62d` introducing commit + `627aed644` (BUG-032 unrelated ruletypes.h touch). Rule never set to non-100. |
| akk-stack SQL seed/migration search | Zero hits. No SQL migration touched this rule. |

**`Companions:CompanionManaRegenMult` was introduced at 100 on 2026-03-10 and has NEVER been changed.** No "regression from a prior higher value" exists in the git record.

### Refinement R-27 — Architecture narrative for BUG-003 mana fully grounded

c-expert's interpretation: the user's "for a long time the pace of their regen closely matched my own" baseline was `CalcManaRegen()`'s introduction in commit `d553ed62d` (the meditate formula). The user's comparison baseline is the meditate formula itself, not a multiplier value.

**The user's "back to being extremely slow" report has two possible explanations:**
- **Branch B-misperception:** meditate formula IS working correctly; user's perception of "matching" was always against an unscaled baseline. The 1.75x player multiplier was added/tuned higher AFTER 2026-03-10, creating the gap that finally became visible.
- **Branch A-code-regression:** an actual code regression introduced AFTER 2026-03-10 by V2 that BYPASSES `CalcManaRegen()` entirely.

The Test 1.5 diagnostic (`#rules set Companions:CompanionManaRegenMult 200`) discriminates: if regen doubles, CalcManaRegen is firing (Branch B-misperception). If regen unchanged, CalcManaRegen is bypassed (Branch A — escalate to follow-up bugfix per V3R-D6).

### Updated Open Questions (FINAL FINAL FINAL FINAL close-out)

| # | Question | Status |
|---|---|---|
| V3R-Q1 | History audit | **CLOSED (R-26): rule was always at 100; no regression from prior higher value** |
| V3R-Q2 | HP regen parallel | CLOSED |
| V3R-Q3 | SQL column name | CLOSED |
| V3R-Q4 | NPC:OOCRegen interaction | Empirical at V3R-6 (non-blocking) |
| V3R-Q5 | protocol-agent formal | CLOSED |
| V3R-Q6 | Q4 Lua blast radius | CLOSED |
| V3R-Q7 | β risk enumeration | CLOSED |
| V3R-Q8 | G-10 mana hypothesis | REFUTED |
| V3R-Q9 | HP regen fix shape | DECIDED |
| V3R-Q10 | A.3 SendArmorAppearance | CLOSED (V3R-D13 reversed) |
| V3R-Q11 | L-5 / AoE filter group-awareness | CLOSED |
| V3R-Q12 | Fix α coverage scope | CLOSED |
| V3R-Q13 | C-10 atomic-rez coexistence | CLOSED |
| V3R-Q14 | #reloadrules existence | CLOSED |

**14 of 14 open questions resolved. Only V3R-Q4 (NPC:OOCRegen interaction) remains routed to empirical verification at V3R-6 — non-blocking for architecture approval.**

### V3R Architecture FINAL ABSOLUTE CONSOLIDATION

**Seven refinement sections (I through VII) capturing the complete advisor input chain:**
1. Refinements I (post c-expert formal addendum C-11–C-16)
2. Refinements II (post config-expert follow-ups G-14–G-17)
3. Refinements III (post protocol-agent formal enumeration P-4–P-8)
4. Refinements IV (post c-expert Section D supplement C-17–C-21)
5. Refinements V (post protocol-agent Round 1 targeted follow-up P-9–P-13)
6. Refinements VI (post data-expert close-out D-14–D-15)
7. Refinements VII (post c-expert G-5a git audit C-22–C-24) ← this section

Strategic shape NEVER changed across the seven refinement waves; each wave either tightened scope, closed an open question, or grounded an existing decision in deeper evidence. The architecture is **maximally code-grounded, advisor-converged, and historically-verified**.


---

## V3R USER-APPROVED FINAL SCOPE (2026-04-29) — BUG-003 DESCOPED

The user has reviewed the V3R architecture and given a revised approval. **BUG-003 (both mana and HP sides) is fully descoped from V3R and moved to a future separate "companion regen mechanics deep dive" bugfix.** This section captures the user-approved revised scope and supersedes any prior V3R section content where BUG-003 was in scope.

### User Decisions (Locked)

| # | Decision | Rationale |
|---|---|---|
| 1 | **BUG-004 fix shape α** | Architect-recommended; per V3R Mandate principle of minimum blast radius |
| 2 | **BUG-003 mana — SKIP for V3R** | User will run a separate project for a deeper dive on companion regen mechanics |
| 3 | **BUG-003 HP — SKIP for V3R** | User wants both regen sides (mana + HP) handled together in the separate regen-mechanics project |
| 4 | **V3R-Empirical-1 protocol — SKIP** | Follows naturally from skipping both BUG-003 sides |
| 5 | **`Companions:AoEExcludesCompanions` rule — REJECTED** | Architect-recommended; per V3R minimum-surface principle, hardcoded behavior locked |
| 6 | **Overall plan — APPROVED with the revisions above** | Ship locked-down BUG-002/004/005 fixes now without BUG-003 distraction |

### Final V3R Scope (after user revisions)

**IN scope:**
- **Fix V Option A** for BUG-002 + BUG-005 (`Companion::Process()` restructure, ~25 lines C++)
- **Fix W α** single-site for BUG-004 (`Mob::IsAttackAllowed` at aggro.cpp:867, ~10-15 lines C++ per c-expert C-12 sketch)
- **3 new TDD tests** in Suite 36: V.1 (heartbeat-for-dead), V.2 (despawn-timer-for-dead), W.1 (aoe-excludes-owner-companion). **V.3 (alive-companion-regen-regression-guard) is REMOVED** since BUG-003 is descoped.
- **Sustained-play game-tester scenarios for BUG-002, BUG-004, BUG-005:** V3R-1 (heartbeat PRIMARY), V3R-2 (auto-dismiss PRIMARY), V3R-3 (AoE friend/foe PRIMARY), V3R-5 (sustained combat 5+ min), V3R-7 (multi-zone cycle), V3R-8 (multi-rez cycle), V3R-9 (sustained AoE encounter)
- **Adjacent-system regression coverage** for the customized subsystems Fix V and Fix W touch (Companion::Process tick consumers, IsAttackAllowed consumers, m_death_despawn_timer, m_ping_timer)

**OUT of V3R scope (descoped to future companion-regen-mechanics bugfix):**
- ~~V3R-Empirical-1 4-test protocol~~ — REMOVED
- ~~V3R-D12 conditional α-HP one-line C++ fix~~ — REMOVED
- ~~Test 1.5 mana code-path diagnostic via `#rules set Companions:CompanionManaRegenMult`~~ — REMOVED
- ~~V3R-6 long-duration sit regen scenario (BUG-003 baseline)~~ — REMOVED (V3R-6 number is freed; remaining scenarios renumber)
- ~~V.3 alive-companion-regen-regression-guard test~~ — REMOVED (regen path is no longer being modified by V3R)
- ~~Empirical-Test-4 buff-state branch~~ — REMOVED

### Final V3R Implementation Sequence (post-user-revision)

| # | Task | Agent | Dependencies | Notes |
|---|---|---|---|---|
| V3R.1 | Write 3 failing-first tests in Suite 36: V.1 (heartbeat-for-dead), V.2 (despawn-timer-for-dead), W.1 (aoe-excludes-owner-companion). Build the test binary; verify all 3 FAIL pre-fix. | c-expert | None | TDD red commit before any fix |
| V3R.2 | Implement Fix V Option A: restructure `Companion::Process()` top-section. `bool is_dead = (GetHP() <= 0);` capture + `if (!is_dead)` guards on AI-dispatch sections. Keep B.1 heartbeat AND B.2 `m_death_despawn_timer.Check()` UNCONDITIONAL. ~25 lines C++. | c-expert | V3R.1 | Replaces V2 Fix R4 alive-guard |
| V3R.3 | Implement Fix W α: single-site IsCompanion-aware AoE exclusion in `Mob::IsAttackAllowed` `_CLIENT vs _NPC` matrix at `aggro.cpp:867`. Surgical insert per c-expert C-12 code sketch (handles both owner's own companion AND group member's companion). ~10-15 lines C++. | c-expert | V3R.1 | Single site; c-expert C-12 sketch is the implementation pattern |
| V3R.4 | Rebuild zone binary. Re-run Suite 36 — verify V.1, V.2, W.1 PASS, all V1/V2 tests unchanged. Run full companion test suite. | c-expert | V3R.2 + V3R.3 | Build verification |
| V3R.5 | `make restart` from akk-stack/, then full server stack startup (loginserver / world / 8 dynamic zones per documented procedure). | infra-expert | V3R.4 | runtime |
| V3R.6 | In-game validation per V3R Validation Plan (post-revision): 7 sustained-play scenarios (V3R-1 heartbeat PRIMARY, V3R-2 auto-dismiss 30-min PRIMARY, V3R-3 AoE PRIMARY, V3R-5 sustained combat 5+min, V3R-7 multi-zone, V3R-8 multi-rez, V3R-9 sustained AoE). User confirms BUG-002 + BUG-005 + BUG-004 closed. | game-tester | V3R.5 | manual + sustained |
| V3R.7 | Commit and push V3R changes on `bugfix/companion-rez` in eqemu and claude repos. | c-expert | V3R.6 | git |

**Spawn list (revised):** c-expert (V3R.1, V3R.2, V3R.3, V3R.4, V3R.7), infra-expert (V3R.5), game-tester (V3R.6). **architect does NOT need to rejoin** (no V3R.7 BUG-003 decision step anymore — BUG-003 is descoped). **data-expert is NOT re-spawned** (no conditional V3R.6.5 rule UPDATE — empirical protocol descoped). **lua-expert / config-expert / protocol-agent** unchanged — no V3R implementation tasks.

### Final V3R Validation Plan (post-revision)

**Band 1 — Direct symptom validation:**
- V3R-1 — BUG-002 visibility heartbeat (PRIMARY)
- V3R-2 — BUG-005 auto-dismiss after 30 minutes (PRIMARY, slow scenario)
- V3R-3 — BUG-004 AoE friend/foe filter (PRIMARY)
- ~~V3R-4 — BUG-003 V3R-Empirical-1 4-test protocol~~ — REMOVED

**Band 2 — Sustained-play coverage:**
- V3R-5 — Sustained combat encounter (5+ minutes)
- ~~V3R-6 — Long-duration sit regen (3+ minutes)~~ — REMOVED (BUG-003 descoped)
- V3R-7 — Multi-zone cycle
- V3R-8 — Multi-rez cycle
- V3R-9 — Sustained AoE encounter

**Band 3 — Adjacent-system regression coverage:**

For each customized subsystem the V3R fix touches, at least one consumer beyond the symptom is tested. Updated matrix:

| Subsystem touched | Consumer scenario | Pass criterion |
|---|---|---|
| `Companion::Process()` AI tick (Fix V) | V3R-5 sustained combat: alive companion behaves normally throughout | Cleric stands when player engages; melee swings on attack-timer cadence; combat positioning correct |
| `Mob::IsAttackAllowed` AoE filter (Fix W) | V3R-3 PRIMARY + V3R-9 sustained AoE | Companion correctly excluded across multiple AoE casts; cross-group-member companions also excluded |
| `m_death_despawn_timer` (BUG-005, restored by Fix V) | V3R-2 PRIMARY (30-min wait) | Auto-dismiss fires correctly; rez interrupt correctly resets/disables timer |
| `m_ping_timer` heartbeat (BUG-002, restored by Fix V) | V3R-1 PRIMARY + V3R-5 sustained alive-stationary | Companion remains visible during dying-window AND during sustained alive-stationary combat |
| `Companion::IsAttackAllowed` companion-as-caster (UNCHANGED but adjacent) | V3R-5 sustained combat: companion casting beneficial spells on group | Group heals land on companions; companion-cast harmful spells still allowed against valid hostiles |

### Future Companion Regen Mechanics Bugfix (Known-Pending)

Per the user's decision 2 + 3, a separate bugfix workspace will handle BUG-003 mana + HP together as a deep-dive on companion regen mechanics. Suggested scope when that workspace is bootstrapped:

- **Empirical investigation:** measure actual companion mana + HP regen rates (via in-game `!status` polling or instrumented logging) under controlled scenarios — confirm whether `CalcManaRegen()` and `CalcHPRegen()` are exercising the expected code paths.
- **Code-path verification:** confirm whether companions hit the custom `Companion::CalcManaRegen()` / `Companion::CalcHPRegen()` paths or fall through to base NPC regen branches under all scenarios (sit/stand, in-combat/OOC, post-rez, pre-rez).
- **Multiplier asymmetry:** evaluate the structural gap between Client/Bot/Merc applying `Character:HPRegenMultiplier=200` and Companion not applying it — decide whether to align (one-line C++ in `Companion::CalcHPRegen`) or maintain the asymmetry intentionally with a `Companions:CompanionHPRegenMult` rule.
- **Visibility gap analysis:** investigate the user's "back to extremely slow" perception baseline against the actual measured regen rates — is the perception a misperception or a real regression?
- **Buff-state interaction:** test whether regen-boosting buffs (Spirit of Cheetah / Clarity / etc.) correctly persist or are correctly re-applied across Death/rez cycles.

The architecture context for this future bugfix is preserved in:
- This V3R section (Refinements II findings G-14 / G-16 documenting the mana hypothesis refutation and the HP regen structural gap)
- `architect/context/round-2-joint-root-cause-synthesis.md` (BUG-003 4-branch diagnosis tree)
- `architect/context/round-3-fix-proposal-and-task-breakdown.md` (Section 4 — original V3R-Empirical-1 protocol design, can serve as starting point)
- `architect/context/round-4-validation-plan.md` (Scenario V3R-4 design, can serve as game-tester scenario template)
- agent-conversations.md V3R section (D-9 protocol, D-13 4-test scenario, G-10/G-11/G-14/G-15/G-16 hypothesis evolution, C-22/C-23 git audit)

### Updated Decision Log

| # | Decision | Rationale |
|---|---|---|
| **V3R-D14 (NEW)** | **BUG-003 (both mana and HP) fully descoped from V3R; moved to future companion-regen-mechanics bugfix** | User decision (2026-04-29). User wants regen handled holistically in a dedicated workspace, not bundled with the locked-down BUG-002/004/005 fixes. Honors regression-discipline principle of not bundling speculative work with confirmed work. |
| **V3R-D15 (NEW)** | **`Companions:AoEExcludesCompanions` rule REJECTED; hardcoded behavior locked** | User decision (2026-04-29). Architect-recommended per minimum-surface principle. AoE exclusion of owner's own companion should always be the correct default; no operator-tuning toggle needed. |

### Updated Open Questions (post-user-revision)

| # | Question | Status |
|---|---|---|
| V3R-Q1 | History audit | CLOSED |
| V3R-Q2 | HP regen parallel | DEFERRED to future regen-mechanics bugfix |
| V3R-Q3 | SQL column name | CLOSED (was needed for Empirical protocol; now moot) |
| V3R-Q4 | NPC:OOCRegen interaction | DEFERRED to future regen-mechanics bugfix |
| V3R-Q5 | protocol-agent formal | CLOSED |
| V3R-Q6 | Q4 Lua blast radius | CLOSED |
| V3R-Q7 | β risk enumeration | CLOSED |
| V3R-Q8 | G-10 mana hypothesis | REFUTED (preserved as input to future regen-mechanics bugfix) |
| V3R-Q9 | HP regen fix shape | DEFERRED (V3R-D12 α-HP preserved as candidate for future regen-mechanics bugfix) |
| V3R-Q10 | A.3 SendArmorAppearance | CLOSED |
| V3R-Q11 | L-5 / AoE filter group-awareness | CLOSED |
| V3R-Q12 | Fix α coverage scope | CLOSED |
| V3R-Q13 | C-10 atomic-rez coexistence | CLOSED |
| V3R-Q14 | #reloadrules existence | CLOSED |

**14 of 14 open questions either resolved or deferred to the future regen-mechanics bugfix.** No outstanding question blocks V3R implementation.

### Final V3R Scope Summary (Locked)

| Bug | Status | Fix |
|---|---|---|
| BUG-002 visibility heartbeat | IN V3R | Fix V Option A (~25 lines C++) |
| BUG-003 mana | OUT (descoped to future regen-mechanics bugfix) | n/a |
| BUG-003 HP | OUT (descoped to future regen-mechanics bugfix) | n/a |
| BUG-004 player AoE hits companions | IN V3R | Fix W α single-site (~10-15 lines C++) |
| BUG-005 auto-dismiss timer broken | IN V3R | Same Fix V Option A (zero additional surface) |

**Total V3R surface (LOCKED):** ~35-40 lines C++ across 2 files (`companion.cpp` + `aggro.cpp`) + 3 new TDD tests + 7 sustained-play game-tester scenarios.

