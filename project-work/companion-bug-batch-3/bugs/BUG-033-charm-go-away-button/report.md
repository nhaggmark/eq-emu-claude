# BUG-033: Charm pet "Go Away" button does nothing

> **Severity:** Medium
> **Reported by:** user
> **Date:** 2026-03-16
> **Feature:** companion-bug-batch-3
> **Status:** Open

---

## Observed Behavior

When an enchanter charms an NPC and uses the "Go Away" pet control button, nothing happens. The charmed NPC remains.

## Expected Behavior

"Go Away" on a charmed NPC should break the charm and release the NPC, same as it works in standard EQ.

## Reproduction Steps

1. Play as enchanter (Chelon, level 32)
2. Charm an NPC
3. Click "Go Away" on the pet controls
4. Nothing happens — NPC remains charmed

## Investigation Needed

- Check how "Go Away" pet command is handled for charmed pets vs summoned pets
- In standard EQ, "Go Away" on a charmed mob breaks charm
- Check if the pet command handler has a case for PetCommand::GoAway on charmed NPCs
- Related to BUG-030 (charm pet controls) — diagnostic logging was added in last fix

## Affected Systems

- [x] C++ server source → c-expert
- [x] Client protocol → protocol-agent
