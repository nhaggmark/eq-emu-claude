# BUG-035 Architecture: Companions Attack Friendly Pets

## Executive Summary

Companions attack friendly pets (charmed, summoned, companion-owned) because the companion targeting system lacks pet-ownership awareness. Five interlocking gaps prevent companions from recognizing that a mob is a pet belonging to a friendly entity. The fix introduces a centralized `Companion::IsFriendlyTarget()` helper that checks transitive pet ownership, then integrates it into the three attack paths: assist logic, the Attack() safety net, and IsAttackAllowed(). A comprehensive test suite (34 tests) validates all pet types, ownership chains, and edge cases including charm break.

---

## Root Cause Analysis (Verified Against Source Code)

### Gap 1: Companion assist logic has no pet filters

**File:** `zone/companion.cpp` lines 1920-1970
**Verified:** The BALANCED stance scan (line 1920) iterates `GetCloseMobList()` and filters only on `IsNPC()` and `IsCompanion()`:
```cpp
if (!nearby || !nearby->IsNPC() || nearby->IsCompanion()) {
    continue;
}
```
No check for `IsPet()`, `IsCharmed()`, `HasOwner()`, or ownership by a friendly entity. A charmed pet is `IsNPC() == true` and `IsCompanion() == false`, so it passes the filter and can be added to the hate list.

The AGGRESSIVE stance scan (line 1948) has the same pattern:
```cpp
if (!nearby || !nearby->IsNPC() || nearby->IsCompanion()) {
    continue;
}
```
Same gap — pets owned by the owner or group members pass through.

### Gap 2: Safety checks don't cover pets

**File:** `zone/companion.cpp` lines 1975-2025
**Verified:** Both BALANCED assist-owner-target (line 1979) and AGGRESSIVE assist (line 2005) have identical safety checks:
```cpp
bool target_is_safe = false;
if (owner_target == owner) { target_is_safe = true; }
else if (owner_target->IsCompanion() && ...) { target_is_safe = true; }
else { if (grp && grp->IsGroupMember(owner_target)) { target_is_safe = true; } }
```
These check: (a) is target the owner, (b) is target a companion of the same owner, (c) is target a group member. They do NOT check: is target a PET of the owner, a PET of a group member, or a PET of another companion.

### Gap 3: Attack() safety net doesn't cover pets

**File:** `zone/companion.cpp` lines 722-738
**Verified:** The hard safety net in `Companion::Attack()` checks:
```cpp
if (other == atk_owner) { ... return false; }
if (atk_grp && atk_grp->IsGroupMember(other)) { ... return false; }
```
No pet-ownership check. If a friendly pet ends up on the hate list through any path, the Attack() safety net won't catch it.

### Gap 4: IsAttackAllowed resolves owners but companions aren't in the pet system

**File:** `zone/aggro.cpp` lines 732-982
**Verified:** `Mob::IsAttackAllowed()` resolves pet ownership at lines 837-838:
```cpp
mob1 = our_owner ? our_owner : this;
mob2 = target_owner ? target_owner : target;
```
For companions, `GetOwner()` returns `nullptr` because companions don't use the standard pet system (no `ownerid` set). So `mob1 = companion (NPC)`. For a charmed pet, `mob2 = client (the charmer)`. The NPC-vs-Client path (via the reverse swap at line 973-978) resolves to Client-vs-NPC which returns `true` (attack allowed).

For a companion's pet (e.g., necro companion's summoned pet), `mob2 = necro companion (NPC)`. The NPC-vs-NPC path at line 892-914 returns `true` (attack allowed between NPCs).

The Bot system handles this via `Bot::IsBotAttackAllowed()` at line 963-970, but that only runs when `attacker->IsBot()` — companions aren't bots.

### Gap 5: ReplaceWithTarget during charm break doesn't exclude companions

