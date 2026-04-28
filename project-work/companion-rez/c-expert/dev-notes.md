# Companion Rez — Dev Notes: c-expert

> **Feature branch:** `bugfix/companion-rez`
> **Agent:** c-expert
> **Task(s):** Triage C++ rez code path (architecture phase)
> **Date started:** 2026-04-27
> **Current stage:** Stage 1 Complete (Triage)

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

## Open Items

- [ ] Architect to decide: implement AC-2 (player corpse rez) in same pass or defer?
- [ ] Architect to decide: multi-target ordering policy (player-first vs. first-found)?
- [ ] lua-expert to confirm: no Lua-side changes needed for companion rez (the `SpellEffect::Revive` path is C++ only)
- [ ] data-expert to confirm: `companion_spell_sets` has rez spells loaded for Cleric (Suite 29.13 integration test)
- [ ] Run Suite 29 tests post-fix to confirm 29.14+ pass

---

## Context for Next Agent

The ROOT CAUSE is `zone/spells.cpp:2051`. The `ST_Corpse` target type validation requires `IsPlayerCorpse()` and rejects companion corpses before the rez effect fires. The fix is one added OR-condition.

All companion rez infrastructure (`Companion::ResurrectFromCorpse`, `AI_ResurrectDeadGroupMember`, post-combat timer, corpse metadata) was built during `companion-rerecruit` and is correct and complete. The `spell_effects.cpp:1720` path that routes to `Companion::ResurrectFromCorpse` exists and is correct — it just never runs because `spells.cpp` kills the spell first.

TDD: write Suite 29.14 (failing test proving companion corpse fails `ST_Corpse` check today), then fix `spells.cpp`, verify test passes, run full suite.
