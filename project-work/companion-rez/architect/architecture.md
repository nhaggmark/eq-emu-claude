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
