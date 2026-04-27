# XP Retune — Architecture & Implementation Plan

> **Feature branch:** `feature/xp-retune`
> **PRD:** `game-designer/prd.md`
> **Author:** architect
> **Date:** 2026-04-27 (v2 — companion XP parity refactor + AA-extensibility seams)
> **Status:** v2 Approved by architecture team (architect + c-expert + config-expert); pending user review before code is written

---

## Document Versioning

This document supersedes the v1 plan (rate-change only, single `rule_values`
UPDATE). The v1 plan is preserved at the bottom of this file under the
**"v1 Plan (Superseded)"** section for historical reference and to support
clean revert if v2 is abandoned.

The active plan is **v2** below.

---

## v2 Executive Summary

Two coordinated changes, shipped together on `feature/xp-retune`:

1. **Kill XP rate retune (carried over from v1)** — `Character:ExpMultiplier`
   3.0 → 2.0 via `rule_values` UPDATE, applied live via `#reloadrulesworld`.
   AA XP unchanged at 3.0x.

2. **Companion XP parity refactor (NEW in v2)** — C++ refactor of the
   companion XP distribution path so a companion in a group earns the same
   per-share XP as the player, on every flat-XP event (kill,
   `quest::exp()`, Lua `:AddEXP()`, flat task rewards), in all group
   compositions 1+1 through 1+4. Implemented via a new
   `Companion::CalculateExp` that mirrors `Client::CalculateExp` minus
   AA/race-class/leadership concerns. The hardcoded `XPSharePct > 100`
   clamp at `exp.cpp:1199` is repurposed: the rule becomes a post-multiplier
   scalar with default `100` (= parity). The refactor leaves explicit
   AA-extensibility seams so a future companion-AA feature can attach
   without re-doing the parity work.

**Build/restart cycle is required for v2.** Rule UPDATE alone does not deliver parity.

