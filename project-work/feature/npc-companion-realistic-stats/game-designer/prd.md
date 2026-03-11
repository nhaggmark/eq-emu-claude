# npc-companion-realistic-stats — Product Requirements Document

> **Feature branch:** `feature/npc-companion-realistic-stats`
> **Author:** game-designer
> **Date:** 2026-03-10
> **Status:** Draft
> **Lore review:** Approved (2026-03-10)

---

## Problem Statement

On this 1-3 player server, companions ARE the group. A solo player's warrior
companion is their main tank. A rogue companion is their primary melee DPS.
The companion system is not an optional convenience — it is the foundation
of all gameplay.

Despite having a fully functional equipment system that lets players gear up
their companions, **equipment currently has almost no effect on companion
combat performance.** The core mechanics that translate gear into power are
broken or missing:

1. **Weapons are cosmetic.** A companion wielding a Lamenter's Blade deals
   the same base damage as one wielding a Rusty Longsword. Melee damage
   comes from the NPC's database entry (`npc_types.max_dmg`), not from the
   equipped weapon's damage value. This is the single largest gap — it
   means the entire melee gearing loop is meaningless.

2. **Weapon speed is ignored.** Attack speed comes from `npc_types.attack_delay`,
   not from the equipped weapon's delay. A fast dagger swings at the same speed
   as a slow two-hander. Weapon choice has no tactical dimension.

3. **Defensive skills are broken or missing.** Companions take the Client/Bot
   avoidance path (checking dodge, parry, riposte, block skills) but most
   NPCs in the database have these skills at zero or very low values. A level
   60 warrior companion may be completely unable to parry or riposte attacks,
   making them a poor tank regardless of gear.

4. **STA does not increase HP.** Unlike player characters where Stamina from
   gear adds significant hit points, companion HP comes directly from the
   NPC database entry. Equipping STA gear on a companion has no HP benefit,
   breaking player expectations about how stats work.

5. **Damage bonus is missing.** Melee classes get a damage bonus at level 28+
   based on weapon delay that adds to every hit. Companions never receive
   this bonus, causing their DPS to fall increasingly behind at higher levels.

The net effect: players invest time finding and equipping gear on companions,
but the companions fight almost identically whether naked or in best-in-slot
equipment. This undermines the gearing loop, reduces the incentive to pursue
better items, and makes companions feel flat and unrewarding compared to
actual player characters.

This feature incrementally closes these gaps across five phases, each
independently shippable and testable, transforming companions from entities
that merely wear gear into entities that fight like properly-equipped
characters.

## Goals

1. **Weapons matter.** A companion's melee damage and attack speed are
   determined by equipped weapons, not by static database values. Upgrading
   a weapon produces a measurable and visible DPS increase.

2. **Gear drives survivability.** Armor AC, STA-to-HP conversion, and
   proper defensive skill values combine so that a well-geared tank
   companion is dramatically more survivable than a poorly-geared one.

3. **Class-appropriate combat.** Companions use dodge, parry, riposte,
   block, dual wield, double attack, and triple attack at rates appropriate
   for their class and level — matching what a player of that class would
   have at the same level.

4. **No regression.** Everything that works today (buffs, procs, haste,
   mana regen, spell AI, formations, commands) continues to work. Each
   phase is additive.

5. **Tunable.** Key parameters (skill scaling, damage bonus application,
   STA-to-HP factor) are exposed as server rules or configurable values
   so that balance can be adjusted without code changes.

6. **Incremental delivery.** Each phase is independently shippable,
   testable, and valuable. Phase 1 alone transforms the gearing experience.
   Later phases layer on additional fidelity.

## Non-Goals

- **Implementing player-style AAs on companions.** Companions do not earn
  or use Alternate Advancement abilities. AA bonuses remain zero.

- **Heroic stat processing.** Classic-through-Luclin items do not have
  heroic stats. `CalcHeroicBonuses()` is not needed for era compliance.

- **Click effects from items.** Companions have no mechanism to activate
  clicky items (no UI, no hotbar, no AI-driven click logic). This is a
  separate feature that requires significant AI work beyond stat mechanics.

- **Augment support.** The companion inventory system does not currently
  track augments. Adding augment support requires schema changes and is
  a separate feature.

- **Changing how companions learn spells.** The `companion_spell_sets`
  system that assigns spells by class and level remains unchanged. Phase 4
  tunes the AI decision-making, not the spell repertoire.

- **Rewriting the NPC attack pipeline.** The goal is to make companions
  use weapon data within the existing NPC attack framework, not to switch
  companions to the Client attack path entirely.

- **Modifying base NPC behavior.** These changes affect only entities that
  are companions (where `IsCompanion()` returns true). Regular NPCs are
  unaffected.

## User Experience

### Phase 1: Weapons Come Alive

#### Player Flow

1. Player recruits a level 40 warrior NPC in North Freeport as a companion.
2. Player gives the companion a Rusty Longsword (Dmg: 5, Delay: 35).
3. The companion fights a mob. Player observes hit messages with damage in
   a range consistent with 5 base damage plus STR bonuses.
