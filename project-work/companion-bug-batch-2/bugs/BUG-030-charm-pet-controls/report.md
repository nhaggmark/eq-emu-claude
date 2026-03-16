# BUG-030: Enchanter charm pet controls UX broken

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-03-15
> **Feature:** companion-bug-batch-2
> **Status:** Open

---

## Observed Behavior

The pet controls UX for enchanter charmed NPCs does not work correctly. Only the 'attack' option seems to do anything. When the enemy breaks charm, the pet controls UX does not always disappear appropriately.

## Expected Behavior

Pet controls should work correctly for charmed NPCs on the Titanium client — attack, follow, sit, guard, etc. When charm breaks, the pet controls should disappear immediately.

## Reproduction Steps

1. Play as enchanter (Chelon, level 32)
2. Charm an NPC
3. Try using pet control buttons (attack, follow, sit, guard, etc.)
4. Only 'attack' works
5. Let charm break
6. Pet controls may persist on screen

## Investigation Needed

- Audit how charm spells interact with the pet control system
- Check Titanium client pet control opcodes and how the server handles them
- Verify charm break properly cleans up the pet relationship
- Check if this is a companion system issue or a general charm issue

## Affected Systems

- [x] C++ server source → c-expert
- [ ] Lua quest scripts → lua-expert
- [x] Client protocol → protocol-agent
