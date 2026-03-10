# BUG-009: Companion NPCs generate zero hate/aggro on mobs

> **Severity:** Critical
> **Reported by:** user
> **Date:** 2026-03-08
> **Feature:** companion-aggro-fixes
> **Status:** Open

---

## Observed Behavior

Recruited NPC companions do not generate any hate/aggro on mobs through any
action — melee hits, spell damage, healing, or abilities like taunt. When
companions deal damage or heal, the mob completely ignores them and stays
glued to whoever initially pulled it (typically the player).

Hate appears broken in all directions: companions cannot pull aggro from
the player, and mobs never shift targets to companions regardless of what
the companions do.

This was tested with a full group composition:
- Player: Enchanter
- Companions: Warrior, Rogue, Wizard, Cleric

None of the companions generated any visible hate on mobs.

## Expected Behavior

Companion NPCs should generate hate through all standard combat mechanics:
- Melee damage should generate hate proportional to damage dealt
- Spell damage should generate hate proportional to damage dealt
- Healing should generate hate on mobs that have the healer on their hate list
- Taunt (warrior) should generate significant hate and force target switch
- All class abilities that affect hate should function normally

The hate/aggro system for companions should work identically to how it works
for bots, mercenaries, or regular NPCs engaging in combat.

## Reproduction Steps

1. Recruit a warrior NPC companion into group
2. Find a mob and engage it (pull to group)
3. Let the warrior companion attack the mob
4. Observe: mob stays on the player, never switches to warrior
5. Repeat with any companion class — none generate hate

## Evidence

User tested with warrior, rogue, wizard, and cleric companions. All four
failed to generate any hate on mobs. Mobs always remained targeted on the
player regardless of companion actions.

## Affected Systems

- [x] C++ server source -> c-expert
- [ ] Lua quest scripts -> lua-expert
- [ ] Perl quest scripts -> perl-expert
- [ ] Database / SQL -> data-expert
- [ ] Rules / Configuration -> config-expert
- [ ] Client protocol -> protocol-agent
- [ ] Infrastructure / Docker -> infra-expert