4. Player upgrades the companion's weapon to a Fine Steel Long Sword
   (Dmg: 9, Delay: 35).
5. The companion's hits are now visibly harder — damage numbers are
   noticeably higher, consistent with the weapon's 9 damage.
6. Player further upgrades to a Blackened Alloy Longsword (Dmg: 12, Delay: 29).
7. Damage per hit increases AND the companion attacks faster due to the
   lower delay. Total DPS increase is dramatic and immediately obvious.
8. Player equips a second weapon in the companion's off-hand (secondary slot).
   The companion now dual-wields, with the off-hand weapon's damage used
   for secondary attacks.

#### What Changes

- Melee hit damage is calculated from the equipped weapon's damage value
  instead of `npc_types.max_dmg`.
- Attack speed is driven by the equipped weapon's delay value instead of
  `npc_types.attack_delay`.
- When no weapon is equipped, the companion falls back to the NPC database
  values (preserving current behavior for unarmed/monk companions).

#### What Stays the Same

- Weapon procs continue to fire (already working).
- Haste effects (spell and item) continue to apply (already working).
- Elemental and bane damage from weapons continue to work (already working).
- The companion's equipped weapon still determines attack animation and
  skill type (already working).

### Phase 2: Combat Skills and Special Attacks

#### Player Flow

1. Player recruits a level 50 warrior companion.
2. In combat, the warrior companion now parries, ripostes, and dodges
   incoming attacks at rates appropriate for a level 50 warrior (high
   parry and riposte, moderate dodge).
3. Player recruits a level 50 rogue companion. The rogue dodges and parries
   attacks, and at level 50 also ripostes (rogues get parry at 12, riposte
   at 30). Their avoidance rates are lower than a warrior but meaningful.
4. A level 50 monk companion dodges at a very high rate and blocks with
   their fists.
5. Melee companions at level 28+ now deal a damage bonus on every hit,
   with the bonus amount scaling with weapon delay (slower weapons get a
   larger bonus, matching the EverQuest damage bonus table).
6. Warriors at level 56+ occasionally land triple attacks.

#### What Changes

- Companions are assigned class-appropriate and level-appropriate values
  for offense, defense, dodge, parry, riposte, and block skills at
  recruitment time and on level-up.
- The damage bonus from weapon delay (the `GetWeaponDamageBonus()` table)
  is applied to companion melee hits for qualifying classes at level 28+.
- Triple attack is enabled for classes that would have it at the appropriate
  level (warriors at 56+, monks and rangers at 60+).
- Dual wield and double attack continue to use their existing mechanisms
  (class check + special abilities from npc_types), which are already
  functional.

#### What Stays the Same

- The IsOfClientBot() return value remains true — companions continue to
  use the Client/Bot avoidance path, which is already correct. The change
  is in the skill VALUES fed into that path, not the path itself.
- Existing special abilities from the source NPC's `npc_types.special_abilities`
  are preserved.

### Phase 3: Stats Drive Survivability

#### Player Flow

1. Player equips a STA-heavy ring (+15 STA) on their warrior companion.
2. The companion's max HP increases visibly — the `!stats` command shows
   a higher HP total than before equipping the ring.
3. Player notices that after a fight, when companions sit to rest, their
   HP recovers faster than when standing (sitting HP regen bonus).
4. A companion with high defense skill now gets slightly more AC benefit
   from that skill (defense skill AC divisor aligned to Client values).

#### What Changes

- STA from equipment and buffs contributes to companion max HP using a
  per-STA-point HP formula scaled by level and class. A level 60 warrior
  with +50 STA from gear gains meaningful extra HP.
- Sitting HP regen bonus is added: companions that are sitting and
  out of combat regenerate HP faster than standing, consistent with how
  player characters work.
- The defense skill contribution to AC uses the Client/Bot divisor (skill/3
  for melee, skill/2 for casters) instead of the NPC divisor (skill/5).

#### What Stays the Same

- Base HP from `npc_types.max_hp` remains the foundation. STA is additive
  on top of that base.
- OOC regen via the `Companions::OOCRegenPct` rule remains active.
- Item and spell HP regen bonuses continue to work (already functional).

### Phase 4: Spell System Tuning

#### Player Flow

1. A cleric companion heals more intelligently: they begin healing at
   different HP thresholds depending on how fast the tank is taking damage,
   rather than waiting until a fixed percentage.
2. A shaman companion consistently slows the primary target early in the
   fight, then shifts to healing/DoTs.
3. An enchanter companion prioritizes mezzing additional adds over slowing
   the primary target.
4. Caster companions conserve mana better in extended fights — they stop
   nuking when mana drops below a configurable threshold and reserve enough
   mana for emergency heals (healers) or emergency mezzes (enchanters).
5. Buff-class companions do not re-buff during combat unless it is an
   in-combat buff (like a damage shield or short-duration proc buff).

#### What Changes

