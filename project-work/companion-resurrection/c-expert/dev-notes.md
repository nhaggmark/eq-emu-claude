# Companion Resurrection System — Dev Notes: C Expert

> **Feature branch:** `feature/companion-resurrection`
> **Agent:** c-expert
> **Task(s):** 1-10, 12 (all C++ tasks)
> **Date started:** 2026-03-15
> **Current stage:** Build

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 1 | Add 5 new rules to `ruletypes.h` + SQL insert | — | Complete |
| 2 | Add companion metadata to Corpse class (`corpse.h/cpp`) | — | Complete |
| 3 | Strip loot from companion corpses + set companion data in `attack.cpp` | 2 | Complete |
| 4 | Extend `SpellEffect::Revive` in `spell_effects.cpp` for companion corpses | 2 | Complete |
| 5 | Add `GetCompanionCorpseByOwnerWithinRange()` to `entity.h/cpp` | 2 | Complete |
| 6 | Implement `ApplyDeathXPPenalty()` + call from `Death()` | 1 | Complete |
| 7 | Implement `ResurrectFromCorpse()` static method | 2,5,6 | Complete |
| 8 | Add rez delay timer + update `AI_IdleCastCheck()` | 1 | Complete |
| 9 | Implement full rez AI: `AI_ResurrectDeadGroupMember()`, `FindDeadGroupMemberCorpse()`, `SelectBestRezSpell()`, deity dialogue | 1,2,5,8 | Complete |
| 10 | Wire rez AI into `AI_Cleric()`, `AI_Paladin()`, `AI_Necromancer()` | 9 | Complete |
| 12 | Multiple-healer coordination: only highest-rez-capable companion attempts | 9 | Complete |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `common/ruletypes.h` | 1181-1250 | Companions category ends at line 1250 before RULE_CATEGORY_END. Add new rules here. |
| `zone/corpse.h` | 1-291 | Private section at 252+. m_is_player_corpse bool at 253. Must add m_companion_id and m_companion_owner_id to private section. IsPlayerCorpse() and IsNPCCorpse() already exist — add IsCompanionCorpse() alongside them. |
| `zone/corpse.cpp` | 51-174 | NPC Corpse constructor at line 51. Initializes m_is_player_corpse=false, m_character_id=0. Need to init m_companion_id=0, m_companion_owner_id=0 here. Also note the decay timer is overridden by npcCorpseDecayTimes at lines 142-153 — companion corpses need separate override to extend to DeathDespawnS. |
| `zone/spell_effects.cpp` | 1707-1720 | SpellEffect::Revive case at 1707. Only calls CastRezz for IsPlayerCorpse(). Need to add else-if for IsCompanionCorpse(). |
| `zone/entity.h` | 209-219 | GetCorpseByOwner, GetCorpseByOwnerWithinRange declared. Add GetCompanionCorpseByOwnerWithinRange next to them. |
| `zone/entity.cpp` | 2027-2049 | GetCorpseByOwnerWithinRange iterates corpse_list, checks IsPlayerCorpse + name match + DistanceSquaredNoZ + range. Follow same pattern for companion version. |
| `zone/companion.h` | Full | Has AI methods, lifecycle, xp, no rez methods yet. Add ResurrectFromCorpse, ApplyDeathXPPenalty, AI_ResurrectDeadGroupMember, FindDeadGroupMemberCorpse, m_rez_delay_timer, m_rez_meditation_announced. GetXPForNextLevel exists, need GetXPForCurrentLevel (= level * (level-1) * 1000 formula). |
| `zone/companion.cpp` | 571-678 | Death() method. NPC::Death() runs first (creates corpse), then SetDepop(false), then saves. ApplyDeathXPPenalty() call goes here after the NPC::Death() call and before equipment handling. |
| `zone/companion.cpp` | 2114-2118 | AI_IdleCastCheck() — add SpellType_Resurrect to the bitmask. |
| `zone/companion.cpp` | 3299-3304 | GetXPForNextLevel() uses `level * level * 1000`. GetXPForCurrentLevel() needs same formula but for current level (xp needed to get FROM current-1 TO current). |
| `zone/companion_ai.cpp` | 1136-1142 | AI_Cleric() rez stub — replace with real AI_ResurrectDeadGroupMember() call. |
| `zone/companion_ai.cpp` | 983-1032 | AI_Paladin() idle section — add rez block before buff. |
| `zone/companion_ai.cpp` | 1676-1680 | AI_Necromancer() idle section — add rez block before buff. |
| `zone/attack.cpp` | 2887-2897 | Corpse creation for NPCs. After entity_list.AddCorpse, check IsCompanion() and set companion data + strip loot + set decay timer. |
| `zone/merc.cpp` | 2003-2018, 3719-3738 | GetGroupMemberCorpse() and rez pattern reference. |

