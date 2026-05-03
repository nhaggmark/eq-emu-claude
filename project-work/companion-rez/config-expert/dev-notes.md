# Companion Rez — Dev Notes: config-expert

> **Feature branch:** `bugfix/companion-rez`
> **Agent:** config-expert
> **Task(s):** Rule audit (architecture phase advisory)
> **Date started:** 2026-04-27
> **Current stage:** Research complete — findings delivered to architect

---

## Task Assignment

Architecture phase advisory: audit rule_values and config files for any
rules that might be blocking or misconfiguring the companion auto-rez
feature. Read-only — no rule changes made.

| # | Task | Depends On | Status |
|---|------|------------|--------|
| Arch advisory | Audit rule_values for rez/AI/companion rules | PRD read | Complete |

---

## Stage 1 + 2: Plan + Research (combined — read-only audit)

### Scope

Queried rule_values for:
- All rules touching rez/resurrect/corpse/death/sickness/revive
- All Companions:* rules (including any added by prior bugfixes)
- All Spells:AI_* rules (NPC spell casting behavior)
- All NPC:* rules
- All Mercs:* rules (closest analog to companion rez)
- All Bots:* rules touching rez/sickness/death
- All Aggro:* rules
- Checked eqemu_config.json and .env for rez-related settings

---

## Stage 3: Socialize — Findings Summary

### A. Companion:RezEnabled and friends (THE KEY RULES)

These rules were added by prior fix work and are directly relevant:

| Rule | Value | Status |
|------|-------|--------|
| `Companions:RezEnabled` | `true` | NORMAL — master toggle is ON |
| `Companions:RezPostCombatDelayS` | `10` | NORMAL — 10s post-combat delay defined (satisfies AC-1) |
| `Companions:RezRange` | `200` | NORMAL — 200 units range for corpse targeting |
| `Companions:RezWaiveReagents` | `true` | NORMAL — reagents waived for NPC casters (NPCs never consume them anyway) |
| `Companions:DeathDespawnS` | `1800` | NORMAL — 30 min auto-dismiss window; plenty of time for rez |

**Assessment:** All four rez-specific Companion rules exist and are set to sane values. The `RezEnabled=true` / `RezPostCombatDelayS=10` pair satisfies the AC-1 post-combat delay requirement. No config change needed here.

### B. Corpse lifetime — will corpses survive long enough to rez?

| Rule | Value | Assessment |
|------|-------|------------|
| `Character:CorpseResTime` | `10800000` ms = 3 hours | NORMAL — player corpses rezable for 3 hours |
| `Character:CorpseDecayTime` | `604800000` ms = 7 days | NORMAL |
| `Character:EmptyCorpseDecayTime` | `10800000` ms = 3 hours | NORMAL |
| `NPC:MinorNPCCorpseDecayTime` | `450000` ms = 7.5 min | WATCH — NPC corpses decay in 7.5 min |
| `NPC:MajorNPCCorpseDecayTime` | `1500000` ms = 25 min | WATCH — NPC corpses (lvl55+) decay in 25 min |
| `NPC:EmptyNPCCorpseDecayTime` | `0` ms = instant | WATCH — empty NPC corpses vanish immediately |
| `Companions:DeathDespawnS` | `1800` s = 30 min | NORMAL — companion auto-dismiss after 30 min |

**Key finding:** NPC corpse decay timing is important. A companion corpse is an NPC corpse. `NPC:MinorNPCCorpseDecayTime` is 7.5 minutes. The `Companions:RezPostCombatDelayS=10` means the Cleric starts trying within 10 seconds — this is well inside any decay window, so corpse lifetime is NOT a blocker. However, the architect should confirm whether companion corpses use NPC or player corpse decay rules (they may be handled differently in `companion.cpp`).

### C. Rez sickness — will it apply to companion NPC targets?

| Rule | Value | Assessment |
|------|-------|------------|
| `Character:UseResurrectionSickness` | `true` | NORMAL — applies to player characters |
| `Character:ResurrectionSicknessSpellID` | `756` | NORMAL — standard sickness spell |
| `Bots:ResurrectionSickness` | `true` | NORMAL — bot system applies sickness |
| `Bots:ResurrectionSicknessSpell` | `756` | NORMAL |

**Assessment:** Rez sickness rules apply to the rez recipient (player/bot). For NPC companion targets, whether rez sickness is applied depends on the C++ code path — this is the architect/c-expert domain. The config rules themselves look normal.

### D. NPC AI casting rules — are they configured to allow beneficials/heals?