- Heal thresholds are tuned per healer class:
  - Clerics: begin healing at 80% HP in combat (currently ~90%), with
    emergency complete heal logic below 25%.
  - Druids: begin healing at 75% HP, weave DoTs between heals.
  - Shamans: heal at 70% HP, prioritize slow first then heal.
- Nuke mana conservation: DPS casters stop nuking below 20% mana
  (currently 10%) to preserve mana for longer fights.
- Buff timing: pre-combat buffs are only applied when idle and out of
  combat. In-combat buff spells (type `SpellType_InCombatBuff`) are the
  only buffs attempted during engagement.
- Mez priority: enchanters attempt mez on adds before attempting slow
  on primary (currently varies).

#### What Stays the Same

- The `companion_spell_sets` database table is unchanged. No spells are
  added or removed.
- The class-specific AI handler structure in `companion_ai.cpp` is
  preserved.
- Stance-based casting frequency (passive 20%, balanced 50%, aggressive
  80%) remains.
- The spell_type bitmask system is unchanged.

### Phase 5: Polish and Edge Cases

#### Player Flow

1. Companion resistances are capped at level-appropriate values, preventing
   gear + buffs + high base resists from making a companion immune to spells.
2. Spell focus items (increased spell damage, reduced mana cost) work
   correctly on companion spell casts.
3. General balance pass: after all previous phases, the overall companion
   power level is evaluated and tuning knobs are adjusted if needed.

#### What Changes

- Resist caps enforced per level (matching Client resist cap formula).
- Focus effects on companion spell casts are verified and fixed if broken.
- StatScalePct and other tuning rules adjusted based on testing with
  full gear + all Phase 1-4 changes active.

#### What Stays the Same

- All Phase 1-4 changes remain active. Phase 5 is additive polish.

## Game Design Details

### Phase 1 Mechanics: Weapon Damage and Delay

#### Weapon Damage for Melee Hits

When a companion has a weapon equipped in the relevant hand slot (Primary
for main-hand, Secondary for off-hand), the melee damage calculation should
use the weapon's damage value instead of `npc_types.max_dmg`:

- **Primary hand (main-hand attack):** Use `weapon->Damage` from the
  item equipped in the Primary slot.
- **Secondary hand (off-hand attack):** Use `weapon->Damage` from the
  item equipped in the Secondary slot.
- **No weapon equipped:** Fall back to `npc_types.max_dmg` /
  `npc_types.min_dmg` (preserving current behavior). This handles monks
  (who fight unarmed) and any companion not yet given a weapon.
- **Ranged attacks:** If the companion has a ranged weapon and
  ammunition, ranged damage should use the ranged weapon's damage value.

Min damage when a weapon is equipped should follow the Client convention:
the minimum hit on a successful melee strike is 1 (not npc_types.min_dmg).

#### Weapon Delay for Attack Speed

When a companion has a weapon equipped, the attack timer should use the
weapon's delay value:

- **Primary hand:** Timer = `weapon->Delay` (in tenths of a second,
  converted to milliseconds) divided by haste modifier.
- **Secondary hand:** Timer = secondary weapon's delay, divided by haste.
- **No weapon equipped:** Fall back to `npc_types.attack_delay`
  (current behavior).
- **Two-handed weapon:** Uses the two-hander's delay for the primary
  timer. Secondary timer is disabled (no dual wield with two-handers).

All existing haste calculations (spell haste, item haste, HundredHands
effect) continue to apply on top of the weapon-derived base delay.

#### Fallback Behavior

The fallback to `npc_types` values is critical for:
- **Monks:** Who fight unarmed and should use their NPC fist damage.
- **Freshly recruited companions:** Before the player has given them gear.
- **Companions whose weapon is removed:** Via `!unequip` or similar.

A companion that has a weapon equipped in Primary but nothing in Secondary
should: use weapon damage for primary attacks, and either disable secondary
attacks or use unarmed damage for off-hand if their class supports dual
wield and they have the skill for it.

#### Success Criteria — Phase 1

- [ ] A companion with a weapon equipped deals damage consistent with that
      weapon's damage value (not npc_types.max_dmg).
- [ ] Replacing a companion's weapon with a higher-damage weapon produces
      visibly higher melee damage.
- [ ] A companion with a faster weapon (lower delay) attacks more frequently
      than one with a slower weapon.
- [ ] A companion with no weapon equipped continues to deal damage using
      npc_types values (no regression for unarmed/monks).
- [ ] Weapon procs, elemental damage, and bane damage continue to work
      when weapon damage is used for base calculation.
- [ ] Haste effects (spell and item) still correctly modify attack speed
      when weapon delay is used.
- [ ] The `!stats` command (from the improved-companion-stats feature)
      reflects the actual weapon-based damage range, not npc_types values.

#### Estimated Complexity: Large

This touches the core melee attack path. Two significant changes (damage
source and attack timer source) that must correctly interact with the
existing combat pipeline.

---

### Phase 2 Mechanics: Combat Skills and Special Attacks

#### Class-Appropriate Skill Assignment

When a companion is recruited (and on each level-up), they should be
assigned combat skill values appropriate for their class and level. The
skill values should match what a player character of that class and level
would have if they had trained their skills to maximum.