### Key Findings

1. **GetXPForNextLevel formula:** `level * level * 1000` — so GetXPForCurrentLevel = `(level-1) * (level-1) * 1000` when level > 1, else 0.
2. **Corpse decay timer:** The NPC Corpse constructor accepts `decay_time` parameter, and THEN the constructor body overrides it with npcCorpseDecayTimes at lines 142-153. To give companion corpses 30-min decay, we must call `SetDecayTimer()` AFTER the corpse is added to the entity list (i.e., after `entity_list.AddCorpse()` in attack.cpp).
3. **Corpse loot stripping:** `m_item_list` is a private member. Use `RemoveItem()` in a loop — but there's no `ClearItems()` method. Can iterate `m_item_list` via `GetLootItems()` reference. Actually `RemoveItem(LootItem*)` removes by pointer. Easiest approach: iterate the item list and call `RemoveItem()` repeatedly. Looking at the existing API more carefully: `GetLootItems()` returns `const LootItems&`. Better: add a `ClearAllLoot()` method to Corpse that clears `m_item_list`. Or use `RemoveItem(loot_slot)` in reverse order.
4. **ResurrectFromCorpse pattern:** Must look up companion_data from DB, create new Companion entity (same pattern as Spawn), position at corpse, set HP/mana, join group, delete corpse. Uses `CompanionDataRepository::FindOne()`.
5. **Reagent waiver for Convergence:** `SpellFinished()` consumes reagents in spells.cpp. The simplest gate is to skip reagent consumption inside `Mob::SpellFinished()` when the caster `IsCompanion()` and `RuleB(Companions, RezWaiveReagents)` is true. Need to find the reagent consumption code path.
6. **Multi-healer coordination check:** In `AI_ResurrectDeadGroupMember()`, before casting, iterate group members and check if any other `IsCompanion()` is already `IsCasting()` with a `SpellType_Resurrect` spell. If so, skip. Only one healer rezzes at a time.
7. **IsCasting check during coordination:** Check via `CastToCompanion()` on group companions. Need to verify current cast spell type.

### Implementation Plan

**Files to create or modify:**

| File | Action | What Changes |
|------|--------|-------------|
| `common/ruletypes.h` | Modify | Add 5 new Companions rules before RULE_CATEGORY_END |
| `zone/corpse.h` | Modify | Add m_companion_id, m_companion_owner_id to private; add IsCompanionCorpse(), GetCompanionID(), GetCompanionOwnerID(), SetCompanionData() to public |
| `zone/corpse.cpp` | Modify | Init new fields in NPC constructor; implement SetCompanionData(); add ClearAllLoot() |
| `zone/attack.cpp` | Modify | After AddCorpse for NPC, check IsCompanion() — strip loot, set companion data, extend decay timer |
| `zone/spell_effects.cpp` | Modify | Add companion corpse path in SpellEffect::Revive handler |
| `zone/entity.h` | Modify | Declare GetCompanionCorpseByOwnerWithinRange() |
| `zone/entity.cpp` | Modify | Implement GetCompanionCorpseByOwnerWithinRange() |
| `zone/companion.h` | Modify | Add ResurrectFromCorpse, ApplyDeathXPPenalty, GetXPForCurrentLevel, AI_ResurrectDeadGroupMember, FindDeadGroupMemberCorpse, m_rez_delay_timer, m_rez_meditation_announced |
| `zone/companion.cpp` | Modify | ApplyDeathXPPenalty(), GetXPForCurrentLevel(), ResurrectFromCorpse(), AI_IdleCastCheck (add SpellType_Resurrect), Process() (rez delay timer), Death() (call ApplyDeathXPPenalty) |
| `zone/companion_ai.cpp` | Modify | AI_ResurrectDeadGroupMember(), FindDeadGroupMemberCorpse(), deity dialogue lookup, replace rez stub in AI_Cleric(), add rez to AI_Paladin(), AI_Necromancer() |
| `zone/spells.cpp` | Modify | In SpellFinished reagent check, add IsCompanion() + RezWaiveReagents bypass |
| `zone/cli/tests/cli_companion_tests.cpp` | Modify | Add Suite 29: Rez system tests |

