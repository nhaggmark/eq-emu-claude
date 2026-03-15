# Companion Resurrection — Research Notes

## Current State of the Codebase

### Companion Death Flow
- `Companion::Death()` calls `NPC::Death()` (which creates an NPC corpse)
- Then resets `p_depop = false` so the companion entity persists post-death
- `m_death_despawn_timer` fires after `DeathDespawnS` (default 1800s / 30 min)
- Death marks companion as `is_suspended=1` in `companion_data` table
- Group slot is NULLed via `MemberZoned()` — dead companion stays conceptually in group
- Owner gets a message: "You have %d seconds to resurrect them, or they will return home"

### Existing Corpse Creation
- NPC::Death() at attack.cpp:2841 explicitly checks `IsCompanion()` to always create a corpse
- Corpse is a standard NPC corpse with loot (from NPC loot tables)
- Companion corpses currently have whatever loot the source NPC had

### Resurrection Spell Effect (SpellEffect::Revive = 81)
- spell_effects.cpp:1712 — only processes `IsPlayerCorpse()` — NPC corpses ignored
- This is the KEY blocker: companion corpses are NPC corpses, so standard rez doesn't work on them
- Will need either: (a) make companion corpses into player-style corpses, or (b) add companion
  corpse handling alongside the player corpse check

### Companion Spell AI — Rez Already Stubbed
- companion_ai.cpp:1136-1142 — AI_Cleric() has a `SpellType_Resurrect` block that's a placeholder
- Comment: "Rezzing is done via the quest system; placeholder for future extension"
- Comment: "For now skip automatic corpse rezzing (needs corpse targeting logic)"
- The Idle cast priority for Clerics: cure > heal > resurrect dead > buff

### Merc Rez Pattern (Reference)
- merc.cpp:2003-2018 — `GetGroupMemberCorpse()` finds player corpses in range
- Casts rez spell on the corpse via `AIDoSpellCast()`
- Uses `DontRootMeBefore` timer to prevent spam-casting on same corpse
- Only searches for player corpses (via `GetCorpseByOwnerWithinRange`)

### Bot Rez Pattern (Reference)
- botspellsai.cpp:2842-2855 — Searches for rez spells with `SpellEffect::Revive`
- Uses `BotSpellTypes::Resurrect` type
- Only targets player corpses (`IsPlayerCorpse()`)

### SpellType_Resurrect = (1 << 16) — bitmask value 65536
- Already defined in spdat.h
- Already used in companion_spell_sets spell type field (available for data-expert to populate)

## Era-Appropriate Resurrection Spells (Classic-Luclin)

### Cleric
| Spell | ID | Level | Mana | XP Restore | Cast Time |
|-------|-----|-------|------|-----------|-----------|
| Reanimation | ~??? | 12 | ~100 | 0% | 6s |
| Revive | 391 | 27 | 300 | 35% | 6s |
| Resurrection | 392 | 47 | 700 | 90% | 6s |
| Reviviscence | 1524 | 56 | 600 | 96% | 7s |

### Paladin
| Spell | ID | Level | Mana | XP Restore | Cast Time |
|-------|-----|-------|------|-----------|-----------|
| Reanimation | ~??? | 22 | ~100 | 0% | 6s |
| Revive | 391 | 39 | 300 | 35% | 6s |
| Resurrection | 392 | 59 | 700 | 90% | 6s |

### Necromancer
| Spell | ID | Level | Mana | XP Restore | Cast Time |
|-------|-----|-------|------|-----------|-----------|
| Convergence | 1733 | 53 | 700 | 93% | 6s |

Note: Convergence requires Essence Emerald reagent in real EQ. For our companion
system, we should decide whether to require reagents or waive them.

## Key Design Decisions Needed

1. **Corpse Type**: Companion corpses are NPC corpses. The Revive spell effect only
   works on player corpses. Solution needed.

2. **What XP Restoration Means for Companions**: Companions have their own XP
   (companion_xp). Rez XP restore % should restore a portion of companion XP lost
   on death. Need to define XP death penalty for companions first.

3. **Rez Priority**: Multiple dead group members — what order?

4. **Post-Rez State**: Standard EQ rez = low HP, no mana, buffs stripped, but
   companions have their own buff save/restore system.

5. **Reagent Requirement**: Necro Convergence needs Essence Emerald. Companions
   can't get reagents normally. Waive for companions?

6. **Corpse Contains No Loot**: Currently NPC::Death() adds loot to companion
   corpses from NPC loot tables. Need to strip this.

7. **Player Rezzable by Companion**: Should companion clerics be able to rez the
   player character? This would need the standard client rez flow (OP_RezzRequest
   → OP_RezzAnswer → OP_RezzComplete).
