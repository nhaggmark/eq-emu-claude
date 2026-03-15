# Companion Resurrection System — Product Requirements Document

> **Feature branch:** `feature/companion-resurrection`
> **Author:** game-designer
> **Date:** 2026-03-15
> **Status:** Draft

---

## Problem Statement

When a companion dies on our 1-3 player server, the player currently faces a punishing recovery cycle: the dead companion is marked as suspended, its corpse despawns after 30 minutes (or immediately if the timer expires), and the player must travel back to the original NPC's spawn location to re-recruit them. During this time, the group is down a member in content balanced for small groups — meaning a single companion death can cascade into a wipe.

This is especially painful for healer or tank companions whose loss immediately threatens the group's viability. In standard EverQuest, resurrection spells exist precisely to handle this scenario, but the current companion system has no resurrection capability. The infrastructure is partially in place — companions already leave corpses on death and have a 30-minute despawn timer with a "resurrect them" message — but the actual resurrection mechanic is unimplemented.

For a server designed around 1-3 players relying heavily on NPC companions, in-combat and post-combat recovery must be robust. Companion resurrection is the missing link between companion death and group recovery.

## Goals

1. **Enable autonomous companion resurrection**: Healer companions (clerics and paladins) automatically resurrect dead group members after combat ends, using era-appropriate resurrection spells with authentic EQ spell effects and XP restoration values. Necromancer companions use a lore-appropriate dark alternative (Convergence reflavored as death-energy channeling).
2. **Allow companion healers to resurrect the player character**: If the player dies but their companion cleric/paladin survives, the companion can rez the player — a critical safety net for a small-group server.
3. **Establish companion death penalties with meaningful rez incentives**: Companions lose XP on death. Higher-level rez spells restore more of that lost XP, making healer class and level choices strategically meaningful.
4. **Create clean companion corpses**: Companion corpses serve as rez targets only — no loot, no clutter — while remaining visible and targetable for the rez duration.

## Non-Goals

- **Manual player-commanded resurrection**: This version implements autonomous rez only. A future version may add a `!rez [target]` command for player-directed rez control.
- **Cross-zone resurrection**: Companions can only rez corpses in the same zone. If the group wipes and zones out, dead companions must be re-recruited.
- **Resurrection sickness or debuffs**: Standard EQ rez already applies low HP/mana and buff strip. No additional debuffs are added.
- **Custom resurrection visual effects**: The standard EQ spell casting animation and particles are sufficient. No custom visual effects.
- **Rez spells from post-Luclin expansions**: Only Classic through Luclin era spells are eligible. Specifically excluded: Divine Resurrection, Gift of Resurrection, and any PoP-era or later spells.

## User Experience

### Player Flow

1. **Combat occurs.** The group engages enemies. During the fight, one or more companions (or the player) may die.

2. **Companion dies.** On death, the companion leaves a corpse at the death location. The corpse contains no loot. The player sees: *"Lashun has fallen in battle! You have 1800 seconds to resurrect them, or they will return home."* The companion is removed from the group's active member list but conceptually remains in the group for rez purposes.

3. **Combat ends.** After the last enemy is killed or disengages, healer companions wait 10 seconds (post-combat settling period) before attempting resurrection. During this time, they may meditate to recover mana if needed.

4. **Healer selects rez target.** The healer companion scans for dead group member corpses within 200 units. Priority order: (a) player character corpse first, (b) rez-capable companions (clerics > paladins > necromancers — rezzing a rezzer enables chain recovery), (c) other healers (druids, shamans — they can heal the living), (d) tank companions, (e) DPS companions. Among equal-priority targets, the closest corpse is chosen.

5. **Mana check.** If the healer has enough mana to cast their best available rez spell, they proceed. If not, they sit and meditate until they have sufficient mana, then stand and cast. A group chat message announces the meditation (see Resurrection Dialogue below).

6. **Rez is cast.** The healer targets the corpse and begins casting the resurrection spell. The group sees the companion's deity-appropriate dialogue (see Resurrection Dialogue below). The spell has its normal cast time (6-7 seconds). The healer stands still during casting (standard EQ casting behavior).

