# Companion Equipment Management Enhancement — Dev Notes: Config Expert

> **Feature branch:** `feature/companion-equipment`
> **Agent:** config-expert
> **Task(s):** Task #3 — Assess configuration needs for companion equipment
> **Date started:** 2026-03-07
> **Current stage:** Complete (Architecture phase). Implementation task assigned — waiting for implementation phase spawn.

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 3 | Assess configuration needs for companion equipment | — | Complete |

---

## Stage 1: Plan

### Research Questions

The architect asked me to answer five questions:
1. Should class/race restriction enforcement be toggleable via rules?
2. Any existing rules related to NPC equipment or companion trading?
3. Should equipment persistence through death be toggleable?
4. Any existing Companions category rules that relate to equipment?
5. What rule values would the architect need?

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `eqemu/common/ruletypes.h` | 1181–1205 | Full Companions rule category — 24 rules, none equipment-related |
| `eqemu/common/ruletypes.h` | 773, 863 | Bot class/race gear restriction rules: `Bots:AllowBotEquipAnyClassGear`, `Bots:AllowBotEquipAnyRaceGear` |
| `eqemu/common/ruletypes.h` | 1147–1160 | Items category — no NPC equip restriction rules |
| `peq.rule_values` (DB query) | — | All 24 Companions rules confirmed live; Bots equip rules confirmed |

---

## Stage 2: Research

### Finding 1: Companions Category — No Equipment Rules Exist

The `Companions` category in `ruletypes.h` (lines 1181–1205) has 24 rules covering
recruitment, scaling, regen, XP, chat, and death despawn. **None relate to equipment.**

Current Companions rules (full inventory):

| Rule | Type | Default | Purpose |
|------|------|---------|---------|
| `Companions:CompanionsEnabled` | bool | true | Master toggle |
| `Companions:MaxPerPlayer` | int | 5 | Max active companions |
| `Companions:LevelRange` | int | 3 | Recruitment level range |
| `Companions:BaseRecruitChance` | int | 50 | Base recruit % |
| `Companions:StatScalePct` | int | 100 | Stat multiplier |
| `Companions:SpellScalePct` | int | 100 | Spell scaling |
| `Companions:RecruitCooldownS` | int | 900 | Failed recruit cooldown |
| `Companions:DeathDespawnS` | int | 1800 | Auto-dismiss after death (seconds) |
| `Companions:MinFaction` | int | 3 | Min faction to recruit |
| `Companions:XPContribute` | bool | true | XP split participation |
| `Companions:MercRetentionCheckS` | int | 600 | Merc retention check interval |
| `Companions:ReplacementSpawnDelayS` | int | 30 | Replacement NPC spawn delay |
| `Companions:XPSharePct` | int | 50 | Companion XP share % |
| `Companions:MaxLevelOffset` | int | 1 | Companion max level = player - N |
| `Companions:ReRecruitBonus` | real | 0.10 | Re-recruit persuasion bonus |
| `Companions:DismissedRetentionDays` | int | 30 | DB retention after dismiss |
| `Companions:CompanionSelfPreservePct` | real | 0.20 | Self-preserve HP threshold |
| `Companions:MercSelfPreservePct` | real | 0.10 | Merc self-preserve threshold |
| `Companions:HPRegenPerTic` | int | 1 | Min HP regen/tic |
| `Companions:OOCRegenPct` | int | 5 | OOC regen % of max HP |
| `Companions:RecallCooldownS` | int | 30 | !recall cooldown |
| `Companions:GroupChatAddressingEnabled` | bool | true | @Name chat addressing |
| `Companions:GroupChatResponseStaggerMinMS` | int | 1000 | Chat stagger min |
| `Companions:GroupChatResponseStaggerMaxMS` | int | 2000 | Chat stagger max |

### Finding 2: Bot Equipment Rules as a Direct Analog

The Bot system has two directly relevant equip restriction rules in `ruletypes.h`:

