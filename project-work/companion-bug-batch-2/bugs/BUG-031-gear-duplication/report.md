# BUG-031: Gear duplication when trading to companions

> **Severity:** Critical
> **Reported by:** user
> **Date:** 2026-03-15
> **Feature:** companion-bug-batch-2
> **Status:** Open

---

## Observed Behavior

When giving gear to NPC companions, the companion often says "thank you" and then responds with "I have no use for this, you can have it back." When checking their equipment, the gear WAS equipped on the companion BUT was also duplicated and returned to the player. This creates duplicate items.

## Expected Behavior

When trading gear to a companion:
- If the companion can equip it: equip it, say thank you, no item returned
- If the companion cannot equip it: return the item, say they can't use it
- Never both equip AND return the same item

## Reproduction Steps

1. Have an NPC companion in group
2. Trade an equippable item to the companion
3. Companion says "thank you" (item equipped)
4. Companion also says "I have no use for this, you can have it back" (item returned)
5. Check companion equipment — item IS equipped
6. Check player inventory — duplicate item was also returned

## Investigation Needed

- This is likely a Lua/C++ synchronization issue — Lua checks and C++ checks are running independently and reaching different conclusions
- The trade handler may be processing the item through two code paths
- BUG-018 was a previous duplication fix — this may be a regression or an incomplete fix
- Audit the full trade flow: event_trade → Lua handler → C++ equip → response

## Affected Systems

- [x] C++ server source → c-expert
- [x] Lua quest scripts → lua-expert
- [ ] Database / SQL → data-expert