7. **Companion auto-accepts rez.** For companion corpses, the rez is automatically accepted — no consent dialog. The companion's bond to their ally means the soul answers the call immediately. The dead companion is restored to life at the corpse location with:
   - HP set to a percentage based on the rez spell (roughly 10-20% of max HP)
   - Mana set to 0
   - All buffs stripped
   - A percentage of death XP loss restored based on the rez spell used
   The companion immediately re-joins the group and resumes following the owner. A completion message is shown to the group.

8. **Player rez (if player died).** If the player character's corpse is found, the companion casts rez on the player corpse. The standard EQ consent dialog appears for the player: the player clicks Accept or Decline. On accept, standard EQ rez behavior applies (teleport to corpse, restore XP, low HP/mana, buffs stripped).

9. **Multiple deaths.** If multiple group members died, the healer rezzes them one at a time in priority order, with normal spell cast times and recast delays between each rez. If the healer runs out of mana, they meditate between rezzes.

10. **No resurrection available.** If no healer companion survives, or the surviving healers are too low level for any rez spell, no automatic rez occurs. The 30-minute despawn timer continues. When it expires, dead companions are marked as dismissed and can be re-recruited from their original NPC type.

### Resurrection Dialogue

Resurrection is a momentous act in Norrath — the recall of a soul from the threshold of the Plane of Tranquility. Companion dialogue should reflect the weight of this act and be colored by the companion's deity. EQ dialogue is terse — one or two lines maximum.

**Cleric/Paladin examples (deity-themed):**

| Deity | Casting Line | Completion Line |
|-------|-------------|-----------------|
| Rodcet Nife (Prime Healer) | "[Name] says, 'By the Prime Healer's grace, I call your soul back.'" | "[Dead] has been resurrected by [Name]." |
| Tunare (Mother of All) | "[Name] says, 'The Mother of All calls you back from the threshold.'" | "[Dead] has been resurrected by [Name]." |
| Innoruuk (Prince of Hate) | "[Name] says, 'You do not have permission to die. Return.'" | "[Dead] has been resurrected by [Name]." |
| Mithaniel Marr (Lightbearer) | "[Name] says, 'The Lightbearer has not finished with you yet.'" | "[Dead] has been resurrected by [Name]." |
| Bertoxxulous (Plague Bringer) | "[Name] says, 'Your rot is not yet complete. Rise.'" | "[Dead] has been resurrected by [Name]." |
| Cazic-Thule (The Faceless) | "[Name] says, 'Fear still has use for you. Stand.'" | "[Dead] has been resurrected by [Name]." |
| Generic / unknown deity | "[Name] says, 'I call upon the powers that bind us. Return to the living.'" | "[Dead] has been resurrected by [Name]." |

**Necromancer Convergence:**

| Deity | Casting Line | Completion Line |
|-------|-------------|-----------------|
| Any | "[Name] says, 'The death-energy lingers... I will bind your soul to it.'" | "[Dead] has been raised by [Name]." |

Note the necromancer uses "raised" rather than "resurrected" — a deliberate thematic distinction. The necromancer does not invoke divine power; they channel residual death-energy from recently slain enemies.

**Meditation announcement:**
- "[Name] says, 'I must gather my strength before I can call anyone back.'"

### Example Scenario

A level 45 warrior player is in Cazic-Thule with three companions: Priestess Grel (level 48 cleric of Cazic-Thule), Togahn the Faithful (level 43 paladin of Mithaniel Marr), and Vethras the Pale (level 50 necromancer). The group pulls a lizardman war party and the fight goes badly.

**Mid-fight:** The necromancer dies to a caster mob. Their corpse appears on the ground (empty, no loot). The player sees: "Vethras has fallen in battle! You have 1800 seconds to resurrect them, or they will return home."

**Combat ends:** The remaining three defeat the lizardmen. After 10 seconds, the cleric companion checks for dead group members. She finds the necromancer's corpse within range.

**Mana check:** The cleric has 420/1200 mana. Resurrection costs 700 mana. She sits to meditate: "Priestess Grel says, 'I must gather my strength before I can call anyone back.'" After recovering to 700+ mana (a few minutes of meditation), she stands.

**Rez cast:** "Priestess Grel says, 'Fear still has use for you. Stand.'" Six seconds later, the spell completes. The necromancer appears at their corpse location with ~15% HP, 0 mana, and no buffs. They receive 90% of the XP lost on death. The group sees: "Vethras has been resurrected by Priestess Grel."

**Recovery:** The necromancer immediately re-joins the group, begins following the player, and starts mana recovery. Priestess Grel begins buffing the group.