The following skills need class-appropriate values:

| Skill | Classes That Use It | Expected Range (Level 60) |
|-------|-------------------|--------------------------|
| Defense | All | 200-252 depending on class |
| Offense | All melee | 200-252 depending on class |
| Dodge | All | 0-175+ depending on class |
| Parry | War, Pal, SK, Rng, Brd, Rog | 0-230 depending on class |
| Riposte | War, Pal, SK, Rng, Brd, Rog | 0-225 depending on class |
| Block | War, Pal, SK (with shield) | 0-230 depending on class |
| Dual Wield | War, Rng, Brd, Rog, Mnk, Bst | 0-245 depending on class |
| Double Attack | War, Pal, SK, Rng, Mnk, Rog, Brd, Bst | 0-245 |
| 1H Slash, 1H Blunt, 2H Slash, 2H Blunt, Piercing, Hand to Hand | Varies by class | 200-252 |

The skill values should scale linearly with level from 1 to class-max at
level 60. The class-max values should be data-driven (database table or
rule values) rather than hardcoded, so they can be tuned.

#### Damage Bonus from Weapon Delay

Starting at level 28, melee-class companions should receive a damage
bonus on every primary-hand hit. The damage bonus follows the standard
EverQuest damage bonus table, which maps (level, weapon delay) to a bonus
value.

The damage bonus is:
- Applied only to primary hand attacks (not off-hand).
- Only for warrior-archetype classes (Warrior, Paladin, Shadow Knight,
  Ranger, Monk, Rogue, Bard, Beastlord).
- Only at level 28 and above.
- Based on the equipped weapon's delay (from Phase 1). If no weapon is
  equipped, the damage bonus uses `npc_types.attack_delay` as the delay
  value.

The damage bonus adds a flat amount to every hit, making it a significant
DPS contributor at higher levels with slower weapons.

#### Triple Attack

Triple attack should be available to companions whose class supports it,
at the appropriate level:

- **Warriors:** Triple attack starting at level 56 (when warriors get
  the TripleAttack skill in classic EQ).
- **Monks:** Triple attack starting at level 60.
- **Rangers:** Triple attack starting at level 60.

Triple attack chance should be skill-based, starting low and increasing
with level (matching the player triple attack skill curve).

#### Success Criteria — Phase 2

- [ ] A level 50 warrior companion demonstrates parry, riposte, and dodge
      at rates consistent with warrior skill caps at level 50.
- [ ] A level 50 rogue companion dodges, parries, and ripostes attacks
      at rates consistent with rogue skill caps (lower than warrior caps
      but present — rogues get parry at 12, riposte at 30).
- [ ] A level 50 cleric companion has very low or no dodge/parry/riposte
      (casters have minimal avoidance skills).
- [ ] Skill values increase on level-up proportionally to level.
- [ ] A level 35 warrior companion's melee hits include a damage bonus
      consistent with the weapon delay bonus table.
- [ ] A level 56+ warrior companion occasionally lands triple attacks.
- [ ] Existing dual wield and double attack behavior is unchanged (these
      already work via NPC special abilities).

#### Dependencies

- Phase 1 (weapon delay) must be complete for the damage bonus to work
  correctly, since the bonus is based on weapon delay.

#### Estimated Complexity: Medium

Skill assignment is primarily a data-mapping exercise. Damage bonus requires
adding a calculation step. Triple attack requires setting a special ability
flag based on class and level.

---

### Phase 3 Mechanics: Stats Drive Survivability

#### STA-to-HP Conversion

When a companion has STA bonuses from equipment or buffs, those bonus STA
points should contribute additional max HP. The conversion formula should
use a simplified version of the Client formula:

- **HP per STA point** scales with level and class archetype:
  - Tank classes (War, Pal, SK): Higher HP per STA (approximately
    matching the Client STA-to-HP table for these classes).
  - Melee DPS (Mnk, Rog, Rng, Brd, Bst): Moderate HP per STA.
  - Priest classes (Clr, Dru, Shm): Moderate HP per STA.
  - Caster DPS (Wiz, Mag, Nec, Enc): Lower HP per STA.
- Only STA from gear and buffs contributes (the `itembonuses.STA` and
  `spellbonuses.STA` values). The base STA from `npc_types` already
  contributes to the NPC's `npc_types.max_hp` value and should not be
  double-counted.
- The conversion is recalculated on `CalcBonuses()`, so equipping or
  removing STA gear immediately updates max HP.

The exact HP-per-STA values should be configurable (via a rule or
lookup table) so they can be tuned for the 1-3 player server context.
A reasonable starting point: approximately 6-10 HP per STA point for
tanks at level 60, 4-6 for melee, 3-5 for casters.

#### Sitting HP Regen Bonus

Companions that are sitting and out of combat should receive an enhanced
HP regen rate, consistent with how player characters regenerate faster
while sitting:

- Sitting bonus: approximately 2x-3x the standing regen rate (matching
  the EQ Client sitting regen multiplier).
- Only applies when the companion is actually sitting (the `IsSitting()`
  check is already available and used for mana regen).