---

## Stage 2: Research

### Documentation Consulted

| API / Function / Syntax | Source | Verified? | Notes |
|------------------------|--------|-----------|-------|
| `GetXPForNextLevel` formula | Source code companion.cpp:3299-3304 | Yes | `level * level * 1000` |
| `Corpse::RemoveItem(uint16)` slot-based removal | Source code corpse.h:160 | Yes | Removes by loot slot |
| `Corpse::SetDecayTimer(uint32)` | Source code corpse.h:140 | Yes | Sets timer in ms |
| `CompanionDataRepository::FindOne()` | Source (ORM pattern) | Yes | Returns struct or {} |
| `NPC::Death()` corpse creation point | attack.cpp:2887-2905 | Yes | Corpse created, then entity_list.AddCorpse() |
| `Timer::GetCurrentTime()` | common/timer.h | Yes | Returns epoch ms |
| `Corpse::DontRootMeBefore()` | mob.h:1282 | Yes | Used in merc rez pattern |
| `SpellType_Resurrect` | spdat.h:648 | Yes | `(1 << 16) = 65536` |
| `SpellFinished` reagent check | spells.cpp — need to find | Pending | See below |

### Plan Amendments

Need to find the reagent consumption code path to implement `RezWaiveReagents`. Looking at the architecture doc: "check if the caster `IsCompanion()` and `RuleB(Companions, RezWaiveReagents)` — if so, skip the reagent check. This needs to be wired into `Mob::SpellFinished()` where reagents are consumed." Will add this after finding the reagent path in spells.cpp.

Also: for `ResurrectFromCorpse()`, the architecture doc says to look up companion_data from the corpse's `GetCompanionID()`. The existing `Companion::Load()` method loads from DB. The rez method needs to:
1. Load companion_data row
2. Load npc_types row for the companion
3. Create a new Companion entity using that NPCType
4. Position at corpse location
5. Unsuspend to wrong HP/mana — instead, manually set HP/mana
6. Restore partial XP
7. Save updated companion_data
8. Delete corpse entity
9. Send group message

For step 6, the rez XP restoration: spell's `base_value` from `spells[spell_id].base[0]` gives the XP restoration percentage. For a 90% rez, that's 90. So `xp_restored = (xp_lost * base_value) / 100`.

But we need to store the XP loss on the corpse or in a member variable so ResurrectFromCorpse can restore it. Architecture says: store the loss amount on the corpse or via member var. Best approach: store `m_xp_lost_on_death` as a new member in Companion, set in ApplyDeathXPPenalty(), read in ResurrectFromCorpse().

---

## Stage 3: Socialize

No cross-agent dependencies for the C++ changes. The data-expert is populating `companion_spell_sets` independently (Task 11). The rez system will work with whatever spells are present — if none exist, no rez spell will be found and no rez attempt occurs. No blocking.

**Consensus plan:** Architecture plan + Stage 1 findings above.

---

## Stage 4: Build

### Implementation Log

#### 2026-03-15 — Task 1: Add 5 new rules to ruletypes.h

**What:** Added 5 RULE_* declarations to the Companions category in ruletypes.h.
**Where:** `common/ruletypes.h` before RULE_CATEGORY_END at line 1250.
**Why:** Foundation for all other tasks — RezEnabled, RezRange, RezPostCombatDelayS, XPDeathPenaltyPct, RezWaiveReagents.

#### 2026-03-15 — Task 2: Add companion metadata to Corpse class

**What:** Added m_companion_id, m_companion_owner_id to Corpse private section; added IsCompanionCorpse(), GetCompanionID(), GetCompanionOwnerID(), SetCompanionData(), ClearAllLoot() to public section; initialized fields in NPC constructor; implemented SetCompanionData() and ClearAllLoot() in corpse.cpp.
**Where:** `zone/corpse.h` (private/public sections), `zone/corpse.cpp` (NPC constructor + new methods).

#### 2026-03-15 — Tasks 3: Strip loot + set companion data in attack.cpp

**What:** After corpse is added to entity list in NPC::Death() (attack.cpp), check IsCompanion() — strip loot, set companion data, override decay timer to 30 min.
**Where:** `zone/attack.cpp` after line 2905 (entity_list.AddCorpse).

#### 2026-03-15 — Task 4: Extend SpellEffect::Revive

