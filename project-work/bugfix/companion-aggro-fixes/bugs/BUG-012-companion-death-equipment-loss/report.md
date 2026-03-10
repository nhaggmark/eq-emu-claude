# BUG-012: Companion loses equipment on death and re-recruitment

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-03-09
> **Feature:** companion-aggro-fixes
> **Status:** Open

---

## Observed Behavior

When a companion dies and is re-recruited, equipment that was previously
traded to them is gone. The companion reverts to their default NPC equipment
state. Items given to the companion by the player are lost.

The user notes that companion memories (NPC knowledge/conversation state)
being wiped on death is expected behavior, but equipment should be retained.

## Expected Behavior

When a companion dies and is re-recruited:
- Equipment previously given to the companion should still be equipped
- The companion_inventories table should persist through death
- Only the "dismissed" or "suspended" state should change, not equipment

## Reproduction Steps

1. Recruit an NPC companion
2. Trade equipment to the companion (e.g., weapons, armor)
3. Let the companion die in combat
4. Re-recruit the same companion
5. Observe: previously traded equipment is gone

## Root Cause Hypothesis

The companion death or dismissal path likely clears the companion_inventories
table, or the re-recruitment path creates a new companion_data record instead
of reusing the existing one, losing the inventory association.

## Affected Systems

- [x] C++ server source -> c-expert
- [ ] Lua quest scripts -> lua-expert
- [ ] Perl quest scripts -> perl-expert
- [x] Database / SQL -> data-expert
- [ ] Rules / Configuration -> config-expert
- [ ] Client protocol -> protocol-agent
- [ ] Infrastructure / Docker -> infra-expert