## Game Design Details

### Mechanics

#### Eligible Rez Classes and Spells

Only classes with resurrection spells in the Classic-Luclin era may rez. The companion must have the spell in their `companion_spell_sets` entry and be at or above the required level.

| Class | Spell | Spell ID | Level | Mana | XP Restore % | Cast Time |
|-------|-------|----------|-------|------|--------------|-----------|
| Cleric | Reanimation | TBD | 12 | ~100 | 0% | 6s |
| Cleric | Revive | 391 | 29 | 300 | 0% | 6s |
| Cleric | Resuscitate | TBD | 39 | ~400 | 50% | 6s |
| Cleric | Resurrection | 392 | 49 | 700 | 90% | 6s |
| Cleric | Reviviscence | 1524 | 56 | 600 | 96% | 7s |
| Paladin | Reanimation | TBD | 22 | ~100 | 0% | 6s |
| Paladin | Revive | 391 | 49 | 300 | 0% | 6s |
| Paladin | Resurrection | 392 | 59 | 700 | 90% | 6s |
| Necromancer | Convergence | 1733 | 53 | 700 | 93% | 6s |

**Important:** Mana costs and XP restore percentages marked with ~ are approximate. All spell IDs marked "TBD" and all values in this table must be verified against the `spells_new` database table by the architect. Third-party sources disagree on exact values — the database is authoritative.

The healer always selects their **highest-level rez spell** they can cast (have enough mana for and meet the level requirement). Higher rez = more XP restored.

**Note:** Spell IDs marked "TBD" must be confirmed from the `spells_new` database table by the architect during the architecture phase.

#### Necromancer Convergence — Death-Energy Justification

In standard EverQuest, Convergence requires an Essence Emerald — created only by casting Sacrifice on a willing player over level 45, killing them at XP cost. A companion necromancer cannot autonomously harvest this component from a group member. This is both mechanically and narratively impossible.

**Design resolution:** Companion necromancers use Convergence without the Essence Emerald reagent. The lore justification is that the necromancer draws on **residual death-energy from recently killed enemies** — the ambient necromantic power released by combat deaths serves as a substitute for the Essence Emerald's stored life force. This is consistent with the necromancer class fantasy of manipulating death energy, and has a natural gameplay gate: it only works after combat (when enemies have recently died), which aligns perfectly with the "rez after combat only" design.

This approach is approved by the lore-master as a valid adaptation that respects the necromancer's thematic identity while making them functional in the companion system. The necromancer's rez is explicitly framed differently from the divine rez of clerics/paladins — they "raise" rather than "resurrect."

#### Companion XP Death Penalty

When a companion dies, they lose a percentage of the XP required for their current level. This makes death meaningful and gives rez spells tangible value.