**What:** Added `else if (CastToCorpse()->IsCompanionCorpse())` branch in spell_effects.cpp that calls `Companion::ResurrectFromCorpse()`.
**Where:** `zone/spell_effects.cpp` at SpellEffect::Revive case.

#### 2026-03-15 — Task 5: Add GetCompanionCorpseByOwnerWithinRange()

**What:** Added declaration to entity.h and implementation to entity.cpp. Iterates corpse_list checking IsCompanionCorpse(), GetCompanionOwnerID() match, DistanceSquaredNoZ < range*range, !IsRezzed().
**Where:** `zone/entity.h` + `zone/entity.cpp`.

#### 2026-03-15 — Task 6: ApplyDeathXPPenalty() + XP tracking

**What:** Added m_xp_lost_on_death to Companion private members, GetXPForCurrentLevel(), ApplyDeathXPPenalty() method. Called from Death() before the NPC::Death() call.
**Where:** `zone/companion.h` + `zone/companion.cpp`.

#### 2026-03-15 — Task 7: ResurrectFromCorpse() static method

**What:** Full rez lifecycle: load companion_data + npc_types, create new Companion at corpse position, set HP/mana to post-rez values, restore XP, join group, delete corpse, send group message.
**Where:** `zone/companion.h` + `zone/companion.cpp`.

#### 2026-03-15 — Task 8: Rez delay timer + AI_IdleCastCheck

**What:** Added m_rez_delay_timer, m_rez_meditation_announced to Companion. Added SpellType_Resurrect to AI_IdleCastCheck() bitmask. Added timer start when combat ends (engaged→idle transition in Process()). Added timer check disabling in Process().
**Where:** `zone/companion.h`, `zone/companion.cpp`.

#### 2026-03-15 — Tasks 9+10+12: Full rez AI

**What:** Implemented AI_ResurrectDeadGroupMember(), FindDeadGroupMemberCorpse() with priority system, SelectBestRezSpell() mana-aware selection, deity dialogue lookup. Replaced stub in AI_Cleric(), added to AI_Paladin() and AI_Necromancer(). Added multi-healer coordination check.
**Where:** `zone/companion.h`, `zone/companion_ai.cpp`.

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `common/ruletypes.h` | Modified | +5 Companions rules |
| `zone/corpse.h` | Modified | +companion metadata fields and methods |
| `zone/corpse.cpp` | Modified | Init fields + SetCompanionData() + ClearAllLoot() |
| `zone/attack.cpp` | Modified | Strip loot + set companion data post-corpse-creation |
| `zone/spell_effects.cpp` | Modified | Companion rez path in SpellEffect::Revive |
| `zone/entity.h` | Modified | +GetCompanionCorpseByOwnerWithinRange() declaration |
| `zone/entity.cpp` | Modified | +GetCompanionCorpseByOwnerWithinRange() implementation |
| `zone/companion.h` | Modified | +rez methods, timer, XP loss tracking |
| `zone/companion.cpp` | Modified | ApplyDeathXPPenalty, GetXPForCurrentLevel, ResurrectFromCorpse, AI_IdleCastCheck, Process rez timer, Death call |
| `zone/companion_ai.cpp` | Modified | Full rez AI: AI_ResurrectDeadGroupMember, FindDeadGroupMemberCorpse, SelectBestRezSpell, deity dialogue, wired into AI_Cleric/Paladin/Necromancer |
| `zone/spells.cpp` | Modified | RezWaiveReagents bypass for companion casters |
| `zone/cli/tests/cli_companion_tests.cpp` | Modified | Suite 29: Rez system tests |

---

## Context for Next Agent

All 11 C++ tasks implemented. The rez system is:
1. Companion dies → ApplyDeathXPPenalty() deducts XP, Death() records m_xp_lost_on_death
2. Corpse created in attack.cpp with companion metadata (companion_id, owner_char_id), loot stripped, decay timer = 30 min
3. Healer companion (CLR/PAL/NEC) idle AI: after 10s post-combat delay, scans for dead group member corpses via FindDeadGroupMemberCorpse() prioritized by rez-value
4. SelectBestRezSpell() finds highest-mana-affordable rez spell; if none, sit+announce meditation
5. AIDoSpellCast() on corpse target
6. SpellEffect::Revive detects IsCompanionCorpse() → calls Companion::ResurrectFromCorpse()
7. ResurrectFromCorpse() spawns new Companion at corpse position with low HP/0 mana/no buffs/partial XP restored, deletes corpse

Data-expert still needs to complete Task 11 (populate companion_spell_sets with rez spell IDs).
