# BUG-008: Enemies killed by companion cannot be looted

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-02-28
> **Feature:** feature-npc-recruitment
> **Status:** Resolved (2026-02-28)

---

## Observed Behavior

When a companion kills an enemy, the enemy corpse disappears as if it were
killed by a regular NPC (non-grouped). The player cannot loot the corpse.
The kill is not being attributed to the player or their group.

## Expected Behavior

Enemies killed by a companion should be lootable by the companion's owner,
just as if the owner (or any other group member) had killed the enemy. The
corpse should persist with normal player-kill loot rules and decay timers.

## Reproduction Steps

1. Log in with an active companion
2. Engage an enemy — let the companion get the killing blow
3. Observe: enemy corpse disappears like an NPC-on-NPC kill
4. Player cannot loot the corpse

## Likely Cause

When an NPC kills another NPC, the corpse follows NPC death rules (fast
despawn, no player loot). The companion is an NPC subclass, so the server
treats companion kills as NPC kills. The kill credit / corpse ownership
logic likely needs to check `IsCompanion()` and attribute the kill to the
companion's owner (or the owner's group) so that player loot rules apply.

Key areas to investigate:
- Death/corpse creation code — how `give_exp_client` / killer attribution works
- `Mob::Death()` or `NPC::Death()` — corpse type determination
- Group kill credit logic — does it check for companion ownership?

## Affected Systems

- [x] C++ server source → c-expert
- [ ] Lua quest scripts → lua-expert
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [ ] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert
