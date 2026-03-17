# BUG-032: Damage shields produce INVULNERABLE message instead of dealing damage

> **Severity:** High
> **Reported by:** user
> **Date:** 2026-03-16
> **Feature:** companion-bug-batch-3
> **Status:** Open

---

## Observed Behavior

When a ranger casts Thorns (damage shield) on an NPC companion, every time the companion is hit in melee, a message appears saying the attacker was trying to pierce the companion but they were INVULNERABLE. No damage shield damage is applied to the attacker.

## Expected Behavior

Damage shields should work on companions exactly like they do on players — when the companion is hit in melee, the attacker should take damage from the damage shield.

## Reproduction Steps

1. Have a ranger companion (or player ranger) cast Thorns on an NPC companion
2. Engage in melee combat where the buffed companion takes hits
3. Observe "INVULNERABLE" message instead of damage shield damage

## Investigation Needed

- The INVULNERABLE message is typically a catch-all for damage that can't be applied correctly
- Check how damage shield damage is sourced — the damage source may be the companion NPC, and NPC→NPC damage may be blocked
- Check if there's an invulnerability flag or target restriction preventing DS damage
- Look at the damage shield processing code path for NPC sources

## Affected Systems

- [x] C++ server source → c-expert
