# BUG-010: Companion level reverts to base NPC level on zone-in

> **Severity:** Critical
> **Reported by:** user / data-expert investigation
> **Date:** 2026-03-08
> **Feature:** companion-aggro-fixes
> **Status:** Open

---

## Observed Behavior

When a companion's level is set via `#level` or through leveling up in combat,
the level reverts to the original NPC's base level (from `npc_types`) after
zoning. The `companion_data.level` field in the database correctly stores the
updated level, but it is never applied when the companion is re-spawned on
zone-in.

## Expected Behavior

Companions should spawn at their saved level from `companion_data.level`,
not the original NPC's base level from `npc_types`. Stats, HP, mana, and
spells should all scale to the saved level.

## Root Cause (from data-expert investigation)

1. On zone-in, `SpawnCompanionsOnZone()` calls `new Companion(npc_type, ...)`
   — the constructor sets level from `npc_type->level` (the original NPC's
   base level in `npc_types`)
2. `companion->Load(cd.id)` is then called — it restores HP, mana, stance,
   XP from `companion_data` but does NOT call `SetLevel(cd.level)`
3. So the in-memory level at spawn is always the original NPC level, not the
   saved companion level
4. `#level` sets the in-memory level and triggers `Save()` (which writes the
   correct level to `companion_data.level`), but the next zone-in reads
   `npc_type->level` again — hence the revert

## Reproduction Steps

1. Recruit an NPC companion (e.g., a level 5 NPC)
2. Use `#level 13` on the companion
3. Zone to a different zone
4. Observe: companion is back to level 5

## Proposed Fix

In the `Load()` method or `SpawnCompanionsOnZone()`, after loading companion
data from the database, call `SetLevel(cd.level)` and scale stats
appropriately (e.g., `ScaleStatsToLevel()` or equivalent) so the saved level
is applied at spawn time.

## Affected Systems

- [x] C++ server source -> c-expert
- [ ] Lua quest scripts -> lua-expert
- [ ] Perl quest scripts -> perl-expert
- [ ] Database / SQL -> data-expert
- [ ] Rules / Configuration -> config-expert
- [ ] Client protocol -> protocol-agent
- [ ] Infrastructure / Docker -> infra-expert
