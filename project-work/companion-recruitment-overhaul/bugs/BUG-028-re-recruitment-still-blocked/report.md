# BUG-028: Previously recruited NPC refuses re-recruitment after group wipe

> **Severity:** Critical
> **Reported by:** user
> **Date:** 2026-03-15
> **Feature:** companion-recruitment-overhaul
> **Status:** Open

---

## Observed Behavior

Lashun Novashine, a previously recruited companion NPC who died in a recent group wipe, says "I will not join you." when the player attempts to re-recruit him. Re-recruitment fails despite the companion recruitment overhaul being deployed.

## Expected Behavior

After the recruitment overhaul, any previously recruited companion (with a `companion_data` record where `is_dismissed=1 OR is_suspended=1`) should always be re-recruitable. The two-track system should detect the existing record BEFORE any cooldown, level, faction, or persuasion checks and route to the re-recruitment bypass track.

## Reproduction Steps

1. Have Lashun Novashine as a recruited companion
2. Group wipe occurs — Lashun dies
3. Find Lashun Novashine (same npc_type_id) in the world
4. Say recruitment keyword to Lashun
5. Lashun says "I will not join you." — re-recruitment blocked

## Evidence

User report: "Lashun Novashine (former recruited NPC who died recently in a wipe) still cannot be recruited. He said 'I will not join you.'"

## Investigation Needed

- Was `#reloadquests` run after the merge? The Lua changes require a quest reload.
- Does `companion_data` have a record for Lashun with `is_suspended=1` or `is_dismissed=1`?
- Is the `check_existing_companion_record()` query finding the record?
- Is the code path hitting the re-recruitment track or falling through to first-time?
- What is Lashun's `npc_type_id`? Does it match the companion_data record?
- Are there quest log errors visible in the zone logs?

## Affected Systems

- [x] C++ server source → c-expert
- [x] Lua quest scripts → lua-expert
- [x] Database / SQL → data-expert
