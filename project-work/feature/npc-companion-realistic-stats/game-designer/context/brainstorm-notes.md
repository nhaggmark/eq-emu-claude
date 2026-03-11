# Brainstorm Notes — NPC Companion Realistic Stats

## Starting Point: Gap Analysis Review

From the companion-mechanics-reference.md (22 gaps identified), I organized
them by player impact and dependency:

### Dependency Graph

```
Phase 1: Weapon Damage & Delay (Gaps 1, 2)
  └── Foundation: weapons become meaningful
       └── Phase 2 depends on this: damage bonus uses weapon delay
       
Phase 2: Combat Skills & Avoidance (Gap 5, 3, 10)
  ├── Class-appropriate defense skills (dodge, parry, riposte, block)
  ├── Class-appropriate offense skills
  ├── Damage bonus from weapon delay (requires Phase 1)
  └── Triple attack for appropriate classes
  
Phase 3: Stats & Survivability (Gaps 6, 9, 4, 11)
  ├── STA -> HP conversion (gear STA matters)
  ├── Sitting HP regen bonus 
  ├── Defense skill AC divisor alignment
  └── (Optional) Individual stat calculation cleanup
  
Phase 4: Spell System Tuning (No gap #, but user requested)
  ├── Spell casting priority refinement
  ├── Heal threshold tuning per class
  ├── Buff management improvements
  └── Mana conservation decisions

Phase 5: Polish (Gaps 12, 14, 8, 13)
  ├── Resist caps
  ├── Focus effects testing/implementation
  ├── (Stretch) Click effects from items
  └── (Stretch) Augment support
```

### Key Design Decisions

1. **Phase 1 is the game-changer.** Right now, giving a warrior companion a
   Lamenter's Blade vs a Rusty Longsword produces zero damage difference.
   This single change transforms the entire gearing loop.

2. **Backward compatibility with npc_types.** When a companion has NO weapon
   equipped, we still need the npc_types base damage to work. The design
   should be: "use weapon damage when weapon equipped, fall back to
   npc_types when no weapon." This preserves existing behavior for
   unarmed companions and monks.

3. **Skill values are the hidden landmine.** Most PEQ NPCs have skill values
   of 0 or very low. When companions take the Client/Bot avoidance path
   (because IsOfClientBot()=true), they check skill values for dodge/parry/
   riposte. With skills at 0, a level 60 warrior companion literally cannot
   parry. We need class-level-appropriate skill assignment.

4. **STA->HP is important for the gearing loop.** If STA from gear doesn't
   add HP, then a STA item is nearly worthless on a companion. This breaks
   the expectation that "gear makes companions stronger."

5. **Damage bonus is a significant DPS gap.** Level 28+ warrior-class
   characters get a damage bonus based on weapon delay that adds to every
   hit. Without this, companion DPS falls behind at higher levels.

6. **Triple attack matters for melee DPS.** Warriors, monks, and rangers
   at high levels should be getting triple attacks. Without it, their
   sustained DPS is noticeably lower than expected.

### What Should NOT Change

- Mana regen system (already well-implemented)
- Buff system (fully functional)
- Weapon procs (working)
- Item stat bonuses via CalcItemBonuses (working)
- Haste from items and spells (working)  
- HP regen from items and spells (working)
- Companion spell AI (working, Phase 4 is tuning only)
- Formation system, sit/stand, follow behaviors
- Level scaling system (linear scaling is fine)
- StatScalePct global tuning knob

### Balance Considerations for 1-3 Player Server

The companion system IS the party for a solo player. Companions need to be
effective enough to fill real group roles. The current gaps mean:

- A warrior companion with BiS gear tanks about the same as one with vendor
  trash (weapons don't matter, skills are low)
- A rogue companion with an epic weapon does the same DPS as one with a
  rusty short sword
- STA gear doesn't make tanks tankier

These changes will significantly increase companion effectiveness when
well-geared. This is intentional and desired — gear should matter. The
existing StatScalePct rule and per-phase tuning knobs allow dialing back
if needed.

### Complexity Estimates

| Change | Complexity | Rationale |
|--------|-----------|-----------|
| Weapon damage for melee | Large | Core attack path modification |
| Weapon delay for attack speed | Large | Attack timer modification |
| Damage bonus | Medium | Add calculation, depends on weapon delay |
| Class-appropriate skills | Medium | Data + assignment logic |
| STA->HP | Medium | New calculation path |
| Sitting HP regen | Small | Add bonus to CalcHPRegen |
| Triple attack | Small | Set special ability based on class/level |
| Defense AC divisor | Small | Path change in ACSum |
| Resist caps | Small | Add cap enforcement |
| Focus effects | Medium | Testing + possible fixes |
| Spell AI tuning | Medium | Multiple class adjustments |