**Total agents involved**: c-expert (C++ refactor), config-expert (two
`rule_values` UPDATEs), infra-expert (rebuild + restart sequencing),
game-tester (validation against PRD's 15 numbered cases).

---

## v2 Existing System Analysis

### Current XP flow (per-kill, group of 1 player + N companions)

```
NPC dies
  ↓
Mob::AddToHateList aggregator → Group::SplitExp(group_experience, conlevel)
  ↓
Group::SplitExp (eqemu/zone/exp.cpp:1123-1219):
  - group_experience already has GROUP BONUS pre-applied (group of 2: +0%, etc.)
  - member_count = GroupCount() — counts companions too (groups.cpp:1184)
  - member_share = group_experience / member_count
  ↓
For each member m in members[]:
    if (m->IsClient()):                                     ← PLAYER PATH
        m->CastToClient()->AddEXP(member_share, conlevel)
            ↓ exp.cpp:497-572
        Client::AddEXP:
            ↓ exp.cpp:404-495
        Client::CalculateExp(member_share, ...):
            applies Character:ExpMultiplier      ← (3.0 currently)
            applies zone->newzone_data.zone_exp_multiplier  (ZEM)
            applies HotZoneBonus if zone->IsHotzone()
            applies UseRaceClassExpBonuses (player-only)
            applies con-scaling via GetConLevelModifierPercent (file-scope static helper in exp.cpp)
            applies Character:FinalExpMultiplier
            applies level_exp_mods (per-level XP curve, levels 66-70 brake)
            splits into add_exp + add_aaxp via CalculateStandardAAExp
        SetEXP(...) commits to character_data.exp / aa_exp

    else if (m->IsCompanion()):                             ← COMPANION PATH
        xp_share_pct = RuleI(Companions, XPSharePct)        ← currently 50
        if (xp_share_pct > 100) xp_share_pct = 100          ← THE CLAMP, exp.cpp:1198-1199
        companion_xp = member_share * xp_share_pct / 100    ← raw fraction, no multipliers
        m->CastToCompanion()->AddExperience(companion_xp)
            ↓ companion.cpp:3341-3360
        Companion::AddExperience(uint32 xp):
            m_companion_xp += xp                            ← no multipliers anywhere
            CheckForLevelUp()
```

### Architectural divergence

The player path runs through the multiplier pipeline. The companion path does not.
Even if `XPSharePct = 100` (max under the clamp), the companion gets only
the un-multiplied per-member slice. With `Character:ExpMultiplier = 3.0`,
the player's actual XP is `member_share * 3.0 * (other modifiers)`, so the
companion sees ~33% of what the player sees at the clamp ceiling, and ~17%
at the live default `XPSharePct = 50`.

### quest::exp / Lua AddEXP also bypass the pipeline

- `questmgr.cpp:1217` calls `initiator->AddEXP(...)` — fires only for `Client`. Companions ignored.
- `lua_companion.cpp:129` calls `Companion::AddExperience(xp)` directly — same raw accumulation, no multipliers.

### Current values (verified by config-expert against live `peq.rule_values`, ruleset_id=1)

| Rule | Current Value | Notes |
|------|---------------|-------|
| `Character:ExpMultiplier` | `'3.0'` | Player kill-XP rate, applied in `Client::CalculateExp` |
| `Character:AAExpMultiplier` | `'3.0'` | Player AA-XP rate; unchanged by this feature |
| `Character:FinalExpMultiplier` | (default) | Post-everything multiplier |
| `Companions:XPSharePct` | `'50'` | Companion XP scalar; currently pre-multiplier, clamped 0-100 |
| `Companions:XPContribute` | (default `true`) | Whether companion presence dilutes per-member slice |

### Gap analysis

PRD requires post-split parity for all flat-XP events. Two structural problems:

1. **Companion path skips `Client::CalculateExp`** — the multiplier stack
   never reaches it.
2. **The 0-100 clamp on `XPSharePct`** prevents rule-only fixes by capping
   the rule's effective value at 100, while parity actually requires the
   companion to receive **more** than the un-multiplied slice (the multiplied
   amount is several times larger than the raw slice).

Refactor must address both, in a way that:
- Works for the group split path AND for direct calls (quest::exp, Lua AddEXP).
- Leaves clean attachment points for future companion-AA accrual.
- Does not affect pet/swarm pet/charm pet/merc XP (all of which use independent paths).

---

## v2 Technical Approach

### Architecture decision

**Mirror pipeline.** Add a `Companion::CalculateExp` that runs the same
multiplier stack as `Client::CalculateExp` (minus the player-only paths)
and call it from `Companion::AddExperience`. Repurpose `Companions:XPSharePct`
as a post-multiplier scalar with default `100` = parity.

| Component | Change Type | Justification |
|-----------|-------------|---------------|
| `Companion::CalculateExp` | NEW method on Companion | Cleanest separation; mirrors `Client::CalculateExp` shape; this IS the AA seam |
| `Companion::AddExperience` | Signature + body change | Add `conlevel` param; call `CalculateExp` first; apply `XPSharePct` post-multiplier scalar |
| `Group::SplitExp` companion dispatch | Refactor | Pass raw `member_share` + `consider_level`; remove the `* xp_share_pct / 100` pre-multiplication |
| `GetConLevelModifierPercent` | Expose existing file-scope static via `exp.h` | Already a file-scope `static` in `exp.cpp:218` (verified by c-expert second-round trace) — NOT a Client method as initially assumed. Cleanest fix is to add the declaration to `exp.h` so `companion.cpp` can call it. No class hierarchy change required. |
| `attack.cpp:2791-2810` companion XP dispatch | Refactor (parallel to exp.cpp:1196-1218) | A SECOND companion XP dispatch site exists in `attack.cpp` (solo-kill path) with the same clamp pattern. Apply the same fix: pass raw `final_exp` + conlevel, drop pre-scaling. |
| `Lua_Companion::AddExperience` | Signature update | Accept optional conlevel param so Lua paths benefit from multiplier pipeline |
| `Companions:XPSharePct` | Repurpose semantically | Was: pre-multiplier fraction (clamped 0-100). Now: post-multiplier scalar (clamped 0-100, default 100 = parity). Operator can dial down sub-parity, not above. |
| `ruletypes.h` default for `XPSharePct` | 50 → 100 | Parity is the new default behavior |
| `rule_values` ruleset_id=1 row for `XPSharePct` | UPDATE 50 → 100 | Existing explicit row needs UPDATE; ruletypes.h default change only affects new rulesets |
| `Character:ExpMultiplier` | UPDATE 3.0 → 2.0 (v1 task carried over) | Rate retune, unchanged from v1 |

### Considered and rejected alternatives

| Alternative | Rejected Because |
|-------------|------------------|
| **Route companion through `Client::CalculateExp` polymorphically** | Would force Companion to be a Client subtype OR refactor CalculateExp to a free function dropping `this`-state (AA caps, etc.). Architectural mess for a parity goal. |
| **Pre-compute final per-member XP in `Group::SplitExp`** | Doesn't help `quest::exp()` or `Lua_Companion::AddExperience`, which bypass `SplitExp`. Fails PRD cases 7-8. |
| **Cap-removal-only on `XPSharePct`** (Approach A) | Leaves rule semantics surprising: name says "SharePct" but values can exceed 100. Worst readability for operators. |
| **Deprecate `XPSharePct`, introduce `Companions:XPMultiplier`** (Approach C) | Adds rule clutter; old rule becomes vestigial. Existing operator setups that use `XPSharePct = 50` would silently lose effect. |

**Approach (B) chosen for `XPSharePct`** — keep clamp 0-100, change
default to 100, repurpose as post-multiplier scalar. Reuses existing rule
with semantically-coherent meaning ("percentage of parity share companion
receives, default 100 = full parity"). Operators who want sub-parity (e.g.
companion gets 75% of what player gets after multipliers) can still tune
that; operators who want above-parity would use a different rule (which
the future companion-AA feature would introduce as a separate concern).

### Data model

Existing tables only. No DDL. Two `rule_values` UPDATEs (both on ruleset_id=1).

```
peq.rule_values (
  ruleset_id  INT,
  rule_name   VARCHAR,
  rule_value  VARCHAR,
  notes       VARCHAR
)
PRIMARY KEY (ruleset_id, rule_name)
```

### Code-path diagram — BEFORE vs AFTER

#### BEFORE (current behavior)

```
Group::SplitExp:
  member_share = group_experience / member_count
  for each m in members:
    if Client:    AddEXP(member_share, conlevel)
                    └→ CalculateExp [multipliers]
    if Companion: AddExperience(member_share * xp_share_pct/100)  [clamped 0-100]
                    └→ m_companion_xp += xp  [NO multipliers]

quest::exp(N) → initiator->AddEXP(N) → CalculateExp [multipliers]   (Client only)
Lua  comp:AddExperience(N) → AddExperience(N) → m_companion_xp += xp  [NO multipliers]
```

#### AFTER (v2 refactor)

```
Group::SplitExp:
  member_share = group_experience / member_count
  for each m in members:
    if Client:    AddEXP(member_share, conlevel)
                    └→ CalculateExp [multipliers]
    if Companion: AddExperience(member_share, conlevel)
                    └→ CalculateExp [multipliers, mirrored — NO AA/race-class/leadership]
                    └→ apply XPSharePct/100 [post-multiplier scalar, default 100 = parity]
                    └→ m_companion_xp += scaled_xp

quest::exp(N) → initiator->AddEXP(N) → CalculateExp [multipliers]   (Client only)
Lua  comp:AddExperience(N) → AddExperience(N, 0xFF)
                              └→ CalculateExp [multipliers]
                              └→ apply XPSharePct/100
                              └→ m_companion_xp += scaled_xp
```

The `XPSharePct` post-multiplier scalar is applied **inside `Companion::AddExperience`**,
not inside `Group::SplitExp`, to ensure all entry points (group split,
direct quest grants, Lua grants) receive the same scaling.

### Code changes

#### C++ changes (c-expert)

**File 1: `eqemu/zone/exp.h` (or equivalent — c-expert determines best surface)**
- `GetConLevelModifierPercent` is already a file-scope `static` in `exp.cpp:218` (verified by c-expert second-round source trace 2026-04-27). It is NOT a `Client::` method as initially assumed in the architect's first pass.
- **Cleanest fix:** add a declaration for `GetConLevelModifierPercent(uint8 conlevel)` to `exp.h` so `companion.cpp` can `#include` it and call the same single source of truth.
- **Alternative considered and rejected:** promoting to `Mob::` protected static would require touching `mob.h`/`mob.cpp` and updating all existing callers — bigger refactor for no semantic gain over the exp.h exposure.
- **Alternative considered and rejected:** inline duplication in `companion.cpp` — small (7-line switch per c-expert) but creates a two-copy maintenance trap.
- No `mob.h` / `mob.cpp` changes required.

**File 2: `eqemu/zone/attack.cpp` (lines 2791-2810)**
- **Second companion XP dispatch site** — solo-kill path (NOT routed through `Group::SplitExp`). Has the same clamp pattern as `exp.cpp:1198-1199`. c-expert confirmed via source grep that `XPSharePct` has exactly two readers: `exp.cpp:1197` and `attack.cpp:2794`.
- Apply the same fix: change companion dispatch to pass raw `final_exp` + conlevel to `Companion::AddExperience`. The `XPSharePct` pre-multiplication is removed here too — the rule is now applied inside `Companion::AddExperience` (single application site for all paths).
- Verify both sites in c-expert's PR diff before merging.

**File 3: `eqemu/zone/companion.h`**
- Add declaration: `uint32 CalculateExp(uint32 raw_xp, uint8 conlevel);`
- Update `AddExperience` signature: `void AddExperience(uint32 xp, uint8 conlevel = 0xFF);`
- Add a code comment on `CalculateExp` documenting the AA-extensibility seam (see "AA-Extensibility Seams" section below).

**File 4: `eqemu/zone/companion.cpp`**
- Implement `Companion::CalculateExp` mirroring `Client::CalculateExp` minus:
  - AA split (`add_aaxp`) — companions don't have AAs in this feature.
  - `UseRaceClassExpBonuses` — companion-irrelevant.
  - `CalculateLeadershipExp` — companion-irrelevant.
- Update `Companion::AddExperience(uint32 xp, uint8 conlevel)`:
  1. `uint32 multiplied = CalculateExp(xp, conlevel);`
  2. `int xp_share_pct = RuleI(Companions, XPSharePct);` (clamp 0-100 retained)
  3. `uint32 final_xp = multiplied * xp_share_pct / 100;`
  4. `m_companion_xp += final_xp;`
  5. `CheckForLevelUp();` (existing behavior preserved)

**File 5: `eqemu/zone/exp.cpp` (lines 1196-1218)**
- Companion dispatch: change from
  `m->CastToCompanion()->AddExperience(member_share * xp_share_pct / 100)`
  to
  `m->CastToCompanion()->AddExperience(member_share, consider_level)`.
- Remove the `xp_share_pct` pre-multiplication and the clamp at this site.
  The clamp is now applied inside `Companion::AddExperience` (or implicit
  via the rule's interpretation as a post-multiplier with the same 0-100
  range).

**File 6: `eqemu/zone/lua_companion.cpp`**
- Update `Lua_Companion::AddExperience` binding to accept an optional
  `conlevel` parameter (default 0xFF, meaning "skip con-scaling, treat as
  flat quest XP").
- Existing single-arg callers (e.g., `:AddExperience(N)` in Lua scripts)
  continue to work and now route through the multiplier pipeline.

**File 7: `eqemu/common/ruletypes.h` (lines 1191-1208 area)**
- Change default for `Companions:XPSharePct` from `50` to `100`.
- Update the description comment to reflect the new semantic ("post-multiplier
  scalar applied to companion XP after the standard multiplier pipeline;
  100 = parity with player per-share").

#### Database changes (config-expert)

**Task A — Apply XP rate retune (carried over from v1, sequenced first):**

```sql
-- Pre-check (record the "before" state)
SELECT ruleset_id, rule_name, rule_value
  FROM peq.rule_values
 WHERE ruleset_id = 1
   AND rule_name IN ('Character:ExpMultiplier', 'Character:AAExpMultiplier');
-- Expected: ExpMultiplier='3.0', AAExpMultiplier='3.0'

-- Forward
UPDATE peq.rule_values
   SET rule_value = '2.0'
 WHERE ruleset_id = 1
   AND rule_name  = 'Character:ExpMultiplier';
-- Expect 1 row affected

-- Post-check
SELECT ruleset_id, rule_name, rule_value
  FROM peq.rule_values
 WHERE ruleset_id = 1
   AND rule_name IN ('Character:ExpMultiplier', 'Character:AAExpMultiplier');
-- Expected: ExpMultiplier='2.0', AAExpMultiplier='3.0' (unchanged guard)

-- Then in-game GM:
#reloadrulesworld

-- Rollback
UPDATE peq.rule_values
   SET rule_value = '3.0'
 WHERE ruleset_id = 1
   AND rule_name  = 'Character:ExpMultiplier';
-- followed by #reloadrulesworld
```

**Task D — Apply companion XPSharePct repurpose (NEW in v2, sequenced after rebuild + restart):**

```sql
-- Pre-check
SELECT ruleset_id, rule_name, rule_value
  FROM peq.rule_values
 WHERE ruleset_id = 1
   AND rule_name  = 'Companions:XPSharePct';
-- Expected: '50'

-- Forward
UPDATE peq.rule_values
   SET rule_value = '100'
 WHERE ruleset_id = 1
   AND rule_name  = 'Companions:XPSharePct';
-- Expect 1 row affected

-- Post-check
SELECT ruleset_id, rule_name, rule_value
  FROM peq.rule_values
 WHERE ruleset_id = 1
   AND rule_name  = 'Companions:XPSharePct';
-- Expected: '100'

-- Then in-game GM:
#reloadrulesworld

-- Rollback
UPDATE peq.rule_values
   SET rule_value = '50'
 WHERE ruleset_id = 1
   AND rule_name  = 'Companions:XPSharePct';
-- followed by #reloadrulesworld
```

#### Configuration changes
None (no `eqemu_config.json` / `.env` / `login.json` edits).

#### Quest script changes
None.

### AA-extensibility seams

The PRD requires the refactor to leave clean attachment points so a future
companion-AA feature can plug in without re-doing parity work. The chosen
mirror-pipeline approach makes this structural — not just a code comment.

**Primary seam: `Companion::CalculateExp` signature evolution**

Current (v2) signature:
```cpp
uint32 Companion::CalculateExp(uint32 raw_xp, uint8 conlevel);
```

Future companion-AA signature (NOT implemented in this feature):
```cpp
uint32 Companion::CalculateExp(uint32 raw_xp, uint8 conlevel, uint32& add_aaxp);
```

The signature evolution mirrors `Client::CalculateExp(uint64 in, uint64& add_exp, uint64& add_aaxp, uint8 conlevel, bool resexp)`.
The future feature would:
1. Add the `add_aaxp` out-parameter to `CalculateExp`.
2. Inside `CalculateExp`, split the multiplied XP into regular + AA buckets
   based on a new rule `Companions:AAExpMultiplier` (config-expert task at
   that future time, NOT this feature).
3. Update `Companion::AddExperience` to pass `add_aaxp` through to a new
   `Companion::AddAAExperience(uint32)` (which would manage companion AA
   point accumulation — out of scope here).

**Code comment to add in `companion.cpp`** (c-expert action item):

```cpp
// Companion::CalculateExp — mirrors Client::CalculateExp minus AA split,
// race/class bonuses, and leadership XP. AA-extensibility seam: a future
// companion-AA feature will add a `uint32& add_aaxp` out-parameter here
// and split the multiplied XP into regular and AA buckets, exactly
// paralleling Client::CalculateExp's add_exp / add_aaxp split. The
// companion side will then add a Companion::AddAAExperience method and
// a Companions:AAExpMultiplier rule. None of that is wired in this
// feature — only the structural seam exists here.
```

**Secondary seam: rule namespace reservation**

The `Companions:` rule namespace is documented in this architecture doc as
the home for future AA-related rules (`Companions:AAExpMultiplier`,
`Companions:AAExpEnabled`, etc.). config-expert confirmed the rule_values
schema accommodates these without changes; the future feature will INSERT
its own rule rows.

**Tertiary seam: Lua binding**

`Lua_Companion::AddExperience` already accepts an optional `conlevel`
parameter via the v2 binding update. A future feature that adds AA-XP
direct-grant capability would extend the binding similarly (e.g., a new
`Lua_Companion::AddAAExperience(uint32)` binding) without churning the
existing parity binding.

### Live reload sequence

After the C++ rebuild and process restart, run **in-game** as a GM:

```
#reloadrulesworld
```

This propagates the rule reload to every running zone process. Confirmed by
config-expert in v1 verification against `command_settings` and
`zone/gm_commands/rules.cpp`. The local-only variants (`#reloadallrules`)
are insufficient for an 8-zone deployment.

The `#reloadrulesworld` is run twice in the v2 deployment:
1. After Task A (rate UPDATE), before the rebuild — applies the rate change live.
2. After Task D (XPSharePct UPDATE), after the restart — applies parity activation.

---

## v2 Implementation Sequence

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| A | Apply XP rate UPDATE: pre-check SELECT, UPDATE `Character:ExpMultiplier` to `'2.0'` (ruleset_id=1), post-check SELECT, then `#reloadrulesworld` in-game; capture before/after output. | config-expert | — | ~5 min |
| B | C++ refactor: implement mirror-pipeline approach across exp.h (expose `GetConLevelModifierPercent`), companion.h, companion.cpp, exp.cpp:1196-1218, attack.cpp:2791-2810, lua_companion.cpp, ruletypes.h. Build clean. AA-seam comment included. | c-expert | A (independent but conventionally first) | ~2-4 hours dev + build |
| C | Restart server stack: rebuild eqemu, then loginserver → world → 8 dynamic zone processes per `MEMORY.md` startup order. Verify all 8 zones come up clean and connect to world. | infra-expert | B | ~10-15 min |
| D | Apply companion XPSharePct UPDATE: pre-check SELECT (expect `'50'`), UPDATE to `'100'`, post-check SELECT, then `#reloadrulesworld` in-game; capture before/after output. | config-expert | C | ~5 min |
| E | Validate against PRD's 15 numbered cases — kill XP rate, AA rate, parity in 1+1 through 1+4, flat quest XP, percentage XP control, regression checks. Pass to user for in-game testing. | game-tester | D | ~30-60 min |

### Task A — Detailed brief for config-expert (rate UPDATE)
- Same brief as v1, sequenced first in v2.
- Confirms rate change is live before the rebuild starts.
- Hand-off to c-expert on completion.

### Task B — Detailed brief for c-expert (C++ refactor)
- Implement the seven file changes listed under "Code changes / C++ changes" above (exp.h, attack.cpp:2791-2810, companion.h, companion.cpp, exp.cpp:1196-1218, lua_companion.cpp, ruletypes.h).
- Apply the mirror-pipeline approach exactly as ratified in `agent-conversations.md` (2026-04-27 architect/c-expert exchange).
- **TWO companion XP dispatch sites must be patched**: `exp.cpp:1196-1218` (group split) AND `attack.cpp:2791-2810` (solo-kill path). Both currently apply the `xp_share_pct/100` clamp inline; both must change to pass raw XP + conlevel to `AddExperience` (which now owns the post-multiplier scaling). This is the second-round finding — easy to miss if only `exp.cpp` is patched.
- **`XPSharePct` post-multiplier scalar MUST be applied inside `Companion::AddExperience`** (right after `CalculateExp` returns), NOT inside the `Group::SplitExp` dispatch. Single application site ensures quest::exp / Lua paths receive the same scaling.
- **`GetConLevelModifierPercent` exposure via `exp.h`** — verified by c-expert as already a file-scope `static` in `exp.cpp:218`, NOT a Client method. Add the declaration to `exp.h` so `companion.cpp` can call the same single source of truth. No `mob.h`/`mob.cpp` changes.
- **AA-seam code comment** placed on `Companion::CalculateExp` per spec above.
- Build: `docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"`. Resolve any compilation errors before handing off.
- Hand off to infra-expert on clean build.

### Task C — Detailed brief for infra-expert (rebuild + restart)
- Server processes inside the container do NOT auto-start after `make restart`. Use the documented startup order from `MEMORY.md`:
  1. `shared_memory` (run to completion — one-shot loader, not persistent).
  2. `loginserver` (wait 3s).
  3. `world` (wait 8s for DB load).
  4. Start 8 zone processes: `dynamic_01` through `dynamic_08`, FROM `/home/eqemu/server/`.
- Verify with `ps aux | grep 'zone dynamic' | grep -v grep | wc -l` (expect 8).
- Tail world.log and one zone log; confirm clean startup with no exceptions in companion or exp paths.
- Hand off to config-expert on confirmed healthy stack.

### Task D — Detailed brief for config-expert (XPSharePct UPDATE)
- **Pre-Task verification ask**: confirm post-rebuild stack is healthy and running the new binary before applying the rule UPDATE. A quick `ps` check + log tail suffices.
- Run pre-check SELECT (expect `'50'`), UPDATE to `'100'`, post-check SELECT.
- `#reloadrulesworld` in-game.
- Capture before/after output for the PR notes.
- Hand off to game-tester.

### Task E — Detailed brief for game-tester
- See "v2 Validation Plan" section below for the 15-case map.

---

## v2 Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| `Companion::CalculateExp` mismatched against `Client::CalculateExp` (e.g. forgot to apply ZEM, hotzone) | Medium | High | game-tester cases 3-6 and 7-9 will catch any divergence in per-share parity. Cases 14 (group bonus) and the implicit hotzone bonus check provide additional coverage. |
| `XPSharePct` post-multiplier applied in wrong place (e.g. inside `Group::SplitExp` instead of `Companion::AddExperience`) | Low | Medium | Architecture doc explicitly mandates inside-AddExperience. Code review by architect at PR stage. |
| `GetConLevelModifierPercent` exposure via exp.h breaks existing callers | Very Low | Low | The function stays in place at `exp.cpp:218`; only its declaration is added to `exp.h`. Existing in-file callers continue to compile. Player kill XP cases (1-2) verify Client path is intact. |
| Second dispatch site at `attack.cpp:2791-2810` missed | Low | High | c-expert second-round trace flagged this site explicitly. PR review checklist must verify both `exp.cpp:1197` and `attack.cpp:2794` are updated. game-tester case 3 (solo+1 companion) exercises the attack.cpp path because solo kills outside groups route through it. |
| Companion XP overflow on high-multiplier zones | Very Low | Low | `m_companion_xp` is uint32; same overflow risk as player `m_pp.exp`; not a new failure mode. |
| Mid-restart partial state (some zones running new binary, others old) | Low | Medium | infra-expert validates all 8 zones running after Task C. If any zone fails to start, abort to Task D until resolved. |
| Operator who deliberately set `XPSharePct < 100` (sub-parity intent) — semantic change | Low | Low | Documented in this doc's "Considered and rejected alternatives" section. Operators with sub-parity intent now apply post-multiplier scaling instead of pre-multiplier; effect direction is the same (companion gets less than parity), magnitudes differ. Acceptable since the rule was 100% custom (no stock EQEmu inheritance). |
| Operator forgot Task D `#reloadrulesworld` after restart | Low | Low | game-tester case 3 (1+1 parity) catches this on first verification. Self-correcting if validation runs. |

### Compatibility Risks

**Pet/swarm pet/charm pet/merc XP — UNCHANGED.** c-expert confirmed
none of these flow through `Companion::AddExperience` or `Group::SplitExp`'s
companion dispatch. Their paths are independent.

**Raid XP path — known limitation, not in scope.** `Raid::SplitExp`
does not currently dispatch to companions. Companions in raid groups
gain zero XP today and continue to gain zero XP after this feature.
If raid+companion play becomes a use case, that is a follow-up feature,
not a rollback trigger.

**Lua scripts that read `companion:GetExp()` or assume sub-parity ratios.**
PRD explicitly says quest scripts are untouched. Any consumer reading
companion XP values will see different numbers post-feature, but per the
PRD this is intended behavior, not a regression. Flagged as a downstream
concern if any custom server-specific Lua relies on the old ratios — none
identified by c-expert in the current codebase.

**Quest reward grants (`quest::exp(N)` / `:AddEXP(N)`).** Players still
receive `N * 2.0` after the rate change (down from `N * 3.0`), as
documented in v1 architecture doc. Companions in group now receive their
per-share fraction of `quest::exp(N)` at parity. This is the PRD's
intent.

### Performance Risks

None. The new `Companion::CalculateExp` runs once per XP grant per companion.
Same scalar arithmetic as `Client::CalculateExp`, no new DB queries, no
extra allocations.

### Rollback Plan

The v2 implementation is designed for a clean revert.

**Code rollback (full v2 refactor revert):**
- All C++ changes ship under a single feature commit (or a tightly-scoped
  series of commits) on `feature/xp-retune`.
- `git revert <commit-sha>` on the feature branch backs out the entire
  refactor.
- Rebuild + restart cycle.
- The architecture doc identifies the exact commit boundary in the PR
  description for clean revert visibility.

**Rate-only rollback (Task A revert):**
- `UPDATE peq.rule_values SET rule_value = '3.0' WHERE ruleset_id = 1 AND rule_name = 'Character:ExpMultiplier';`
- `#reloadrulesworld`.

**XPSharePct-only rollback (Task D revert, leaving C++ refactor in place):**
- `UPDATE peq.rule_values SET rule_value = '50' WHERE ruleset_id = 1 AND rule_name = 'Companions:XPSharePct';`
- `#reloadrulesworld`.
- Companion now gets 50% of parity (post-multiplier). Useful as a
  fine-tuning option if parity ends up being too generous for the user's
  taste.

**Combined rollback (everything back to pre-v2):**
- Revert C++ commits AND revert both rule_values UPDATEs.
- Rebuild + restart.

The rate change and the parity refactor are independent in the rollback
sense: each can be reverted without affecting the other (with the caveat
that reverting just the C++ refactor leaves `XPSharePct = 100` applying
as a pre-multiplier of the un-multiplied slice, which produces the v1
ceiling behavior — fine for a brief period, fix with the XPSharePct
rollback above).

---

## v2 Review Passes

### Pass 1: Feasibility

**Yes — fully feasible.** c-expert traced all the multiplier inputs in
`Client::CalculateExp` and confirmed each is accessible to a `Companion`:

- `RuleR(Character, ExpMultiplier)` and `RuleR(Character, FinalExpMultiplier)` — global rules, no `this`-state.
- `zone->newzone_data.zone_exp_multiplier` (ZEM) — global zone state, accessible.
- `zone->IsHotzone()` and `RuleR(Zone, HotZoneBonus)` — global zone state + rule.
- `RuleB(Zone, LevelBasedEXPMods)` and the level_exp_mods table — global.
- `GetConLevelModifierPercent(conlevel)` — c-expert second-round trace
  confirmed this is **already a file-scope `static` in `exp.cpp:218`**,
  not a `Client::` method as initially assumed. Exposing the declaration
  via `exp.h` is a one-line change; no class refactor needed.

The exclusions are equally clean:
- AA split (`add_aaxp`) — companions don't have AAs in this feature; the
  out-parameter shape is reserved for the future companion-AA seam.
- `UseRaceClassExpBonuses` — companion-irrelevant.
- `CalculateLeadershipExp` — companion-irrelevant.

**No protocol-agent involvement needed.** XP updates use `OP_ExpUpdate` /
`ExpUpdate_Struct` carrying a 0-330 progress ratio. Struct, opcode, and
wire format are unchanged. Companions have their own internal XP state,
not exposed via packets to the player client.

Hardest part: ensuring c-expert finds and patches BOTH companion XP
dispatch sites — `exp.cpp:1197` (group split) AND `attack.cpp:2794`
(solo-kill path). Validation cases 1-3 collectively exercise both paths.

### Pass 2: Simplicity

**Yes, this is the simplest approach that satisfies the PRD.**

- Three considered alternatives (polymorphic Client, pre-compute in
  SplitExp, cap-removal-only) each have specific failures (architectural
  mess, fails quest::exp parity, leaves surprising rule semantics).
- The chosen approach changes 7 files (mostly small surgical changes plus
  one new method that mirrors an existing one) and 2 rule_values rows.
- No new tables, no new opcodes, no schema migrations, no new rules
  (existing `Companions:XPSharePct` is repurposed in place).
- Code duplication concern: `Companion::CalculateExp` will share ~50 lines
  of multiplier logic with `Client::CalculateExp`. Acceptable because
  (a) the two paths have different exclusions, (b) bot/merc/companion
  already duplicate similar concerns elsewhere in the codebase, (c)
  over-abstraction would couple two systems whose evolution may diverge
  (e.g., the future companion-AA feature will modify only the companion
  side).

Nothing to remove or defer. The AA-seam is a documentation + structural
constraint, not added code surface.

### Pass 3: Antagonistic — what could go wrong

**Steel-manned the design against:**

- **Companion levels above max-companion-level** — the multiplied XP could
  push companions to overrun their cap. `CheckForLevelUp` already enforces
  the companion max level (verified by c-expert as existing behavior, no
  change). XP overflow into a level-locked companion just accumulates as
  banked XP at the cap; same behavior as a banked-cap player. **Mitigated.**

- **Companion XP overflow at uint32 max** — same risk as player
  `m_pp.exp` (which is also uint32 in some paths). Not a new failure
  mode; not a v2-specific concern. **Pre-existing, not in scope.**

- **Companion in a raid (not a group)** — `Raid::SplitExp` doesn't
  currently dispatch to companions. Companion gets zero raid XP today and
  continues to get zero raid XP after this feature. **Documented as known
  limitation, explicitly out of scope.**

- **`Companions:XPContribute` interaction** — this rule controls whether
  companion presence in a group affects member_count. Not changing
  semantics. If `XPContribute = false`, companion is excluded from
  `member_count` (player gets a full group share, companion in this
  refactor still gets parity to that full share via `CalculateExp`). The
  interaction is consistent with the PRD's intent ("companion gets the
  same per-share that the player gets"). **No change needed.**

- **Operator who set `XPSharePct < 100` deliberately** — pre-feature, this
  meant "companion gets X% of un-multiplied slice." Post-feature, it
  means "companion gets X% of multiplied parity-share." Sub-parity intent
  is preserved (still less than parity), but the magnitude differs. Since
  config-expert confirmed `XPSharePct` is 100% custom (no stock EQEmu
  inheritance), no operator outside this server is affected. **Documented
  in compatibility risks.**

- **Operator forgot to apply Task D after restart** — companion XP would
  scale by the existing `XPSharePct = 50` value, putting companions at 50%
  of parity. game-tester case 3 catches this on first verification.
  **Self-correcting.**

- **Mid-restart partial state** — already addressed in technical risks.
  infra-expert verifies all 8 zones running before Task D fires. If any
  zone fails, abort to Task D until resolved.

- **Quest scripts reading companion XP values directly** — PRD says quest
  scripts are untouched. If any custom Lua/Perl in this server relies on
  the old sub-parity ratios, it would see different numbers. None
  identified by c-expert. **Flagged for game-tester sanity check during
  case 9 (flat task reward).**

- **Player exploit during the deployment window** — change is a slowdown
  (rate) plus a parity bump (companion). No exploit windows worth gaming.
  Player can't "race" against the rule reload meaningfully.

- **Server crash mid-Task** — Task A is single-statement atomic. Task B
  is a code change behind a clean rebuild gate. Task C is a process
  restart with explicit ordering. Task D is single-statement atomic. No
  partial states across tasks possible.

- **Rollback** — symmetric: each Task has a documented inverse. C++
  refactor is a single revert. Rules are single UPDATEs.

### Pass 4: Integration

**Task ordering is linear and dependency-clean:**

```
A (config: rate UPDATE)
  ↓
B (c-expert: C++ refactor + ruletypes.h default)
  ↓
C (infra: rebuild + restart all 8 zones)
  ↓
D (config: XPSharePct UPDATE + reload)
  ↓
E (game-tester: 15-case validation)
```

- No circular dependencies.
- Task A is a no-build pure rule change; can theoretically run before or
  in parallel with Task B's dev work, but sequencing-first is cleaner for
  the deployment narrative.
- Task C explicitly depends on a clean B build; aborts on build failure.
- Task D explicitly depends on C's verified-healthy stack; aborts if zones
  show errors.
- Task E aggregates all 15 PRD validation cases; depends on everything
  upstream being green.

Hand-off artifacts at each boundary:
- A→B: captured pre/post SELECT output from Task A.
- B→C: clean build log, summary of files modified.
- C→D: ps output showing 8 zones, world.log clean.
- D→E: captured pre/post SELECT output from Task D, world.log reload line.
- E→user: validation report mapping each PRD case to PASS/FAIL.

---

## v2 Validation Plan — mapped to PRD's 15 cases

The PRD specifies 15 numbered validation cases. game-tester verifies each:

### Player kill-XP rate (PRD cases 1-2)

| PRD # | Case | Expected | Maps to |
|-------|------|----------|---------|
| 1 | Solo player, single kill of a known mob | Player XP gain ≈ 0.667x of pre-change amount | Task A effect |
| 2 | Solo player, kill with full hotzone bonus | Hotzone bonus applies; total scales correctly off new 2.0x base | Task A effect, hotzone integration |

### Companion XP parity (PRD cases 3-6)

| PRD # | Case | Expected | Maps to |
|-------|------|----------|---------|
| 3 | 1 player + 1 companion, single kill | Companion XP per-share equals player XP per-share | Tasks B + D effect |
| 4 | 1 player + 2 companions, single kill | All three earn equal per-share XP | Tasks B + D effect |
| 5 | 1 player + 3 companions, single kill | All four earn equal per-share XP | Tasks B + D effect |
| 6 | 1 player + 4 companions, single kill | All five earn equal per-share XP | Tasks B + D effect |

### Flat-XP event types reach companions at parity (PRD cases 7-9)

| PRD # | Case | Expected | Maps to |
|-------|------|----------|---------|
| 7 | `quest::exp(N)` granted to player while companion in group | Companion gains the same flat amount the player gains | Tasks B + D — companion path through CalculateExp via questmgr or signal-driven AddExperience |
| 8 | Lua `:AddEXP(N)` on a companion-eligible target | Companion gains parity amount | Task B `Lua_Companion::AddExperience` binding update + CalculateExp routing |
| 9 | Flat (non-percentage) task reward XP, player turn-in | Companion in group receives parity share | Tasks B + D — task reward funnels through standard XP path |

### Untouched paths — must NOT change (PRD cases 10-15)

| PRD # | Case | Expected | Maps to |
|-------|------|----------|---------|
| 10 | `quest::addlevelbasedexp()` percentage grant | Player XP unchanged; this path was not in scope | Negative control — `AddLevelBasedExp` does not apply `Character:ExpMultiplier` |
| 11 | Percentage-typed task reward XP | Unchanged | Same — `AddLevelBasedExp` path |
| 12 | AA point gain at max level | Unchanged (AA multiplier still 3.0x) | `Character:AAExpMultiplier` untouched |
| 13 | Death XP loss on level-locked character | Still 1.5%/death | Death rule untouched |
| 14 | Group XP bonus for player-only group of 2 | Bonus still applies, scales off new 2.0x base | Group bonus is pre-split, unchanged |
| 15 | Pet/swarm pet behavior on kills | Unchanged | These never call `Companion::AddExperience` — c-expert verified |

### Server-side health (cross-cutting)

- [ ] `world.log` clean after both `#reloadrulesworld` invocations (rate reload AND parity reload).
- [ ] All 8 zone logs show no exceptions in the refactored XP path.
- [ ] Zone process startup timestamps reflect the Task C restart only — no unexpected zone restarts mid-session.

### Server-side acceptance criteria (architect-level, before user testing)

- [ ] `rule_values` row for `Character:ExpMultiplier`, ruleset_id=1 reads `'2.0'`.
- [ ] `rule_values` row for `Character:AAExpMultiplier`, ruleset_id=1 reads `'3.0'` (guard).
- [ ] `rule_values` row for `Companions:XPSharePct`, ruleset_id=1 reads `'100'`.
- [ ] `Companion::CalculateExp` exists and is called by `Companion::AddExperience`.
- [ ] AA-seam comment present in `companion.cpp`.
- [ ] No companion AA point accrual observed (no `add_aaxp` flow on companion path).
- [ ] All 15 PRD cases pass per the table above.

---

## v2 Required Implementation Agents

| Agent | Tasks | Rationale |
|-------|------:|-----------|
| `config-expert` | A, D | Owns `rule_values` audits and tunings; both UPDATEs are scoped, verified queries with rollback. |
| `c-expert` | B | Owns C++ refactor across 7 files; mirror-pipeline approach ratified with architect. |
| `infra-expert` | C | Owns container/process lifecycle; full-stack restart with documented startup order. |
| `game-tester` | E | Owns server-side validation against the 15-case PRD map. |

**Do NOT spawn**: `lua-expert`, `perl-expert`, `data-expert`, `protocol-agent`. None have work in v2.
- `lua-expert`: Lua binding update is in C++ (`lua_companion.cpp`), c-expert handles.
- `perl-expert`: no Perl involved.
- `data-expert`: no schema changes; rule_values UPDATEs are config-expert's domain.
- `protocol-agent`: no opcode, struct, or wire-format changes (verified — `OP_ExpUpdate` carries only 0-330 ratio).

---

## v1 Plan (Superseded)

> **Note:** This section preserves the v1 architecture plan for revert
> reference. v1 covered ONLY the rate change. v2 supersedes it by
> bundling the rate change with the companion XP parity refactor under
> the same feature branch.

### v1 Executive Summary

Lower the kill-XP multiplier from 3.0x to 2.0x while leaving the AA-XP
multiplier at 3.0x. Implementation is a **single-row UPDATE on the
`peq.rule_values` table** (ruleset_id = 1, rule_name = `Character:ExpMultiplier`),
applied live via the `#reloadrulesworld` GM command. No code, no rebuild, no
restart, no protocol changes. One implementation task owned by config-expert.

### v1 Existing System Analysis (Preserved)

The server reads server-wide tunables from the `rule_values` table at
boot and caches them in the `RuleManager` singleton (`common/rulesys.h` /
`common/ruletypes.h`). Each zone process loads the active ruleset
(`zone.ruleset` column, default = ruleset_id = 1) and exposes individual
values via macros: `RuleI`, `RuleR`, `RuleB`, `RuleS`.

`Character:ExpMultiplier` is consumed inside `Client::CalculateExp()`
(`zone/exp.cpp:428`), which is invoked by `Client::AddEXP()` (`exp.cpp:510`).
**`AddEXP()` is the single funnel for ALL flat-XP grants** — kill XP (via
`Group::SplitExp` / `Raid::SplitExp`), `quest::exp()` Perl grants, Lua
`:AddEXP()` calls, and flat task-reward XP. Every one of those paths
gets multiplied by `Character:ExpMultiplier`.

**One exception**: `Client::AddLevelBasedExp()` (`exp.cpp:1091`) is a
parallel XP path used by percentage-based rewards. It does **not** apply
`Character:ExpMultiplier`. Percentage-based grants are unaffected by this
retune.

### v1 Approach

Pure **rule-value tuning**. Single-row UPDATE on `peq.rule_values`
(`ruleset_id=1`, `rule_name='Character:ExpMultiplier'`,
`rule_value '3.0' → '2.0'`), applied live via `#reloadrulesworld`.

### v1 Task

| # | Task | Agent | Depends On | Estimated Scope |
|---|------|-------|------------|-----------------|
| 1 | Apply XP retune: pre-check SELECT, UPDATE, post-check SELECT, then `#reloadrulesworld` in-game; capture before/after output. | config-expert | — | ~5 min |

### v1 Validation Plan

(Superseded by v2 Validation Plan above — v2 plan absorbs all v1 cases as PRD cases 1-2 and 10-15, plus adds cases 3-9 for companion parity.)

---

> **Next step (v2):** User reviews this architecture-v2 plan. On approval,
> spawn the implementation team with `c-expert`, `config-expert`,
> `infra-expert` (game-tester comes solo in Phase 5). Task A is the natural
> first task; the rest follow the documented dependency chain.