```
RULE_BOOL(Bots, AllowBotEquipAnyRaceGear, false, ...)   // line 773
RULE_BOOL(Bots, AllowBotEquipAnyClassGear, false, ...)  // line 863
```

Both default to `false` (restrictions enforced). This is the exact pattern we need for
companions. The naming convention and type are clear precedent.

### Finding 3: No Existing NPC/Companion Equipment Rules

There are no existing rules for:
- NPC equipment persistence
- Companion equipment persistence through death
- Companion equipment persistence through dismissal
- NPC trade window item restriction enforcement

The `Items` category (lines 1147–1160) has no rules that apply to NPC or companion
equipment behavior — only player-facing item property toggles.

### Finding 4: Existing Death Rule Does Not Cover Equipment

`Companions:DeathDespawnS` (int, 1800) controls how long after death before a
companion auto-dismisses. This is NOT an equipment persistence rule — it controls
despawn timing. Equipment persistence through death is a separate, unruled behavior
that the PRD requires as default-on.

---

## Stage 3: Findings and Recommendations

### Recommended New Rules

Based on the PRD requirements and the Bot system's precedent, three new rules should
be added to `ruletypes.h` in the `Companions` category:

#### Rule 1: `Companions:EnforceClassRestrictions`
```
RULE_BOOL(Companions, EnforceClassRestrictions, true,
    "Enforce class-based item restrictions when equipping items on companions")
```
- **Type:** bool
- **Default:** `true` (restrictions enforced — matches Bot system behavior and PRD goal #7)
- **Rationale:** PRD requires class restriction enforcement. Toggleable for server ops
  who want permissive companion equipment (e.g., cosmetic-only mode). Bot analog:
  `Bots:AllowBotEquipAnyClassGear` (but inverted — our rule is "enforce" not "allow any").
- **Implementation note:** The c-expert needs this to gate the class bitmask check in
  the trade handler. When `false`, skip the class check and allow any class to equip
  any item.

#### Rule 2: `Companions:EnforceRaceRestrictions`
```
RULE_BOOL(Companions, EnforceRaceRestrictions, true,
    "Enforce race-based item restrictions when equipping items on companions")
```
- **Type:** bool
- **Default:** `true` (restrictions enforced — matches Bot system behavior and PRD goal #7)
- **Rationale:** Separate from class so server ops can independently toggle class vs
  race enforcement. Bot analog: `Bots:AllowBotEquipAnyRaceGear`.
- **Implementation note:** Same gating pattern as class restrictions above.

#### Rule 3: `Companions:EquipmentPersistsThroughDeath`
```
RULE_BOOL(Companions, EquipmentPersistsThroughDeath, true,
    "If true, companion equipment is retained after death (not dropped on corpse)")
```
- **Type:** bool
- **Default:** `true` (equipment persists — matches PRD goal #6 and design intent)
- **Rationale:** The PRD explicitly calls out equipment persistence through death as a
  non-goal for loss and a required feature to prevent punishing small-group play. Making
  it a rule allows a server admin to optionally enable equipment loss on death if
  desired. The c-expert/lua-expert needs this to gate whether equipment is cleared from
  the companion's storage on death.
- **Implementation note:** When `false`, the death handler should remove equipment from
  the companion's storage slot table (or transfer to corpse — architect decides). Default
  `true` means no change on death.

### Rules the PRD Suggested but I Do NOT Recommend as Rules

The PRD (Appendix) also suggested `Companions:EquipmentPersistsThroughDismissal`. I
recommend against this as a rule because:
- Dismissal persistence is handled by the companion identity/database persistence system
  (the same system that saves the companion's existence across sessions)
- There is no meaningful "on-dismiss equipment action" to toggle — equipment is stored
  in the DB row, and if the row persists (governed by `DismissedRetentionDays`), so does
  the equipment
- Adding a separate persistence toggle here would create a confusing interaction with
  `DismissedRetentionDays`
- **Recommendation:** The c-expert/lua-expert should persist equipment in the same DB
  record as the companion identity. No separate rule needed.

### Verdict: Config-First vs Code-First

| Question | Answer |
|----------|--------|
| Can class/race enforcement be done via existing rules? | No — new rules needed |
| Do existing rules cover equipment persistence? | No — new rule needed for death; dismissal needs no rule |
| Can any PRD requirement be achieved via config alone (no C++ changes)? | No — all equipment features require C++ and/or Lua changes |
| Do any existing rules conflict with the design? | No conflicts found |

**Bottom line:** This feature cannot be achieved through configuration alone. The three
new rules above gate behavior that requires new C++ code (trade handler, death handler,
class/race bitmask check). The config-expert's contribution is: define the three new
rules in `ruletypes.h` and insert their initial values into `rule_values`.

---

## Stage 4: Build

### Implementation Log (2026-03-07)

**Task #1: Add 3 new Companions rules to ruletypes.h**

- File edited: `/mnt/d/Dev/eq/eqemu/common/ruletypes.h`
- Inserted after line 1205 (GroupChatResponseStaggerMaxMS), before RULE_CATEGORY_END():
  ```cpp
  RULE_BOOL(Companions, EnforceClassRestrictions, true, "Enforce class-based item restrictions when equipping items on companions")
  RULE_BOOL(Companions, EnforceRaceRestrictions, true, "Enforce race-based item restrictions when equipping items on companions")
  RULE_BOOL(Companions, EquipmentPersistsThroughDeath, true, "If true, companion equipment is retained after death (not dropped on corpse)")
  ```
- Build result: common library (libcommon.a) compiled and linked cleanly — ruletypes.h changes are valid.
  Build failure at companion.cpp (m_inv private member errors) is a pre-existing c-expert blocker unrelated to these rules.
- Commit: `6d4c71f98` on `feature/companion-equipment` branch in eqemu/
- Task #1: **Complete**

**Pending: Task #2 (data-expert) — Insert rule_values rows**
Data-expert is inserting the 3 DB rows for these rules. The SQL is in the "Context for Next Agent" section above.

---

## Open Items

- [ ] Architect to confirm which of the three recommended rules they want in the
  implementation plan, and whether any additional rules are needed
- [ ] c-expert to confirm rule names match what they'll use in C++ (e.g.,
  `RuleB(Companions, EnforceClassRestrictions)`)
- [ ] If architect decides equipment loss on death IS desired (rule default `false`),
  data-expert may need to add a column to the companion equipment table for "equipped
  at death" tracking

---

## Context for Next Agent

When the implementation phase starts and config-expert is assigned tasks:

**Three new rules to add to `eqemu/common/ruletypes.h`** in the `Companions` category
(after line 1205, before `RULE_CATEGORY_END()`):

```cpp
RULE_BOOL(Companions, EnforceClassRestrictions, true, "Enforce class-based item restrictions when equipping items on companions")
RULE_BOOL(Companions, EnforceRaceRestrictions, true, "Enforce race-based item restrictions when equipping items on companions")
RULE_BOOL(Companions, EquipmentPersistsThroughDeath, true, "If true, companion equipment is retained after death (not dropped on corpse)")
```

**Three new rows to insert into `peq.rule_values`** (ruleset_id = 1):

```sql
INSERT INTO rule_values (ruleset_id, rule_name, rule_value, notes) VALUES
(1, 'Companions:EnforceClassRestrictions', 'true', 'Enforce class-based item restrictions when equipping items on companions'),
(1, 'Companions:EnforceRaceRestrictions', 'true', 'Enforce race-based item restrictions when equipping items on companions'),
(1, 'Companions:EquipmentPersistsThroughDeath', 'true', 'If true, companion equipment is retained after death (not dropped on corpse)');
```

After adding rules to `ruletypes.h`, a C++ rebuild is required for them to take effect.
The `#reloadrules` in-game command reloads DB values but does NOT pick up new rule
definitions from `ruletypes.h` — that requires a full rebuild.
