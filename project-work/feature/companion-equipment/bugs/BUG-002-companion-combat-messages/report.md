# BUG-002: Companion combat hits not shown in "Other's Hit" windows

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-03-07
> **Feature:** companion-equipment
> **Status:** Open

---

## Observed Behavior

NPC companion damage dealt and damage received does not appear in the
player's "other people's hits" and "other people being hit" chat windows.
Companion combat is invisible to the owner in these filtered channels.

## Expected Behavior

When a recruited companion hits a mob or is hit by a mob, the damage
messages should appear in the player's "other people's hits" and "other
people being hit" windows, just like they would for any other group member.

## Reproduction Steps

1. Recruit an NPC companion into group
2. Equip companion with a weapon
3. Engage a mob in combat with companion attacking
4. Check the "other people's hits" chat window — companion hits are missing
5. Check the "other people being hit" chat window — companion damage taken is missing

## Evidence

User reported during companion-equipment feature testing.

## Affected Systems

- [x] C++ server source → c-expert
- [ ] Lua quest scripts → lua-expert
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [x] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert

---

## Architecture Assessment

**Assessed by:** architect
**Date:** 2026-03-07

### Root Cause Analysis

The issue is in `zone/attack.cpp`, function `Mob::CommonDamage()` (lines
4596-4789). The damage message routing logic has three paths based on the
attacker's identity:

1. **Pet path** (line 4601): `attacker && owner && !attacker->IsBot()` --
   Entered when the attacker has a valid `GetOwner()` return. Sends damage
   with `FilterPetHits`/`FilterPetMisses` filter to the owner.

2. **Client/Bot path** (line 4641): `attacker->IsOfClientBot()` --
   Entered when the attacker is a Client or Bot. Sends damage with
   `FilterNone` (no filtering, everyone receives it).

3. **Observer path** (line 4719): Sends to all nearby clients with
   `FilterOthersHit`/`FilterOthersMiss`.

**The problem:** Companions fall through BOTH path 1 and path 2, landing
only on path 3:

- **Path 1 fails** because `Companion::GetOwner()` returns `nullptr`.
  Companions use `GetCompanionOwner()` (returns a `Client*` via
  `entity_list.GetClientByCharID(m_owner_char_id)`) instead of the standard
  pet ownership mechanism (`ownerid`/`petid`). The base `Mob::GetOwner()`
  at `zone/mob.cpp:4527` checks `GetOwnerID()` which is never set for
  companions, then verifies `m->GetPetID() == GetID()` which also fails.

- **Path 2 fails** because `Companion::IsOfClientBot()` returns `false`.
  The `Companion` class does not override `IsOfClientBot()` or
  `IsOfClientBotMerc()` (defaults from `Entity` base class return false).

- **Path 3 executes** with `FilterOthersHit` (value 16, default=hide).
  The Titanium client defaults this filter to "hide" (0). Even if the
  player enables it in Options, this is the wrong semantic -- companion
  damage should use `FilterPetHits` (value 20, default=show).

**Comparison with Bots (which work correctly):**

| Property | Bot | Companion |
|----------|-----|-----------|
| `GetOwner()` | Returns owning Client (ownerid is set) | Returns nullptr |
| `IsOfClientBot()` | true (overridden in `bot.h:795`) | false (Entity default) |
| `IsOfClientBotMerc()` | true (overridden in `bot.h:796`) | false |
| `IsPet()` | false (IsMerc() check) | false (no ownerid) |
| Damage filter when dealing | FilterNone (everyone sees) | FilterOthersHit (default=hide) |
| Damage filter when taking | FilterOthersHit (same as companion) | FilterOthersHit |

Bots reach path 2 via `IsOfClientBot() == true`, sending damage with
`FilterNone`. Companions reach neither path 1 nor path 2.

### Key Files and Lines

| File | Lines | Relevance |
|------|-------|-----------|
| `zone/attack.cpp` | 4596-4789 | `CommonDamage()` damage message routing |
| `zone/mob.cpp` | 4527-4540 | `Mob::GetOwner()` -- fails for companions |
| `zone/companion.h` | 101, 249-253 | `IsCompanion()`, `GetCompanionOwner()`, no override of `IsOfClientBot` |
| `zone/companion.cpp` | 1779-1782 | `GetCompanionOwner()` implementation |
| `zone/entity.h` | 86-87 | Default `IsOfClientBot()`/`IsOfClientBotMerc()` returning false |
| `zone/bot.h` | 795-796 | Bot overrides of `IsOfClientBot()`/`IsOfClientBotMerc()` |
| `zone/entity.cpp` | 1738-1791 | `QueueCloseClients()` -- filter check logic |
| `zone/client.cpp` | 3943 | `Filter0(FilterOthersHit)` -- server filter mapping |
| `common/eq_constants.h` | 751 | `FilterOthersHit = 16` definition (0=hide, 1=show) |

### Proposed Fix

