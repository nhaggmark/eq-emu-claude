## What
Restrict companion AI from casting snare-line spells during active combat unless the target is both (a) below 20% HP and (b) showing flee behavior. After 2 resists on the same target, the companion stops attempting snare against that target.

## Why
Druid and Ranger companions (and other snare-capable classes) currently spam Ensnare during fights. This:
- Generates aggro the player doesn't want on the companion
- Wastes mana that could go to heals, nukes, or other utility
- Costs DPS — each cast is a cast slot not spent on damage
- Provides no tactical benefit when the mob is already locked in melee

The intent is movement control where it actually matters (low-HP mobs about to flee) without polluting normal combat.

## Mechanics
- **Classes affected:** Druid, Ranger, Necromancer, Shaman — every class with a snare-line spell
- **Spells affected:** Snare-line only (movement slow). Root-line spells (immobilize) are NOT in scope and continue to behave as they do today.
- **In-combat trigger:** Companion may cast snare on a target only if:
  - Target HP ≤ 20%, AND
  - Target is currently in flee behavior
- **Resist counter:** Per target. After 2 resists on the same target, companion will not attempt snare again on that target for the remainder of that engagement. Counter resets when the companion engages a new target.
- **Out-of-combat behavior:** Unaffected. Companions may still snare freely during pulls, pre-engagement positioning, or any non-active-combat scenario.

## Out of scope (for this feature)
- Root-line spells (immobilize) — same complaint pattern doesn't apply, and players use root for legit CC
- Player-character casting (this is a companion-AI rule, not a player-spell-gating rule)
- Manual `/command` overrides — companions should still obey direct snare commands from the player, regardless of the AI rule (architect to confirm this is how command-overrides work)

## Open questions for the architect
- Should the 20% HP threshold and 2-resist count be tunable via a new `rule_values` entry (e.g., `Companions:SnareHpThreshold`, `Companions:SnareResistLimit`)? Recommend yes, default to spec values.
- Where in the companion AI tick does this gate need to sit so that snare is suppressed cleanly without affecting other casts in the same decision pass?
- Verify: does manual player command (e.g., asking the companion to snare directly) bypass this rule? If not currently possible, is that worth a separate small feature?