- Stacks with existing OOC regen from the `Companions::OOCRegenPct` rule.
- Does NOT apply during combat (companions should not be sitting in combat
  under normal circumstances).

#### Defense Skill AC Divisor

The companion's defense skill contribution to AC should use the Client/Bot
divisor instead of the NPC divisor:

- Current: defense_skill / 5 (NPC path in ACSum)
- Corrected: defense_skill / 3 for melee classes, defense_skill / 2 for
  caster classes (Client/Bot path)

Since companions already return `IsOfClientBot() = true` and get the
Client/Bot treatment for most of ACSum, the defense skill divisor should
match. This is a small but thematically correct change.

#### Success Criteria — Phase 3

- [ ] Equipping a STA item on a companion increases their max HP. The
      `!stats` command shows the higher HP total.
- [ ] Removing a STA item decreases max HP back to the previous value.
- [ ] A level 60 warrior companion with +50 STA from gear gains
      approximately 300-500 extra HP (meaningful but not game-breaking).
- [ ] A sitting companion regenerates HP faster than a standing one
      (approximately 2-3x rate).
- [ ] The sitting regen bonus is visible in combat log regen messages
      or observable through HP recovery speed.
- [ ] A companion with high defense skill has slightly higher AC than
      before the divisor change (verifiable via `!stats`).

#### Dependencies

- Phase 2 (class-appropriate defense skill values) should be complete
  so the defense skill divisor change has meaningful skill values to
  work with. However, this is a soft dependency — the divisor change
  can be applied independently.

#### Estimated Complexity: Medium

STA-to-HP requires a new calculation path in the HP computation. Sitting
regen is a small change to `CalcHPRegen`. Defense divisor is a targeted
path change in ACSum.

---

### Phase 4 Mechanics: Spell System Tuning

#### Heal Threshold Refinement

Current heal thresholds are functional but can be improved:

**Cleric AI:**
- Current: heals group below 90% in combat, heals owner below 25% in
  passive stance.
- Revised: heals group below 80% in combat. Emergency complete heal
  (largest available heal) when any group member drops below 25%. In
  passive stance, heals owner below 35%.
- Rationale: 90% is too aggressive — clerics burn through mana healing
  minor damage. 80% allows the tank to take a few more hits before a
  heal is triggered, conserving mana for longer fights.

**Druid AI:**
- Current: heals, cures, roots, DoTs, nukes.
- Revised: heals at 75% HP threshold. Prioritizes HoT (heal over time)
  spells when available and target is above 50%. Uses direct heals below
  50%. Weaves DoTs between heals when mana allows.
- Rationale: Druids should leverage their HoT efficiency.

**Shaman AI:**
- Current: slows (70% chance), heals, cures.
- Revised: slow primary target immediately on engagement (100% priority
  on first cast). Heal at 70% threshold. Cani (cannibalize mana from HP)
  when mana below 40% and HP above 80%.
- Rationale: Slow is the shaman's most impactful ability and should never
  be skipped due to RNG.

#### Mana Conservation

- **DPS casters (Wizard, Magician, Necromancer):** Stop nuking when mana
  drops below 20% (currently 10%). This reserves a mana buffer for
  emergencies (gate, emergency CC).
- **Healers (Cleric, Druid, Shaman):** Switch to most mana-efficient heal
  when mana drops below 30%. Stop preemptive buffing below 30% mana
  (currently checked but threshold varies).
- **Enchanters:** Reserve at least 15% mana for emergency mez. Stop
  nuking/DoTing below 30% mana. Always attempt mez on adds if mana
  permits.

#### Buff Management

- **Pre-combat only:** Standard buffs (type `SpellType_Buff` and
  `SpellType_PreCombatBuff`) are only cast when the companion is idle
  and out of combat.
- **In-combat buffs:** Only `SpellType_InCombatBuff` spells are attempted
  during engagement (damage shields, short-duration proc buffs, etc.).
- **No re-buffing in combat:** If a buff drops during combat, do not
  attempt to re-cast it until combat ends. Exception: in-combat buffs.
- **Buff check on idle:** When transitioning from engaged to idle,
  companions should check for missing buffs and rebuff the group.

#### Success Criteria — Phase 4

- [ ] A cleric companion does not begin healing until a group member drops
      below 80% HP in combat.
- [ ] A shaman companion always attempts slow on the primary target as
      their first combat action.
- [ ] A wizard companion stops nuking when mana drops below 20%.
- [ ] Companions do not attempt to cast standard buffs during combat.
- [ ] An enchanter companion prioritizes mezzing adds over other actions
      when multiple hostile targets are present.
- [ ] Companion healers switch to their most efficient heal when mana is
      below 30%.
- [ ] Companions rebuff the group when transitioning from combat to idle.

#### Dependencies

- None. Phase 4 is independent of Phases 1-3. It can be implemented in
  any order.

#### Estimated Complexity: Medium

Multiple class-specific AI adjustments. Each class handler needs targeted
changes to thresholds and priority ordering. The changes are localized to
`companion_ai.cpp` logic but affect 6+ class handlers.