Add companion-specific logic in `CommonDamage()` that mirrors the pet-owner
path (path 1). This is the least-invasive approach -- it does not require
overriding `GetOwner()` (which would have cascading side effects making
companions behave as pets throughout the entire combat system).

**Approach:** After the existing `GetOwner()` check at line 4600, add a
parallel check for companions using `IsCompanion()` and
`GetCompanionOwner()`:

```
Line 4600: Mob* owner = attacker ? attacker->GetOwner() : nullptr;
+ // Companion-specific: use GetCompanionOwner() since companions
+ // do not use the standard ownerid/petid mechanism
+ if (!owner && attacker && attacker->IsCompanion()) {
+     owner = static_cast<Companion*>(attacker->CastToNPC())->GetCompanionOwner();
+ }
```

This single addition causes companions to enter path 1 (the pet-owner
path), which:
- Sends damage packets to the owner with `FilterPetHits`/`FilterPetMisses`
  (both default to SHOW in the Titanium client)
- Properly sets `skip = owner` so the owner doesn't also receive the
  observer path's `FilterOthersHit` duplicate

For the **"companion being hit"** case (mob attacks companion), the same
fix applies to the observer block's owner check at line 4775:

```
Line 4775: Mob *owner = attacker->GetOwner();
```

This line determines whether to skip the observer queue (when attacker has
a client owner). For the "companion being hit" case, the attacker is the
mob, not the companion. So this line is actually about the MOB's owner,
which is correct (nullptr for regular mobs). The observer block fires
normally, sending OP_Damage with FilterOthersHit.

However, there is ALSO the `this` side -- when the companion is the target
being hit, we want the companion's owner to see "CompanionName was hit for
X damage." The observer block at line 4766-4787 handles this, but it uses
FilterOthersHit (default=hide). To fix the "companion being hit" messages,
we should add a separate block that sends the damage packet directly to the
companion's owner, similar to how "damage affecting us" is handled for
clients at line 4768-4769 but using FilterPetHits as the filter.

**Insert after line 4769** (after `if (IsClient()) { QueuePacket; }`):

```
+ // Companion-specific: send damage-to-companion packets to the
+ // companion's owner with FilterPetHits so they see damage taken
+ if (IsCompanion()) {
+     Client* comp_owner = static_cast<Companion*>(CastToNPC())->GetCompanionOwner();
+     if (comp_owner) {
+         comp_owner->QueuePacket(&p, true, Client::CLIENT_CONNECTED, FilterPetHits);
+     }
+ }
```

### Why NOT override GetOwner() or IsOfClientBot()

1. **`GetOwner()` override** would make `IsPet()` return true (via
   `HasOwner()`), causing companions to receive pet-specific damage
   penalties, pet aggro rules, pet experience splitting, and many other
   pet-specific behaviors throughout the codebase. There are 50+ callsites
   that check `GetOwner()` or `IsPet()`.

2. **`IsOfClientBot()` override** would cause companions to be treated
   like bots/clients in combat calculations (AC scaling, offense scaling,
   critical hits, skill damage), which is incorrect for NPC companions.
   There are 30+ checks for `IsOfClientBot()` in attack.cpp alone.

Both approaches have too many side effects. The targeted fix in
`CommonDamage()` is narrowly scoped to just the message routing.

### Task Breakdown

**Task 1: Fix companion damage dealing messages** (c-expert)
- File: `zone/attack.cpp`, function `Mob::CommonDamage()`
- After line 4600, add companion owner resolution via `IsCompanion()` +
  `GetCompanionOwner()`
- Add `#include "companion.h"` to attack.cpp if not already present
- This causes companion damage to use FilterPetHits/FilterPetMisses
  (default=show) instead of FilterOthersHit (default=hide)

**Task 2: Fix companion damage taken messages** (c-expert)
- File: `zone/attack.cpp`, function `Mob::CommonDamage()`
- After line 4769 (the `IsClient()` block), add companion-specific block
  that sends the OP_Damage packet to the companion's owner with
  FilterPetHits filter
- This ensures the owner sees "MobName hits CompanionName for X damage"

**Task 3: Build and test** (c-expert + game-tester)
- Build the zone binary
- Test: recruit companion, engage mob, verify "Pet Hits" filter shows
  companion damage dealt
- Test: verify "Pet Hits" filter shows companion damage received
- Test: verify no duplicate messages appear
- Test: verify normal pet, bot, and player damage messages still work

### Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| `CastToNPC()` crash if `IsCompanion()` is true but entity is corrupt | Low | `IsCompanion()` is only true for `Companion` objects which inherit from NPC |
| Duplicate damage messages if both pet-owner and observer paths fire | Medium | Setting `skip = owner` in the companion path prevents the observer path from also sending to the owner |
| Performance: additional `IsCompanion()` check on every damage event | Negligible | `IsCompanion()` is a virtual bool return, effectively free |
| FilterPetHits semantics: companion hits labeled as "pet hits" | Low | This is the correct EQ convention -- companions are functionally the player's pet for combat message purposes |