| Rule | Value | Assessment |
|------|-------|------------|
| `Spells:AI_EngagedBeneficialSelfChance` | `100` | NORMAL |
| `Spells:AI_EngagedBeneficialOtherChance` | `25` | NORMAL — 25% chance to cast beneficials on others while engaged |
| `Spells:AI_EngagedDetrimentalChance` | `20` | NORMAL |
| `Spells:AI_IdleBeneficialChance` | `100` | NORMAL — 100% to cast beneficials while idle (post-combat) |
| `Spells:AI_EngagedNoSpellMinRecast` | `500` ms | NORMAL |
| `Spells:AI_EngagedNoSpellMaxRecast` | `1000` ms | NORMAL |
| `Spells:AI_IdleNoSpellMinRecast` | `6000` ms | NORMAL |
| `Spells:AI_IdleNoSpellMaxRecast` | `60000` ms | NORMAL |
| `Spells:AI_HealHPPct` | `50` | NORMAL — heal triggers at 50% HP when no max_hp set in spell |

**Key finding:** `Spells:AI_IdleBeneficialChance=100` means NPCs have 100% chance to try beneficial spells when idle (i.e., post-combat). This is the relevant state for post-combat rez initiation. The AI casting pipeline is NOT blocking rez — in fact, idle beneficial casting is wide open. The bug is elsewhere (the rez request/accept flow, per PRD hypothesis).

### E. Mercs analog — how does the merc rezzer work?

| Rule | Value | Assessment |
|------|-------|------------|
| `Mercs:ResurrectRadius` | `50` | Reference — merc healer rez radius is 50 units |
| `Companions:RezRange` | `200` | Companion rez range is 4x larger — this is intentional |

### F. eqemu_config.json and .env

No rez-related, resurrect-related, or companion-related runtime config found in either file. These are database/code-controlled, not config-file-controlled.

### G. Rules that look unusual or worth flagging

1. **`NPC:OOCRegen`** has TWO entries with values `1` and `0` in different rule sets. The active value depends on which ruleset the zone uses. If OOC regen is 0, a downed companion's mana-regeneration behavior (for the Cleric waiting for mana) could be affected — but this is the Cleric's regen, not the dead companion's. Low priority.

2. **`NPC:LastFightingDelayMovingMax`** has FIVE entries with mixed values (30000 and 20000 ms). Duplicate rule entries may indicate import artifacts; the last value loaded wins. The architect should be aware but this doesn't affect rez.

3. **`Spells:AI_IdleNoSpellMaxRecast`** = 60000 ms (60 seconds). This is the maximum recast delay when an NPC doesn't cast a spell while idle. If the Cleric's rez attempt is being gated by this timer, there could be up to a 60-second window before the next cast check. The 10-second `RezPostCombatDelayS` may fire the rez check before the AI spell timer even runs. Architect should confirm whether the companion rez logic runs independently of `AI_IdleNoSpellMinRecast/MaxRecast` or if it hooks into that timer.

### H. Summary verdict

**No rule values are misconfigured or blocking the auto-rez feature.** All rez-related Companion rules exist, are active, and are set to sane values. The NPC AI casting rules allow beneficial-other casting. The bug (rez cast goes off but nothing happens) is in the C++ rez request/accept code path — the `OP_RezzAnswer`/`OP_RezzRequest` flow for NPC targets — exactly as hypothesized in BUG-001. Config is clean.

**Rules the architect should know exist:**
- `Companions:RezEnabled` (master toggle, currently `true`)
- `Companions:RezPostCombatDelayS` (10 seconds, satisfies AC-1)
- `Companions:RezRange` (200 units)
- `Companions:RezWaiveReagents` (true)
- `Companions:DeathDespawnS` (1800 seconds = 30 min corpse window)

**Potential new rules if architect wants them (from PRD suggestions):**
The PRD mentions `Companions:AutoRezTierPreference` as advisory. No such rule exists yet. If the architect decides tier-preference behavior should be rule-configurable (vs. hard-coded), that would be a new `rule_values` insert — a data-expert task, with a corresponding `RULE_BOOL/INT/STRING` entry in `ruletypes.h` as a c-expert task.

---

## Stage 4: Build

No build work — architecture advisory phase only. Read-only audit.

---

## Open Items

- [ ] Architect to confirm whether companion corpses use NPC corpse decay rules or a custom path
- [ ] Architect to confirm whether Cleric rez trigger fires independently of `Spells:AI_IdleNoSpellMinRecast/MaxRecast` timers
- [ ] If tier-preference rule is desired: data-expert inserts `rule_values`, c-expert adds to `ruletypes.h`

---

## Context for Next Agent

If a future config-expert picks this up during implementation phase:

The auto-rez rules already exist in rule_values (`Companions:RezEnabled`, `Companions:RezPostCombatDelayS`, `Companions:RezRange`, `Companions:RezWaiveReagents`). These were presumably inserted by a prior fix or scaffold. Verify they still exist with:

```sql
SELECT rule_name, rule_value FROM rule_values WHERE rule_name LIKE 'Companions:Rez%';
```

If new rules are needed (e.g., `Companions:AutoRezTierPreference`), the pattern is:
1. c-expert adds `RULE_XXX(Companions, AutoRezTierPreference, default, "description")` to `common/ruletypes.h`
2. data-expert inserts the row into `rule_values` (ruleset_id=1)
3. Server reload via `#reloadrules` or server restart