**File:** `zone/entity.cpp` lines 1522-1536, `zone/spell_effects.cpp` line 4488
**Verified:** When charm breaks, `ReplaceWithTarget(charmed_pet, owner)` iterates ALL AI-controlled mobs and replaces the charmed pet with its owner on their hate lists. If a companion has the charmed pet on its hate list (shouldn't, but possible through various AoE/assist paths), the companion would then have the CLIENT on its hate list. This is caught by Attack() safety net for the owner directly, but NOT for a scenario where the companion already had a different friendly pet.

**Assessment:** This gap is secondary — fixing gaps 1-4 prevents friendly pets from reaching the hate list in the first place. ReplaceWithTarget doesn't need modification.

---

## Technical Approach

### Design Principle: Defense in Depth

The fix uses a **three-layer defense** strategy. Each layer catches what the previous might miss:

1. **Layer 1 (Assist Logic):** Filter friendly pets BEFORE they reach the hate list
2. **Layer 2 (IsAttackAllowed):** Reject attacks on friendly pets at the combat permission check
3. **Layer 3 (Attack Safety Net):** Last-resort scrub from hate list if a pet sneaks through

All three layers use the same centralized helper method to avoid logic duplication.

### New Helper Method: `Companion::IsFriendlyTarget(Mob* target)`

A single method that answers: "Should this companion treat `target` as friendly?"

**Location:** `zone/companion.h` (declaration), `zone/companion.cpp` (definition)

```
bool Companion::IsFriendlyTarget(Mob* target) const

Returns true if target is:
  1. The companion's owner (Client)
  2. A group member
  3. Another companion belonging to the same owner
  4. A PET (any type) whose owner is:
     a. The companion's owner
     b. A group member
     c. Another companion belonging to the same owner
  5. A PET of a PET (transitive: e.g., swarm pet owned by a summoned pet
     owned by a companion) — chase GetUltimateOwner() up to 3 hops
```

**Implementation logic:**
```
IsFriendlyTarget(target):
  if target == owner → true
  if target is companion with same owner_char_id → true
  if group contains target → true

  // Pet ownership check: resolve the target's ultimate owner
  ultimate = target->GetUltimateOwner()
  if ultimate != target:  // target IS a pet of some kind
    if ultimate == owner → true
    if ultimate is companion with same owner_char_id → true
    if group contains ultimate → true

  // Companion-owned pet check: if target has an owner that is a companion
  direct_owner = target->GetOwner()
  if direct_owner and direct_owner->IsCompanion():
    cast to Companion, check owner_char_id match → true

  return false
```

This handles ALL pet types because the standard pet system (charmed, summoned, swarm, beastlord warder) all set `ownerid` on the pet, making `GetOwner()` / `GetUltimateOwner()` work.

### Layer 1: Assist Logic Changes

**File:** `zone/companion.cpp`

**BALANCED scan (lines 1920-1923):** Add `IsFriendlyTarget(nearby)` check:
```
if (!nearby || !nearby->IsNPC() || nearby->IsCompanion() || IsFriendlyTarget(nearby)) {
    continue;
}
```

**AGGRESSIVE scan (lines 1948-1951):** Same change:
```
if (!nearby || !nearby->IsNPC() || nearby->IsCompanion() || IsFriendlyTarget(nearby)) {
    continue;
}
```

**BALANCED owner-assist (lines 1975-1996):** Replace the manual safety check with `IsFriendlyTarget()`:
```
if (owner_target && !IsFriendlyTarget(owner_target) && IsAttackAllowed(owner_target)) {
    AddToHateList(owner_target, 1);
    SetTarget(owner_target);
}
```

**AGGRESSIVE owner-assist (lines 1999-2025):** Same pattern:
```
if (owner_target && !IsFriendlyTarget(owner_target) && IsAttackAllowed(owner_target)) {
    if (!IsEngaged() || GetTarget() == nullptr) {
        AddToHateList(owner_target, 1);
        SetTarget(owner_target);
    }
}
```

### Layer 2: IsAttackAllowed Override

**File:** `zone/companion.h` (declaration), `zone/companion.cpp` (definition)

Add a `Companion::IsAttackAllowed()` override:
```
bool Companion::IsAttackAllowed(Mob* target, bool isSpellAttack) override {
    if (IsFriendlyTarget(target)) {
        return false;
    }
    return Mob::IsAttackAllowed(target, isSpellAttack);
}
```

This catches ALL code paths that call `IsAttackAllowed()` on a companion — not just the assist logic, but also AoE targeting, spell targeting, proc targeting, etc.

### Layer 3: Attack() Safety Net Enhancement

**File:** `zone/companion.cpp` lines 722-738

Extend the existing safety net to include pet ownership:
```
// Existing checks for owner and group members...
// NEW: check if target is a pet of a friendly entity
if (IsFriendlyTarget(other)) {
    RemoveFromHateList(other);
    SetTarget(nullptr);
    return false;
}
```

This replaces the existing manual owner/group checks with the single `IsFriendlyTarget()` call, which is a superset.

### Edge Case: Charm Break

When charm breaks, the formerly-charmed NPC becomes hostile again. The fix handles this correctly because:

1. Charm break calls `SetOwnerID(0)` on the pet (spell_effects.cpp line 4431)
2. After this, `GetOwner()` returns nullptr, `IsPet()` returns false
3. `IsFriendlyTarget()` won't match — target has no owner
4. `IsAttackAllowed()` returns true — companion CAN attack
5. The NPC's own hate list gets `AddToHateList(owner, 1, 0)` making it aggressive

**No special handling needed for charm break.** The standard charm-break code path (spell_effects.cpp lines 4431-4515) already clears ownership before any subsequent hate list operations. By the time companions re-evaluate targets, the pet is no longer owned.

---

## Implementation Sequence

### Task 1: Implement `IsFriendlyTarget()` helper — **c-expert**

**Files to modify:**
- `zone/companion.h` — Add declaration: `bool IsFriendlyTarget(Mob* target) const;`
- `zone/companion.cpp` — Add implementation

**Details:**
- Must be `const` (doesn't modify companion state)
- Must handle nullptr target (return false)
- Must handle the companion itself as target (return true — don't attack self, though this is already handled elsewhere)
- Chase `GetUltimateOwner()` for transitive pet chains
- Check `IsCompanion()` cast to `Companion*` for same-owner check via `GetOwnerCharacterID()`
- Use `GetGroup()` and `IsGroupMember()` for group membership checks

### Task 2: Integrate into assist logic — **c-expert**

**File to modify:** `zone/companion.cpp`

**Changes:**
1. BALANCED scan (line ~1921): Add `|| IsFriendlyTarget(nearby)` to skip condition
2. AGGRESSIVE scan (line ~1949): Add `|| IsFriendlyTarget(nearby)` to skip condition
3. BALANCED owner-assist (lines ~1975-1996): Replace manual safety block with `IsFriendlyTarget()` call
4. AGGRESSIVE owner-assist (lines ~1999-2025): Replace manual safety block with `IsFriendlyTarget()` call

### Task 3: Add `IsAttackAllowed()` override — **c-expert**

**Files to modify:**
- `zone/companion.h` — Add declaration: `virtual bool IsAttackAllowed(Mob* target, bool isSpellAttack = false) override;`
- `zone/companion.cpp` — Add implementation that calls `IsFriendlyTarget()` then delegates to `Mob::IsAttackAllowed()`

### Task 4: Enhance Attack() safety net — **c-expert**

**File to modify:** `zone/companion.cpp`

**Changes:**
- Replace the existing manual owner + group member checks (lines 722-738) with a single `IsFriendlyTarget()` call
- Keep the `RemoveFromHateList()` + `SetTarget(nullptr)` + `return false` pattern

### Task 5: Add comprehensive test suite — **c-expert**

**File to modify:** `zone/cli/tests/cli_companion_tests.cpp`

**New test suite: "Suite 34: BUG-035 — Companions Don't Attack Friendly Pets"**

The test suite must create companions and various pet types, then verify that the companion's targeting logic correctly identifies and avoids friendly pets.

#### Test Categories:

**IsFriendlyTarget() unit tests (10 tests):**
1. Returns false for nullptr
2. Returns true for the companion's owner (Client — skip if no mock Client available, test via GetOwnerCharacterID match)
3. Returns true for another companion with same owner_char_id
4. Returns true for a companion that is itself (edge case)
5. Returns false for an unrelated NPC
6. Returns false for a companion with different owner_char_id
7. Returns true for an NPC whose GetOwner() is a companion with same owner_char_id (companion's pet)
8. Returns true for an NPC whose GetUltimateOwner() traces to a friendly entity (swarm pet chain)
9. Returns false for an NPC whose owner is an unrelated entity
10. Returns false for an NPC with no owner (wild mob)

**Assist logic filtering tests (8 tests):**
11. BALANCED scan: friendly summoned pet not added to hate list
12. BALANCED scan: friendly charmed pet not added to hate list (simulate via IsFriendlyTarget check)
13. BALANCED owner-assist: target that is a friendly pet is not engaged
14. BALANCED owner-assist: target that is a hostile NPC IS engaged (regression)
15. AGGRESSIVE scan: friendly pet not added to hate list
16. AGGRESSIVE scan: hostile NPC IS added to hate list (regression)
17. AGGRESSIVE owner-assist: friendly pet is not engaged
18. AGGRESSIVE owner-assist: hostile NPC IS engaged (regression)

**IsAttackAllowed override tests (6 tests):**
19. IsAttackAllowed returns false for companion's own-owner's pet (simulated)
20. IsAttackAllowed returns false for another companion (same owner) pet
21. IsAttackAllowed returns true for unrelated NPC
22. IsAttackAllowed returns true for hostile NPC
23. IsAttackAllowed returns false for another companion with same owner
24. IsAttackAllowed returns true for companion with different owner

**Attack() safety net tests (4 tests):**
25. Attack() returns false and removes target from hate list when target is friendly pet
26. Attack() returns false for owner
27. Attack() returns false for group member (regression)
28. Attack() returns true for hostile NPC (regression)

**Charm break edge case tests (4 tests):**
29. NPC with ownerid=0 is NOT treated as friendly (post charm-break)
30. NPC with PetType::None is NOT treated as friendly
31. Companion correctly attacks a former charmed pet after charm breaks (simulate by creating NPC with no owner)
32. IsFriendlyTarget returns false for NPC that was formerly charmed (ownerid cleared)

**Multi-companion scenarios (2 tests):**
33. Two companions: companion A does not attack companion B's pet
34. Companion does not attack its own pet

**Test Infrastructure Notes:**
- The test framework can create companions via `CreateTestCompanion()`
- Regular NPCs can be created and manipulated (set ownerid, pet type)
- AddToHateList, CheckAggro, RemoveFromHateList are directly callable
- IsAttackAllowed is directly callable
- `IsFriendlyTarget()` is a new public method, directly testable
- Some tests need to spawn an NPC and set its ownerid to simulate a pet — use `NPC::SetOwnerID()` and `Mob::SetPetType()`
- Group integration tests may need `AddCompanionToGroup()` and mock group scenarios

---

## Risk Assessment

### Technical Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| IsFriendlyTarget() has a performance cost in assist scan loops | Low | GetCloseMobList already limits scan radius; IsFriendlyTarget does at most 3 entity lookups per call. Scan runs max once per Process() tick. |
| Replacing manual safety checks in assist logic could introduce regression | Medium | Test suite includes regression tests verifying hostile NPCs ARE still engaged. |
| IsAttackAllowed override could block legitimate attacks (e.g., AoE hitting neutral NPCs) | Low | Override only blocks when IsFriendlyTarget returns true — same entities that the existing manual checks protect. AoE targeting already goes through a different path. |
| GetUltimateOwner() chain could loop if entities have circular ownership | Low | GetUltimateOwner() already has the standard Mob implementation that terminates when HasOwner() returns false. Max depth is naturally bounded by entity hierarchy. |
| CastToNPC()/CastToCompanion() crashes if entity is deleted between check and cast | Low | All checks use the pattern `if (target && target->IsCompanion()) { ... CastToNPC() ... }` — the same pattern used throughout the codebase. |

### Compatibility Risks

| Risk | Mitigation |
|------|------------|
| Existing companion tests break | No existing tests exercise pet-targeting; changes are additive. |
| Attack() safety net change alters existing behavior | The new check is a superset of the existing manual owner + group member checks. Regression tests verify both old and new cases. |
| Pets of enemies incorrectly marked friendly | IsFriendlyTarget only checks against the companion's own owner, group, and same-owner companions — not arbitrary friendly factions. |

### Performance Risks

| Risk | Assessment |
|------|------------|
| IsFriendlyTarget called per-mob in assist scan | At most ~20 mobs in GetCloseMobList(200), each call does 3-4 entity lookups via GetOwner/GetUltimateOwner. Negligible compared to existing faction checks in the same loop. |
| IsAttackAllowed override adds one extra check | Single method call before delegating to Mob::IsAttackAllowed. Negligible. |

---

## Review Passes

### Pass 1: Feasibility

- **IsFriendlyTarget():** All required methods exist: `GetOwner()`, `GetUltimateOwner()`, `IsCompanion()`, `GetOwnerCharacterID()`, `GetGroup()`, `IsGroupMember()`. No new infrastructure needed.
- **IsAttackAllowed override:** Virtual method, standard override pattern. No linker or vtable concerns.
- **Test infrastructure:** The existing CLI test framework (`cli_companion_tests.cpp`) supports creating companions and NPCs, manipulating hate lists, and testing methods directly. All 34 tests are feasible with existing infrastructure.
- **No client-side changes:** This is purely server-side AI logic. No opcode, packet, or protocol changes.
- **No config/rule changes:** The fix is behavioral correctness, not a tunable parameter. No new rules needed.

### Pass 2: Simplicity

- **Single helper method:** All three defense layers use `IsFriendlyTarget()`. No duplicated logic.
- **Minimal code changes:** ~50 lines of new code (helper + override + safety net), ~20 lines of modified code (assist logic filters).
- **No new files:** All changes in existing companion.h, companion.cpp, and test file.
- **Replaces verbose manual checks:** The BALANCED and AGGRESSIVE safety blocks (lines 1979-1990, 2005-2016) are 12+ lines each of manual owner/companion/group checks. Replaced with one `IsFriendlyTarget()` call each.

### Pass 3: Antagonistic

- **Can a hostile NPC be incorrectly marked friendly?** No. IsFriendlyTarget only matches entities in the companion's direct ownership/group chain. An NPC that happens to share the same faction but is not a pet/group member/companion is not matched.
- **Can charm break leave a stale "friendly" flag?** No. IsFriendlyTarget checks live ownership on every call. When charm breaks and ownerid is cleared, the next check returns false.
- **Can a pet attack race condition occur?** In theory, if a pet is added to hate list between the IsFriendlyTarget check and the AddToHateList call, but this is single-threaded within the zone process. No race condition possible.
- **Can companion's own pet be targeted?** Yes, without the fix. Gap 3 shows the Attack() safety net doesn't check this. The fix covers it via IsFriendlyTarget.
- **Can an exploit be created?** A player could theoretically use charm + companions to create an invulnerable NPC (companion won't attack charmed pet). But this is the INTENDED behavior — charmed pets are friendly during charm. When charm breaks, the protection is removed.
- **What if GetUltimateOwner() is expensive?** It walks up the ownership chain. Maximum depth in practice is 2 (pet → companion → client doesn't have GetOwner set for companions). Actually for companions it's 1 (pet → companion). Not a concern.
- **What if companion has no owner Client in zone?** GetCompanionOwner() returns nullptr. IsFriendlyTarget handles this by falling through to group-based checks and direct owner_char_id comparisons.

### Pass 4: Integration

- **Task dependency:** Task 1 (IsFriendlyTarget) must be completed first since all other tasks depend on it.
- **Tasks 2-4 are independent** after Task 1 is complete — they modify different sections of companion.cpp.
- **Task 5 (tests)** should be implemented alongside or after Tasks 1-4 to verify the fixes.
- **Build verification:** All changes are in zone/ — only zone binary needs rebuild. No shared_memory, world, or loginserver changes.
- **Validation:** Game-tester should verify in-game with: (a) charmed pet alongside companions, (b) necro companion with pet alongside other companions, (c) charm break scenario.

---

## Validation Plan

### Automated Tests (CLI)

Run: `cd ~/server && ~/code/build/bin/zone tests:companion`

All 34 new tests in Suite 34 must pass. All existing suites (1-33) must continue to pass (regression).

### Manual In-Game Tests

1. **Charmed pet test:**
   - Play as Enchanter with 2+ companions
   - Charm an NPC in a dungeon
   - Engage a hostile mob with the group
   - After combat ends: charmed pet should NOT be attacked by companions
   - Break charm (let it wear off): companions SHOULD attack the now-hostile NPC

2. **Companion pet test:**
   - Recruit a Necromancer NPC as companion
   - Recruit a Warrior NPC as companion
   - Let the Necro summon its pet
   - Engage combat: warrior companion should NOT attack necro's pet
   - After combat: warrior companion should NOT switch to necro's pet

3. **Beastlord warder test (if available):**
   - Recruit a Beastlord companion
   - Verify other companions don't attack its warder

4. **Multi-companion pet test:**
   - Recruit multiple caster companions (Mage + Necro)
   - Both summon pets
   - Verify no cross-companion pet aggro

---

## Files Modified

| File | Change Type | Description |
|------|-------------|-------------|
| `zone/companion.h` | Add declaration | `IsFriendlyTarget()` method, `IsAttackAllowed()` override |
| `zone/companion.cpp` | Add + Modify | `IsFriendlyTarget()` impl, `IsAttackAllowed()` override, assist logic filters, Attack() safety net |
| `zone/cli/tests/cli_companion_tests.cpp` | Add | Suite 34: 34 new tests for BUG-035 |

No database changes. No config/rule changes. No protocol changes. No Lua/Perl changes.

---

## Implementation Notes for c-expert

### IsFriendlyTarget Implementation Pattern

```
bool Companion::IsFriendlyTarget(Mob* target) const {
    if (!target) return false;
    if (target == this) return true;

    Client* owner = GetCompanionOwner();

    // Direct checks: owner, companions, group
    if (owner && target == owner) return true;

    if (target->IsCompanion()) {
        Companion* other_comp = static_cast<Companion*>(target->CastToNPC());
        if (other_comp->GetOwnerCharacterID() == m_owner_char_id) return true;
    }

    Group* grp = GetGroup();
    if (grp && grp->IsGroupMember(target)) return true;

    // Pet ownership: check if target's owner (or ultimate owner) is friendly
    Mob* target_owner = target->GetOwner();
    if (target_owner) {
        if (owner && target_owner == owner) return true;
        if (target_owner->IsCompanion()) {
            Companion* owner_comp = static_cast<Companion*>(target_owner->CastToNPC());
            if (owner_comp->GetOwnerCharacterID() == m_owner_char_id) return true;
        }
        if (grp && grp->IsGroupMember(target_owner)) return true;

        // Chase up for swarm pets / pet-of-pet chains
        Mob* ultimate = target->GetUltimateOwner();
        if (ultimate && ultimate != target && ultimate != target_owner) {
            if (owner && ultimate == owner) return true;
            if (ultimate->IsCompanion()) {
                Companion* ult_comp = static_cast<Companion*>(ultimate->CastToNPC());
                if (ult_comp->GetOwnerCharacterID() == m_owner_char_id) return true;
            }
            if (grp && grp->IsGroupMember(ultimate)) return true;
        }
    }

    return false;
}
```

### Key Invariant

After this fix: if `companion->IsFriendlyTarget(mob)` returns true, then:
- `companion->AddToHateList(mob)` should never be called by assist logic
- `companion->IsAttackAllowed(mob)` returns false
- `companion->Attack(mob)` returns false and scrubs the hate list

Three independent layers, one truth source.
