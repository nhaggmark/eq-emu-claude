# BUG-016: Stackable item quantity lost when trading to companion

> **Severity:** Medium
> **Reported by:** user
> **Date:** 2026-03-10
> **Feature:** improved-companion-stats
> **Status:** Open

---

## Observed Behavior

When a player trades a stack of items (e.g., 20 arrows) to a companion,
only the item ID is stored in `m_equipment[slot]`. The stack count /
charges are silently discarded. The companion_inventories database table
has a `charges` column but it is always saved as 0 and never read back.

The trade handler in global_npc.lua calls `inst:GetID()` to get the item
type but never reads `inst:GetCharges()`. The C++ `GiveItem()` function
only accepts an item_id, not a quantity.

Since NPCs have effectively unlimited ammo (they never consume it), this
is primarily a resource loss issue — the player loses N-1 items from a
stack of N for no benefit.

## Expected Behavior

When trading a stack of items to a companion, either:
- The full stack should be stored (charges column populated), or
- Only 1 item should be removed from the player's stack (returning the
  rest), since the companion only needs the item type

## Reproduction Steps

1. Have a stack of 20 arrows in inventory
2. Trade the stack to a companion
3. Observe: all 20 arrows are consumed from the player's inventory
4. Run !equipment on the companion: shows 1 arrow (no quantity)
5. The 19 extra arrows are destroyed

## Affected Systems

- [x] C++ server source → c-expert
- [x] Lua quest scripts → lua-expert
- [ ] Perl quest scripts → perl-expert
- [ ] Database / SQL → data-expert
- [ ] Rules / Configuration → config-expert
- [ ] Client protocol → protocol-agent
- [ ] Infrastructure / Docker → infra-expert