- **Death XP loss**: Configurable via a rule (suggested default: 10% of current level's XP requirement)
- **Rez XP restoration**: The rez spell's XP restore percentage is applied to the amount lost
  - Example: A level 40 companion dies. Current level XP requirement = 1,600,000. They lose 160,000 XP. A 90% rez restores 144,000 XP, so the net loss is only 16,000 XP. A 0% rez (Revive) restores nothing — the full 160,000 is lost.
- **Level-down protection**: If XP loss would drop the companion below level 1 or below their recruited level, XP is floored at the minimum for that level. Companions cannot de-level.
- **Effective penalty by rez quality**: With a 96% rez (Reviviscence), the penalty is negligible (4% of 10% = 0.4% of level XP). With a 0% rez (Revive), the full death penalty applies. This rewards having a high-level cleric.

#### Rez Targeting and Priority

When multiple group members are dead, the healer selects targets in this order:

1. **Player character** — Always first. The player's survival is paramount.
2. **Rez-capable companions** — Rezzing a rezzer enables chain-rezzing of remaining dead. Sub-priority: Clerics > Paladins > Necromancers (clerics have the best rez spells).
3. **Other healer companions** — Druids and shamans cannot rez, but they can heal the living. Rez them next to restore healing capacity.
4. **Tank companions** — Tanks protect the group from further danger.
5. **DPS companions** — Last priority since the group can survive without them.

Within the same priority tier, the **closest corpse** is chosen (minimizing movement).

#### Post-Combat Delay

Resurrection attempts begin **10 seconds after combat ends** (after the healer's `IsEngaged()` returns false and a settling timer expires). This:
- Allows mana to begin regenerating
- Prevents the healer from interrupting their own combat actions
- Feels natural and authentic — the healer assesses the situation before acting

#### Mana Management

If the healer lacks mana to cast their best rez spell, the AI follows this sequence:
1. Check if a lower-tier rez spell is affordable (e.g., Revive at 300 mana instead of Resurrection at 700)
2. If any rez spell is affordable, use it (lower XP restore is better than no rez)
3. If no rez spell is affordable, sit and meditate
4. Announce via group say: "[Name] says, 'I must gather my strength before I can call anyone back.'"
5. When mana is sufficient for the best available rez, stand and cast
6. Resume normal idle behavior after all dead are rezzed

#### Companion Corpse Behavior

- **No loot**: Companion corpses contain no items. Equipment is persisted separately in `companion_inventories`.
- **Targetable**: Corpses must be targetable by the rez caster (standard EQ corpse targeting).
- **Decay timer**: 30 minutes (existing `DeathDespawnS` rule, already implemented).
- **Appearance**: Standard NPC corpse appearance matching the companion's race/model.
- **On decay**: If the timer expires without rez, the companion is marked as dismissed (existing behavior). The player can re-recruit from any NPC of the same type.

#### Player Character Resurrection by Companion

When a companion healer finds the player's corpse:
- The companion casts the rez spell on the player corpse
- The standard EQ rez consent dialog is sent to the player client (`OP_RezzRequest`)
- The player clicks Accept or Decline
- On Accept: Standard EQ resurrection behavior (XP restore, teleport to corpse, low HP/mana)
- On Decline: The companion skips this target and moves to the next dead group member

This uses the existing client rez infrastructure — no new packet types needed.

#### Rez After Combat Only (Safety Rule)

Resurrection is only attempted when the healer is **not in combat** (idle cast check, not engaged cast check). This prevents:
- Healers wasting mana on rez during active combat when they should be healing the living
- The long cast time (6-7s) being interrupted by incoming damage
- Awkward mid-fight rez/death cycling

#### Recast Delay

After casting a rez spell, the standard spell recast delay applies (typically 20 seconds for rez spells). This prevents instant chain-rezzing and creates natural pacing.

### Balance Considerations

**Why this doesn't trivialize death:**
- Rez requires a surviving healer with rez capability (class + level + mana)
- If the group wipes completely, no rez is possible — standard re-recruitment applies
- XP death penalty still applies (partially mitigated by rez, but never zero with rez)
- Post-rez companions are severely weakened (low HP, 0 mana, no buffs) — a second pull before recovery can be fatal
- Mana cost of rez spells is significant — the healer may not have enough for a heal right after rezzing
- 10-second post-combat delay + cast time + recast delay = ~40 seconds per rez minimum
- Deity-themed dialogue adds narrative weight — rez feels like a significant act, not a button press

**Group-wipe scenario:** If all companions and the player die, rez is unavailable. The player respawns at their bind point and must re-recruit companions. Death has real consequences — rez mitigates but does not eliminate the penalty.

**Solo player scenario (1 player, no healer companion):** Rez is unavailable unless the player has recruited a healer companion. This creates a natural incentive to include at least one healer in the group composition.

**Multiple healer scenario:** If multiple healer companions survive, only one attempts rez at a time (the one with the highest-level rez spell). The others resume normal idle behavior (buffing, healing the living).

### Era Compliance

All resurrection spells referenced are available in the Classic through Luclin era:
- **Reanimation**: Classic (Cleric 12, Paladin 22) — corpse-summon/0% rez, verify exact behavior in spells_new
- **Revive**: Classic (Cleric 29, Paladin 49)
- **Resuscitate**: Classic (Cleric 39)
- **Resurrection**: Classic (Cleric 49, Paladin 59)
- **Reviviscence**: Kunark (Cleric 56) — available in our era
- **Convergence**: Kunark (Necromancer 53) — available in our era, reagent waived with lore justification

No post-Luclin spells are used. Specifically excluded:
- Divine Resurrection (post-Luclin)
- Gift of Resurrection (Gates of Discord)
- Any PoP-era or later rez spells
- Alternate Ability rez (AA rez came later and is out of era scope)

Druids and shamans do NOT have resurrection spells in the Classic-Luclin era and are excluded from the rez-casting system (they remain high-priority rez targets due to their healing value).

## Affected Systems

- [x] C++ server source (`eqemu/`)
  - `zone/companion.cpp` / `zone/companion_ai.cpp` — Rez AI logic, corpse targeting, post-rez state restoration, death XP penalty
  - `zone/spell_effects.cpp` — Extend `SpellEffect::Revive` handler to support companion corpses
  - `zone/corpse.cpp` — Companion corpse handling (no-loot, rezzable state, companion metadata)
  - `zone/attack.cpp` — Ensure companion corpse creation strips loot
  - `zone/companion.h` — New methods for rez state management
- [ ] Lua quest scripts (`akk-stack/server/quests/`)
- [ ] Perl quest scripts (maintenance only)
- [x] Database tables (`peq`)
  - `companion_spell_sets` — Add rez spells for clerics, paladins, necromancers
  - `companion_data` — May need XP-loss-on-death tracking field
  - `rule_values` — New rules for rez behavior tuning
- [x] Rule values
  - Companion rez enabled/disabled toggle
  - Companion XP death penalty percentage
  - Post-combat rez delay (seconds)
  - Rez range (units)
  - Reagent waiver toggle
- [ ] Server configuration
- [ ] Infrastructure / Docker

## Dependencies

- **BUG-012 fix (completed)**: Equipment persistence on death — companion gear is saved to `companion_inventories` before corpse creation. This is already implemented.
- **BUG-028 fix (completed)**: Death() handler hardened with direct SQL fallback — ensures companion_data is always updated on death.
- **Companion spell casting AI overhaul (completed)**: `companion_spell_sets` priorities are properly differentiated for all 12 classes.
- **Death despawn timer (already implemented)**: The 30-minute `DeathDespawnS` timer already exists and creates a rez window.
- **Companion corpse creation (already implemented)**: `NPC::Death()` at attack.cpp:2841 already checks `IsCompanion()` to always create a corpse.

No new dependencies need to be completed before this feature can be built.

## Open Questions

1. **Verify all spell data from `spells_new`**: Spell IDs for Reanimation and Resuscitate are unknown (marked TBD). Additionally, mana costs and XP restoration percentages vary across third-party sources. The architect must query `spells_new` for all rez spells with `SpellEffect::Revive` (effect ID 81) and confirm exact spell IDs, levels, mana costs, and base_value (XP restore %) for each. The database is the authoritative source.

2. **Companion XP loss on death — is it already implemented?** The `m_companion_xp` field exists and `AddExperience()` is implemented, but the current `Death()` method does not deduct XP. This feature needs to add the death penalty. The architect should confirm the correct formula and rule name.

3. **NPC corpse vs. player corpse for rez targeting**: The current `SpellEffect::Revive` handler (spell_effects.cpp:1712) only processes `IsPlayerCorpse()`. Companion corpses are NPC corpses. The architect must determine the best approach — either make companion corpses a special type, or extend the Revive handler to check for companion corpses.

4. **Multiple surviving healers coordination**: The design says "only the one with the highest rez spell attempts." The architect should determine how to coordinate this — likely a check in the idle cast path that skips rez if another companion is already casting one.

5. **Deity lookup for dialogue**: Companion NPCs have a deity field in `npc_types`. The architect should confirm this is populated and accessible at runtime for selecting the correct rez dialogue lines. If the deity field is 0 or unpopulated for many NPCs, the system must fall back to class-based generic dialogue (e.g., "calls upon divine power" for clerics/paladins, death-energy framing for necromancers).

## Acceptance Criteria

- [ ] When a companion dies, a corpse remains at the death location with no loot items
- [ ] After combat ends (10s delay), a surviving healer companion with a rez spell targets the nearest eligible dead group member corpse and casts resurrection
- [ ] Companion corpses are automatically accepted (no consent dialog) and the companion respawns at the corpse location with low HP, 0 mana, and no buffs
- [ ] The rezzed companion automatically re-joins the owner's group and resumes following
- [ ] Player character corpses are rezzable by companion healers via the standard rez consent dialog (OP_RezzRequest → player Accept/Decline)
- [ ] Rez priority order is observed: player > rez-capable companions > other healers > tanks > DPS
- [ ] If the healer lacks mana, they meditate first, announce it, then rez when mana is sufficient
- [ ] Each rez spell restores the correct percentage of death XP loss based on the spell's XP restoration value
- [ ] Companions lose a configurable percentage of level XP on death (death penalty)
- [ ] Only era-appropriate rez spells (Classic-Luclin) are used: Reanimation, Revive, Resuscitate, Resurrection, Reviviscence (CLR/PAL), Convergence (NEC)
- [ ] Necromancer Convergence works without requiring the Essence Emerald reagent
- [ ] The 30-minute corpse decay timer still applies — if no rez occurs, the companion is marked dismissed
- [ ] Group chat messages announce rez casting with deity-appropriate dialogue and completion
- [ ] Multiple dead companions are rezzed one at a time with proper recast delays
- [ ] If no healer companion survives, no rez is attempted (existing death/dismiss flow continues)
- [ ] A rule toggle exists to enable/disable companion rez globally
- [ ] The system works for 1 player + 1-5 companions (the full range of our server's group sizes)

---

## Appendix: Technical Notes for Architect

### Existing Infrastructure

The following systems are already partially or fully in place and should be leveraged:

1. **Companion corpse creation**: `NPC::Death()` at `attack.cpp:2841` checks `IsCompanion()` and always creates a corpse. However, this currently includes NPC loot from loot tables — that needs to be stripped for companion corpses.

2. **Death despawn timer**: `Companion::Death()` starts `m_death_despawn_timer` (30 min). The companion entity persists post-death (depop is reset to false). `Companion::Process()` checks the timer at line 1774.

3. **Rez spell AI stub**: `companion_ai.cpp:1136-1142` has an existing `SpellType_Resurrect` block in `AI_Cleric()` that is a placeholder reading: "needs corpse targeting logic."

4. **Merc rez pattern**: `merc.cpp:2003-2018` and `merc.cpp:3719-3738` implement `GetGroupMemberCorpse()` — finds player corpses in range and casts rez. This pattern can be adapted for companions (extended to also find companion NPC corpses).

5. **SpellType_Resurrect**: Already defined as `(1 << 16)` in `spdat.h`. Available for use in `companion_spell_sets`.

6. **SpellEffect::Revive (effect 81)**: The spell effect handler at `spell_effects.cpp:1707-1720` currently only processes `IsPlayerCorpse()`. This is the key extension point — it needs to also handle companion NPC corpses.

7. **Corpse::CastRezz()**: `corpse.cpp:2290-2359` — the existing rez-on-corpse method sends `OP_RezzRequest` to the player client via world server. This is the flow for player character rez. Companion rez needs a separate path that auto-accepts.

8. **NPC deity field**: `npc_types.deity` stores the NPC's deity ID. This should be used to select deity-themed rez dialogue.

### Suggested Rule Names

- `Companions:RezEnabled` (bool, default true) — Master toggle
- `Companions:RezPostCombatDelayS` (int, default 10) — Seconds after combat before rez attempt
- `Companions:RezRange` (int, default 200) — Max distance to corpse for rez targeting
- `Companions:XPDeathPenaltyPct` (int, default 10) — % of current level XP lost on death
- `Companions:RezWaiveReagents` (bool, default true) — Waive reagent requirements for companion casters

### Key Spell Effect Reference

The `SpellEffect::Revive` effect (ID 81) uses `base_value` in the spell data to determine XP restoration percentage. The `spells_new` table stores this per-spell. The architect should verify the exact `base_value` field mapping for each rez spell listed in this PRD.

### Companion Corpse Type Consideration

The core challenge is that companion corpses are NPC corpses (`IsNPCCorpse()` returns true) but need to be rezzable like player corpses. Possible approaches:
- Add a `IsCompanionCorpse()` check alongside `IsPlayerCorpse()` in the Revive effect handler
- Store companion metadata (companion_id, owner_char_id) on the Corpse object when created from a companion death
- Create a new companion-specific rez path that bypasses the normal OP_RezzRequest flow (since companions auto-accept)

The architect should determine which approach minimizes code changes while maintaining correctness.

### Deity Dialogue Implementation

The rez dialogue table needs a data-driven approach (not hardcoded strings). Suggested: a lookup table mapping deity IDs to casting lines and completion lines. The architect should determine whether this lives in the database, a Lua table, or a C++ map. The generic fallback line covers companions whose deity is 0 or unrecognized.

---

> **Next step:** Pass this PRD to the **architect** for technical feasibility
> assessment and implementation planning.
