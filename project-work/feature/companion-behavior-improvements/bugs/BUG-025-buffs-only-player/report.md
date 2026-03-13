# BUG-025: !buffs command only buffs player instead of all party members

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-03-12
> **Feature:** companion-behavior-improvements
> **Status:** Open

---

## Observed Behavior

When the player uses `/gsay @all !buffs`, caster companions only buff the
player character. They do not buff other companion NPCs in the group.

## Expected Behavior

The `!buffs` command should cause each caster companion to refresh all of
their buffs on ALL party members, including other companion NPCs — not just
the player. This is distinct from `!buffme` which is supposed to only buff
the player.

The PRD specifies:
- `!buffme` = queue buff refresh on player only
- `!buffs` = queue buff refresh on all party members (player + companions)

## Reproduction Steps

1. Recruit multiple companions including at least one caster
2. Type `/gsay @all !buffs`
3. Observe: caster only buffs the player, does not buff other companions

## Evidence

User observed in-game — companions remain unbuffed after !buffs command.

## Affected Systems

- [ ] C++ server source → c-expert
- [x] Lua quest scripts → lua-expert (companion.lua cmd_buffs / buff timer handler in global_npc.lua)
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [ ] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert
