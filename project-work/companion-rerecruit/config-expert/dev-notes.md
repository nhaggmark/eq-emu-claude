# Companion Re-recruitment Fix — Dev Notes: config-expert

> **Feature branch:** `bugfix/companion-rerecruit`
> **Agent:** config-expert
> **Task(s):** Architecture support — rule_values triage for re-recruit blockers
> **Date started:** 2026-04-27
> **Current stage:** Research (read-only triage, planning phase)

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| Triage | Enumerate all `Companions:*` rule_values; identify recruit/re-recruit gating rules | PRD approved | Complete |

---

## Stage 1: Plan

Read PRD → query `rule_values` for all `Companions:*` rows → cross-check against `ruletypes.h` defaults → compare DB values vs compiled defaults to flag any custom overrides → report gating rules to architect.

---

## Stage 2: Research

### Sources Consulted

| Source | What I Checked |
|--------|----------------|
| `rule_values` (live DB) | Full `SELECT rule_name, rule_value, notes FROM rule_values WHERE rule_name LIKE 'Companions:%'` |
| `eqemu/common/ruletypes.h` (lines 1181–1254) | All RULE_INT / RULE_BOOL / RULE_REAL macros under `RULE_CATEGORY(Companions)` |
| `akk-stack/server/eqemu_config.json` | No companion keys found |
| `akk-stack/.env` | No companion keys found |

---

## Stage 3: Findings

### Complete `Companions:*` Rule Inventory

All rows queried 2026-04-27. DB value = current live value. Default = compiled default in `ruletypes.h`. Delta = custom override if different from default.

| Rule Name | DB Value | ruletypes.h Default | Delta | Type |
|-----------|----------|---------------------|-------|------|
| Companions:AggressiveScanRadius | 75 | (not in h) | — | INT |
| Companions:AlwaysMeditateRegen | true | true | none | BOOL |
| Companions:BaseRecruitChance | 100 | 50 | **OVERRIDDEN** (50→100) | INT |
| Companions:CasterCombatRange | 70 | (not in h) | — | INT |
| Companions:CompanionFleeEnabled | false | false | none | BOOL |
| Companions:CompanionManaRegenMult | 100 | 100 | none | INT |
| Companions:CompanionSelfPreservePct | 0.20 | 0.20 | none | REAL |
| Companions:CompanionsEnabled | true | true | none | BOOL |
| Companions:DeathDespawnS | 1800 | 1800 | none | INT |
| Companions:DismissedRetentionDays | 30 | 30 | none | INT |
| Companions:EnforceClassRestrictions | true | true | none | BOOL |
| Companions:EnforceRaceRestrictions | true | true | none | BOOL |
| Companions:EquipmentPersistsThroughDeath | true | true | none | BOOL |
| Companions:FormationDistance | 15 | (not in h) | — | INT |
| Companions:GroupChatAddressingEnabled | true | true | none | BOOL |
| Companions:GroupChatResponseStaggerMaxMS | 2000 | 2000 | none | INT |
| Companions:GroupChatResponseStaggerMinMS | 1000 | 1000 | none | INT |
| Companions:HealerManaConservePct | 30 | (not in h) | — | INT |
| Companions:HealThresholdPct | 80 | (not in h) | — | INT |
| Companions:HPRegenPerTic | 1 | 1 | none | INT |
| Companions:LevelRange | 50 | **3** | **OVERRIDDEN** (3→50) | INT |
| Companions:LOMThresholdPct | 15 | (not in h) | — | INT |
| Companions:ManaCutoffPct | 20 | (not in h) | — | INT |
| Companions:MaxLevelOffset | 1 | 1 | none | INT |
| Companions:MaxPerPlayer | 5 | 5 | none | INT |
| Companions:MercRetentionCheckS | 600 | 600 | none | INT |
| Companions:MercSelfPreservePct | 0.10 | 0.10 | none | REAL |
| Companions:MinFaction | 3 | 3 | none | INT |
| Companions:OOCRegenPct | 5 | (not in h) | — | INT |
| Companions:RecallCooldownS | 30 | (not in h) | — | INT |
| Companions:RecruitCooldownS | 900 | 900 | none | INT |
| Companions:ReplacementSpawnDelayS | 30 | 30 | none | INT |
| Companions:ReRecruitBonus | 0.10 | 0.10 | none | REAL |
| Companions:ResistCapBase | 50 | (not in h) | — | INT |
| Companions:RezEnabled | true | (not in h) | — | BOOL |
| Companions:RezPostCombatDelayS | 10 | (not in h) | — | INT |
| Companions:RezRange | 200 | (not in h) | — | INT |
| Companions:RezWaiveReagents | true | (not in h) | — | BOOL |
| Companions:RogueBehindMob | true | (not in h) | — | BOOL |
| Companions:SittingRegenMult | 200 | (not in h) | — | INT |
| Companions:SpellScalePct | 100 | 100 | none | INT |
| Companions:STAToHPFactor | 100 | (not in h) | — | INT |
| Companions:StatScalePct | 100 | 100 | none | INT |
| Companions:UseWeaponDamage | true | (not in h) | — | BOOL |
| Companions:XPContribute | true | true | none | BOOL |
| Companions:XPDeathPenaltyPct | 10 | (not in h) | — | INT |
| Companions:XPSharePct | 100 | 100 | none | INT |

### Rules That Gate Recruitment (RE-RECRUIT RELEVANT)

These are the rules that can block or influence the recruit/re-recruit path:

#### 1. `Companions:LevelRange` — **PRIMARY BLOCKER**
- **DB value:** 50 (already custom-set wide)
- **ruletypes.h default:** 3 (±3 levels)
- **What it does:** Controls the level range (+/-) within which an NPC is eligible for first recruitment relative to player level. If the player outlevels the companion NPC's base level by more than this, the NPC is rejected.
- **Re-recruit relevance:** This is the level-cap blocker reported in BUG-001 (Lydl the Great). The DB value is already set to 50, which is very permissive — but if the player is 50+ levels above the NPC's base type level, it would still reject. More importantly, **there is no separate rule for re-recruit vs first-recruit**. The same `LevelRange` gate applies to both. The fix must happen in C++ logic (bypass this check when a prior recruitment record exists), not by changing this rule value.
- **Recommendation:** Do NOT change this value. The architect needs to add a C++ bypass at the `LevelRange` evaluation site that skips the check when `companion_data` shows a prior recruitment record for this char+NPC pair.

#### 2. `Companions:RecruitCooldownS` — **COOLDOWN BLOCKER**
- **DB value:** 900 (15 minutes)
- **ruletypes.h default:** 900
- **What it does:** Cooldown in seconds after a "failed recruitment attempt" on the same NPC. The notes say "failed recruitment" but based on BUG-001 behavior, the cooldown fires after dismissal/death too.
- **Re-recruit relevance:** This is the "won't discuss joining you again so soon" blocker. No separate re-recruit cooldown rule exists — same rule for both paths.
- **Recommendation:** Do NOT change this value to 0 globally (it may serve a purpose for first-recruit spam prevention). The architect needs a C++ bypass that skips the cooldown check when a prior recruitment record exists. Alternatively, if the data-expert confirms cooldowns are stored in `data_buckets` keyed as `companion_cooldown_{npc_type_id}_{char_id}`, the Lua path can check for prior recruitment record before applying the cooldown message.

#### 3. `Companions:MaxLevelOffset` — **COMPANION LEVEL CAP**
- **DB value:** 1
- **ruletypes.h default:** 1
- **What it does:** Companion's maximum level is capped at `player_level - MaxLevelOffset`. So with offset=1, a companion can never exceed player_level - 1.
- **Re-recruit relevance:** This is a cap on how high a companion can level, not a recruitment gate. However if a companion was leveled to a value that exceeds player_level - 1 (e.g., companion at 35, player de-levels to 34), this could interact with re-recruit. The architect should clarify whether this causes a rejection or just clamps the companion's level silently on re-recruit.
- **Recommendation:** No change needed for re-recruit fix. The architect should note this as an edge case to evaluate.

#### 4. `Companions:MinFaction` — **FIRST-RECRUIT ONLY**
- **DB value:** 3 (Kindly)
- **What it does:** Minimum faction required. This is a first-recruit gate.
- **Re-recruit relevance:** Should not apply to re-recruit. Architect should confirm the C++ faction check has the same prior-record bypass applied.

#### 5. `Companions:BaseRecruitChance` — **SUCCESS ROLL**
- **DB value:** 100 (guaranteed success, overridden from default 50)
- **What it does:** Base success percentage for the recruitment persuasion roll.
- **Re-recruit relevance:** At 100%, this is not a blocker in practice. But if the re-recruit path also runs this roll, it should be bypassed for re-recruits (a returning companion shouldn't need to be "persuaded" again).

#### 6. `Companions:ReRecruitBonus` — **PARTIAL MITIGATION**
- **DB value:** 0.10
- **What it does:** Adds 10% to the persuasion roll for re-recruiting a voluntarily dismissed companion.
- **Re-recruit relevance:** This rule exists as evidence the system has SOME awareness of re-recruit vs first-recruit. However it only applies a bonus, it does not bypass the level check or cooldown. The C++ code that reads this rule is the place where a full bypass should be inserted.

### Rules That Do NOT Block Re-Recruit

These rules are confirmed NOT relevant to the re-recruit gating problem:

- `Companions:CompanionsEnabled` — master toggle, not a re-recruit gate
- `Companions:DismissedRetentionDays` — garbage collection, not a gate
- `Companions:DeathDespawnS` — despawn timer after death, not a recruit gate
- `Companions:MaxPerPlayer` — group slot cap, not a per-NPC gate

### Config File Findings

No companion-related settings found in `eqemu_config.json` or `.env`. All companion configuration is rule-driven. Server config is not a factor in this bug.

---

## Recommendations for Architect

### Config-level changes needed: NONE

All three blockers (level cap, cooldown, dismissed flag) are enforced in C++ or Lua logic that reads rule values. The rules themselves are not the problem — the problem is that the C++ validation logic applies them uniformly to both first-recruit and re-recruit paths.

**The invariant cannot be satisfied purely through rule changes.** Setting `LevelRange=999` and `RecruitCooldownS=0` would "fix" re-recruit but would also remove all gating from first-recruit, violating PRD Non-Goal #1.

### Recommended architecture

The fix must happen at the C++ recruit-validation layer:

1. **Before any level check** — query `companion_data` for a prior record matching (char_id, npc_type_id). If a record exists → bypass `LevelRange` check entirely.
2. **Before any cooldown check** — same prior-record query. If a record exists → bypass `RecruitCooldownS` check entirely.
3. **On re-recruit** — clear the dismissed/suspended/dead flags in `companion_data`. This is data-expert territory (SQL UPDATE) and lua-expert territory if the flag is set in Lua.

The `ReRecruitBonus` rule (0.10) is already reading the prior-record table; that code path is where the bypass logic should be inserted.

### New rule suggestion (optional, for architect to decide)

If the architect wants to expose the bypass as a configurable toggle:

```
RULE_BOOL(Companions, BypassLevelCheckOnReRecruit, true, "Skip level range check when re-recruiting a previously-recruited companion")
RULE_BOOL(Companions, BypassCooldownOnReRecruit, true, "Skip recruit cooldown when re-recruiting a previously-recruited companion")
```

These would default to `true` (the desired behavior) and allow the server admin to restore gating if desired. Whether to add these rules is the architect's call — the PRD invariant is clear enough that hard-coding the bypass is also valid.

---

## Open Items

- [ ] Architect to confirm whether `MaxLevelOffset` causes a rejection on re-recruit or silently clamps — this determines if a bypass is needed there too.
- [ ] Architect to confirm the C++ code site that reads `ReRecruitBonus` — that is the likely place to insert the full bypass.
- [ ] data-expert to confirm current schema of `companion_data` (column names for dismissed/suspended/dead state).
- [ ] lua-expert to confirm whether the cooldown message path in `companion.lua` ~line 399 is still accurate and whether the cooldown is set/checked there or in C++.

---

## Context for Next Agent

This is a read-only triage. No rule values were changed. The conclusion is that no rule change alone can satisfy the re-recruit invariant without breaking first-recruit gating. The fix is C++ logic changes (c-expert) with possible Lua changes (lua-expert) and a `companion_data` flag-clearing change (data-expert). Config-expert has no build tasks for this feature unless the architect decides to add new bypass-toggle rules, in which case config-expert would add `rule_values` INSERT statements.