---

### Phase 5 Mechanics: Polish

#### Resist Caps

Companion resistances should be capped at level-appropriate values to
prevent stacking base resists + gear resists + buff resists from creating
immunity:

- Cap formula: approximately `level * 5 + 50` (matching the rough Client
  resist cap for the Classic-Luclin era).
- Applied after all bonuses (base + items + spells) are summed.
- Each resist (MR, FR, CR, DR, PR) is capped independently.
- The cap value should be a configurable rule so it can be tuned.

#### Focus Effects

Spell focus effects from equipped items (increased spell damage, reduced
mana cost, increased duration, etc.) should work on companion spell casts.
Since companions call standard `SpellOnTarget()` and `SpellEffect()`
functions, focus effects may already work through the Mob focus code path.
This needs to be tested and fixed if broken.

Key focus effects to verify:
- Improved Damage (increased nuke damage)
- Improved Healing (increased heal amount)
- Mana Conservation (reduced mana cost)
- Extended Enhancement (increased buff duration)

#### Balance Tuning Pass

After all previous phases are active, a balance tuning pass should be
performed:

- Evaluate companion DPS with good gear vs player character DPS at the
  same level — companions should be competitive but not strictly superior.
- Evaluate tank companion survivability vs player tank — companions should
  be viable main tanks for group content.
- Adjust `Companions::StatScalePct` if base stats need global scaling.
- Potentially introduce additional rules for fine-tuning:
  - Companion damage output multiplier
  - Companion avoidance multiplier
  - Companion HP multiplier from STA

#### Success Criteria — Phase 5

- [ ] No companion resist stat can exceed the resist cap.
- [ ] Equipping a focus effect item on a companion produces measurably
      increased spell damage, healing, or reduced mana cost (as
      appropriate for the focus type).
- [ ] Overall companion power level is evaluated and documented, with
      tuning knob values recorded for the current balance point.

#### Dependencies

- Phases 1-4 should be complete before the balance tuning pass, since
  the pass evaluates the cumulative effect of all changes.

#### Estimated Complexity: Small-Medium

Resist caps are a straightforward clamp. Focus effects are primarily
testing. The balance pass is evaluation and tuning knob adjustment.

---

### Balance Considerations

#### Interaction with 1-3 Player Constraint

This server is designed for 1-3 real players supplemented by companions.
In a typical play session, a solo player might have 3-5 companions forming
their entire group. These changes are designed with this in mind:

- **Weapons matter (Phase 1)** means the player's efforts to find and
  equip good weapons on companions directly translates to better group
  performance. This creates a rewarding gearing loop.
- **Combat skills (Phase 2)** means a warrior companion can actually
  fulfill the tank role. Without proper parry/riposte/dodge, tank
  companions are glass cannons regardless of gear.
- **STA->HP (Phase 3)** means equipping STA gear on the tank is
  meaningful, not wasted item slots.
- **Spell tuning (Phase 4)** means healer companions are reliable enough
  that a solo player can trust them to keep the group alive.

#### Power Level Expectations

A well-equipped companion should perform at approximately 70-85% of an
equivalently-geared player character of the same class and level. This
makes companions effective enough to fill group roles while preserving
a meaningful edge for the real player(s). The exact percentage can be
tuned via:

- `Companions::StatScalePct` — global stat multiplier
- Skill cap scaling factor — how close companion skills get to player caps
- Damage bonus application — whether companions get 100% of the DB table
  bonus or a percentage of it

#### Preventing Overpowered Companions

The following safeguards exist:

1. **StatScalePct rule:** Already exists, default 100%. Can be reduced if
   companions become too strong after Phase 1-2 changes.
2. **Skill caps can be set below player caps:** If 100% of player skill
   values makes companions too effective, companion skills can be capped
   at 80-90% of player values.
3. **Resist caps (Phase 5):** Prevent immunity stacking.
4. **No AAs:** Companions never gain AAs, which is a significant power
   differential at level 60+ since player AAs add substantial capability.
5. **AI limitations:** Even with perfect stats, companion AI will never
   match a skilled human player's decision-making.

#### Edge Cases

**Level 1 companions:** At level 1, most stats and skills are low
regardless. Weapon damage will still work (even a Rusty Sword has damage
values). Damage bonus does not apply (requires level 28). Avoidance
skills are near zero (appropriate for level 1).

**Level 60 companions with best-in-slot gear:** This is the scenario most
likely to be overpowered. With weapon damage + damage bonus + high
avoidance skills + STA-to-HP + good spell AI, a fully-geared level 60
warrior companion could be very strong. Mitigated by: no AAs, skill caps
potentially below player caps, AI imperfection, and the StatScalePct
tuning knob.

**Monks (unarmed):** Monks who fight without weapons equipped should
continue to use `npc_types` damage values for their fist attacks. The
fallback behavior in Phase 1 explicitly handles this. Monk damage at
high levels is typically strong from their NPC base stats.

**Companions with no gear at all:** Should fight exactly as they do today
(regression protection). All fallback paths use current npc_types values.

**Weapon swap mid-combat:** If a weapon is swapped via `!equip` during
combat, the new weapon's damage and delay should take effect on the next
attack. `CalcBonuses()` and `SetAttackTimer()` should be called on
equipment change (they already are).

### Era Compliance

This feature is entirely mechanics-focused. No new items, zones, NPCs,
quests, or lore content is introduced. All mechanics being implemented
(weapon damage, attack delay, damage bonus table, skill-based avoidance,
STA-to-HP, focus effects, resist caps) are core EverQuest systems that
existed from Classic launch.

The damage bonus table, skill caps, and resist cap formulas should use
Classic-through-Luclin era values. No post-Luclin mechanics (such as
post-PoP weapon ratio changes, Heroic stats, or combat ability timers)
should be introduced.

Specific era-lock checks:
- Damage bonus table: use the pre-PoP damage bonus table (which is
  already in the codebase as the default).
- Skill caps: use Classic-era max skill values per class. The codebase
  already has these tables.
- Triple attack: Warriors at 56, Monks/Rangers at 60 — these are the
  Classic-era thresholds.
- Focus effects: only Classic-through-Luclin focus effects exist on
  era-locked items, so no post-era focus types will be triggered.

## Affected Systems

- [x] C++ server source (`eqemu/`) — Companion attack path (weapon
  damage, weapon delay, damage bonus), companion skill assignment,
  STA-to-HP calculation, HP regen calculation, ACSum defense divisor,
  resist cap enforcement, focus effect verification.
- [ ] Lua quest scripts (`akk-stack/server/quests/`) — No Lua changes
  expected. All changes are in the C++ combat engine. If `!stats`
  display needs updating to show weapon-based damage, that is part of
  the improved-companion-stats feature, not this one.
- [ ] Perl quest scripts (maintenance only)
- [x] Database tables (`peq`) — Possible new table or data entries for
  class-specific skill cap values if these are not driven by existing
  codebase skill cap tables. Possibly `companion_spell_sets` adjustments
  for Phase 4 threshold changes (if thresholds are data-driven rather
  than code-driven).
- [x] Rule values — New or modified rules for: STA-to-HP conversion
  factor, companion skill cap percentage, companion damage bonus
  percentage, resist cap formula, heal/mana thresholds. All should be
  configurable via the rule system rather than hardcoded.
- [ ] Server configuration
- [ ] Infrastructure / Docker

## Dependencies

1. **Companion system must be functional.** The recruit-any-NPC companion
   system (recruitment, equipment, commands, AI, persistence) must be
   operational. This feature modifies how companions fight, not whether
   they exist.

2. **improved-companion-stats feature (recommended but not blocking).**
   The `!stats` and `!equipment` commands from that feature provide the
   primary way for players to observe the effects of these changes. If
   `!stats` is not yet implemented, testing can still be done via combat
   log analysis and GM commands, but the player experience is diminished.

3. **Phase ordering within this feature:** Phase 1 should be completed
   before Phase 2 (damage bonus depends on weapon delay). Phase 2 should
   be completed before Phase 3 (defense divisor change depends on proper
   skill values). Phase 4 is independent and can be done in any order.
   Phase 5 depends on Phases 1-4 being complete for the balance pass.

## Open Questions

1. **Monk fist damage scaling:** In the live game, monk fist damage scales
   with level (increasing H2H damage at higher levels even without a weapon).
   Should companion monks get this scaling from their `npc_types` base
   damage, or should a monk-specific fist damage table be applied? The
   architect should investigate whether the existing codebase has a monk
   fist damage lookup and whether it can apply to companions.

2. **Weapon ratio validation:** Should there be a sanity check preventing
   obviously overpowered weapon ratios? For example, a GM-spawned weapon
   with 200 damage and 10 delay would be absurd on a companion. The
   architect should consider whether weapon ratio bounds are needed or if
   the existing item database is sufficient protection.

3. **Skill data source:** The codebase already has skill cap tables for
   player classes (used by Client::CalcSkillCaps). Can these same tables
   be queried for companion skill assignment, or do companions need their
   own skill cap data? The architect should investigate.

4. **Focus effect code path:** Does the Mob-level focus effect code path
   apply to companions automatically, or does it require `IsClient()`
   checks that exclude NPCs? The architect should verify.

5. **Companion spell AI thresholds — data vs code:** Are the heal
   thresholds and mana conservation percentages currently hardcoded in
   `companion_ai.cpp`, or are they data-driven from `companion_spell_sets`
   (via the `min_hp_pct` / `max_hp_pct` columns)? If data-driven, Phase 4
   changes may be database-only with no code changes needed. The architect
   should clarify.

6. **Attack path divergence risk:** Modifying the companion's attack path
   to read weapon damage introduces a code divergence from standard
   NPC::Attack(). If upstream EQEmu updates change NPC::Attack(), the
   companion-specific changes could conflict. The architect should consider
   how to minimize merge conflict risk (e.g., override in
   Companion::Attack() vs modifying NPC::Attack() with IsCompanion() checks).

## Acceptance Criteria

### Phase 1: Weapons Come Alive

- [ ] A companion equipped with a weapon deals melee damage derived from
      that weapon's damage stat, not from npc_types.max_dmg.
- [ ] Swapping a companion's weapon to one with higher damage produces
      correspondingly higher melee hits.
- [ ] A companion equipped with a faster weapon (lower delay) attacks more
      frequently.
- [ ] A companion with no weapon equipped deals damage using npc_types
      values (current behavior preserved).
- [ ] Weapon procs, haste, and elemental damage continue to function.
- [ ] A dual-wielding companion uses the appropriate weapon damage for
      each hand.

### Phase 2: Combat Skills and Special Attacks

- [ ] A warrior companion has high parry, riposte, dodge, and block
      skill values at level-appropriate rates.
- [ ] A rogue companion has dodge, parry, and riposte skills at
      class-appropriate rates (lower than warrior but present).
- [ ] A caster companion has minimal defensive combat skills.
- [ ] Companion skill values scale with level-up.
- [ ] Level 28+ melee companions deal damage bonus consistent with the
      weapon delay bonus table.
- [ ] Level 56+ warriors land triple attacks.
- [ ] Level 60+ monks and rangers land triple attacks.

### Phase 3: Stats Drive Survivability

- [ ] Equipping a STA item on a companion increases max HP. Removing it
      decreases max HP.
- [ ] Sitting companions regenerate HP faster than standing companions.
- [ ] Companion defense skill contribution to AC uses the Client/Bot
      divisor.

### Phase 4: Spell System Tuning

- [ ] Cleric companion begins healing at 80% HP, not 90%.
- [ ] Shaman companion reliably slows primary target as first action.
- [ ] DPS casters stop nuking below 20% mana.
- [ ] No standard buffs are cast during combat engagement.
- [ ] Enchanters prioritize mez on adds.

### Phase 5: Polish

- [ ] Companion resistances are capped at level-appropriate values.
- [ ] Spell focus effects from equipped items affect companion spell output.
- [ ] Balance tuning pass completed and documented.

---

## Appendix: Technical Notes for Architect

These notes are advisory. The architect makes all implementation decisions.

### Companion Attack Path

The critical code is in `NPC::Attack()` (attack.cpp ~line 2362) where
`GetBaseDamage()` and `GetMinDamage()` are called. For companions, the
architect could:
- Override `Companion::Attack()` to read weapon damage from inventory
  before calling into the shared attack pipeline.
- Or add `IsCompanion()` checks within `NPC::Attack()` to branch on
  weapon data.

The `DamageHitInfo` struct has `base_damage` and `min_damage` fields that
need to be set from weapon data instead of NPC data.

### SetAttackTimer Override

`NPC::SetAttackTimer()` (attack.cpp ~line 6784) reads `attack_delay`.
For companions, the weapon delay from `GetInv().GetItem(slot)->Delay`
could be used instead. The `Companion::GiveItem()` already calls
`CalcBonuses()` which calls `SetAttackTimer()`, so attack speed should
update automatically on equipment change.

### Skill Cap Table Reference

The codebase has `SkillCaps` data loaded from the `skill_caps` database
table. The `Client::CalcSkillCaps()` function queries this. The same data
could potentially be used for companion skill assignment by querying the
table with the companion's class and level.

### Existing Rule Names

- `Companions::StatScalePct` — global stat multiplier (default 100)
- `Companions::HPRegenPerTic` — floor HP regen
- `Companions::OOCRegenPct` — out-of-combat HP regen % (default 5)
- `Companions::CompanionManaRegenMult` — mana regen multiplier (default 100)
- `Character::ManaRegenMultiplier` — global mana regen (used by companions too)

### Suggested New Rule Names

- `Companions::UseWeaponDamage` — enable/disable weapon-based damage (boolean, for Phase 1 toggle)
- `Companions::UseWeaponDelay` — enable/disable weapon-based delay (boolean, for Phase 1 toggle)
- `Companions::SkillCapPct` — what percentage of player skill caps companions reach (default 100)
- `Companions::DamageBonusPct` — what percentage of the weapon delay damage bonus to apply (default 100)
- `Companions::STAToHPFactor` — multiplier on STA-to-HP conversion (default 100 = 100%)
- `Companions::SittingRegenMult` — multiplier for sitting HP regen (default 200 = 2x standing)
- `Companions::ResistCap` — maximum resist value or 0 for no cap
- `Companions::HealThresholdPct` — starting heal threshold (default 80)
- `Companions::ManaCutoffPct` — mana percentage below which casters stop nuking (default 20)

### Reference: companion-mechanics-reference.md

The comprehensive gap analysis is at:
`claude/project-work/feature/improved-companion-stats/architect/context/companion-mechanics-reference.md`

This document contains side-by-side code comparisons for all 14 mechanic
categories and the full 22-item gap table. The architect should use this
as the primary technical reference.

---

> **Next step:** Pass this PRD to the **architect** for technical feasibility
> assessment and implementation planning.
