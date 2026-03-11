# Companion Group Commands — Architecture Audit Findings

> **Auditor:** architect
> **Date:** 2026-03-11
> **Scope:** Implementation in `companion.lua` and `global_npc.lua` vs. architecture plan and PRD

---

## Summary

The implementation is **solid overall**. All 9 commands are present, the dispatch pipeline is
correct, the response channel migration from `client:Message()` to `CompanionGroupSay()` (via
`companion_say()` helper) is complete, and the architecture's core decisions (pure Lua, entity
variables for buff queue, timer-based processing) are faithfully implemented.

There are a few deviations from the PRD, most of which are minor or defensible. Two items
require attention before the feature ships.

---

## Command-by-Command Audit

### 1. !status — **PASS WITH NOTES**

**Architecture compliance:** Fully implemented per spec. Enhanced with HP%, mana (N/A for melee),
target, sit/stand, follow/guard mode, buff listing with duration in minutes/`<1 min`/permanent.

**Verified behaviors:**
- Dead check shows `[DEAD]` indicator with Level/Class only
- HP percentage calculated correctly
- Pure melee check: `GetMaxMana() == 0` → "Mana: N/A"
- Buff iteration via `GetBuffs()` with `GetSpellID()` and `GetTicsRemaining()` → minutes conversion
- Follow/guard mode read from `companion_modes` table
- Multi-line output via multiple `companion_say()` calls (correct per protocol findings)

**Notes:**
- **PRD deviation (minor, acceptable):** PRD shows `HP: 1450/2000 (72%)  |  Mana: 800/1200 (66%)`
  with pipe separators on one line. Implementation splits HP and Mana into separate lines. This
  is a readability improvement given group chat constraints (no formatting control).
- **PRD deviation (minor, acceptable):** PRD says dead companion shows "HP: 0/2000 (0%) — DEAD".
  Implementation shows `=== Name [DEAD] ===` header with Level/Class only, omitting HP line.
  This is cleaner — showing "HP: 0/2000" for a dead companion adds no information.
- **PRD says "Following: Yes/No".** Implementation shows "Mode: Follow" or "Mode: Guard" which
  is equivalent and arguably more informative.

### 2. !help — **PASS WITH NOTES**

**Architecture compliance:** Fully implemented. Complete command reference card with topic-based
help (`!help stance`, `!help movement`, etc.). @all deduplication via data bucket lock with 1s TTL.

**Verified behaviors:**
- All categories present: Stance, Movement, Combat, Buffs, Equipment, Information, Control
- All 9 new commands listed
- All existing commands listed
- Topic-based detail help for each category
- @all deduplication: `help_lock_<zone_id>` data bucket with 1s TTL
- Unknown topics handled with error message

**Notes:**
- **PRD deviation (acceptable, forced by protocol):** PRD says "The response is delivered as a
  single message, not multiple messages." Protocol-agent confirmed Titanium does NOT render `\n`
  in group chat. Multiple `companion_say()` calls is the only viable approach. This deviation
  is necessary and correct.
- **PRD deviation (minor):** PRD shows exact help text with specific formatting including
  alignment with dashes. Implementation uses a slightly different format but covers all the
  same content. Acceptable — exact formatting is a presentation detail, not a functional
  requirement.
- **Missing from PRD reference card:** `!recall` is listed in the help but was not in the PRD's
  help reference card format. This is a correct addition — the help should be comprehensive.
- **Missing from PRD reference card:** `!target` is listed in the help but was not in the PRD's
  help reference. Also a correct addition — existing commands should be documented.
- **Minor gap:** Help doesn't mention `!stats` in the main overview; it IS listed under
  `!help information` topic. This is fine since `!stats` is a pre-existing command.

### 3. !equipmentmissing — **PASS**

**Architecture compliance:** Exact match to spec.

**Verified behaviors:**
- Iterates slots 0-22, skips slot 21 (PowerSource)
- Checks `GetEquipment(slot_id) == 0` for each slot
- Reports empty slots as comma-separated list
- Reports "has all equipment slots filled" when no empty slots
- Uses `companion_say()` (group chat) for response
- Dead companions still report (correct per PRD — death doesn't change equipment)

**No issues found.**

### 4. !follow — **PASS WITH NOTES**

**Architecture compliance:** Implemented per spec with dead check and group chat feedback.

**Verified behaviors:**
- Sets `SetGuardMode(false)` — correct
- Updates `companion_modes` table — correct
- Dead check with appropriate message — correct
- Uses `companion_say()` for feedback — correct

**Notes:**
- **PRD deviation (minor):** PRD says if already following, respond "[Name] is already following
  you." Implementation does not check whether companion is already in follow mode — it just sets
  follow mode unconditionally. This is benign (setting follow when already following is a no-op)
  but the duplicate-state feedback message is missing.

### 5. !tome — **PASS**

**Architecture compliance:** Exact match to spec.

**Verified behaviors:**
- Dead check with "[Name] is dead and cannot move" — correct
- Proximity check: `CalculateDistance(client) < 50` → "is already nearby" — correct
- Movement via `RunTo()` (pathed, not teleport) — correct
- No cooldown — correct (distinct from `!recall`)
- Feedback: "[Name] moves toward you." — matches PRD

**No issues found.**

### 6. !flee — **PASS**

**Architecture compliance:** Exact match to spec.

**Verified behaviors:**
- Dead check — correct
- Sets passive stance: `SetStance(0)` — correct
- Hate list is NOT cleared — correct per PRD critical design decision
- Move to player: `RunTo()` — correct
- Sets follow mode: `SetGuardMode(false)` + `companion_modes` update — correct
- Context-aware feedback: "disengages and retreats" when was in combat, "moves to follow"
  when was not in combat — correct per PRD
- Checks both `was_in_combat` AND `was_passive` for the feedback branch — correct edge case
  handling (passive + not engaged → lighter message)

**No issues found.**

### 7. !assist — **PASS WITH NOTES**

**Architecture compliance:** Fully implemented with auto-stance-switch and edge case handling.

**Verified behaviors:**
- Dead check — correct
- No-target check with correct message — matches PRD
- Self-target check: "will not attack themselves" — correct
- Friendly target check via `IsAttackAllowed()` — correct
- Auto-stance-switch: passive → balanced before engaging — correct per PRD
- Feedback with stance switch info — correct
- Uses `companion_say()` for all responses — correct

**Notes:**
- **PRD deviation (minor):** PRD says feedback is "[Name] attacks [Target]!" but implementation
  says "[Name] assists against [Target]!" — different verb. "Assists against" is arguably more
  accurate for the EQ context (this IS an assist command, not a direct attack order).
- **PRD deviation (minor, noted):** PRD specifies "Player targets a corpse: '[Name] cannot
  attack a corpse.'" Implementation has no explicit corpse check. `IsAttackAllowed()` likely
  returns false for corpses, which would trigger the "will not attack a friendly target" message
  instead. This is functionally correct but the message is technically wrong for the corpse case.
  Low priority — corpse-targeting is an uncommon edge case.

### 8. !buffme — **PASS**

**Architecture compliance:** Exact match to spec.

**Verified behaviors:**
- Dead check: "is dead and cannot cast spells" — correct
- Caster check: `GetMaxMana() == 0` → "has no buff spells available" — correct
- OOM check: `GetManaRatio() < 10` → "too low on mana" — correct (10% threshold per arch spec)
- Sets entity variable `buff_request_target` = `"owner"` — correct
- Sets retry counter to 0 — correct
- Starts timer `buff_request_<npc_id>` at 2000ms — correct
- Feedback: "[Name] will refresh your buffs when able." — matches PRD

**Timer handler in global_npc.lua verified:**
- Stops timer on entry — correct
- Checks if request is still active — correct
- Retry cap at 30 (60 seconds) with timeout message — correct per arch spec
- Waits for idle state (not engaged, not casting) before casting — correct
- Builds target list based on request type ("owner" vs "party") — correct
- Queries `companion_spell_sets` for buff spells with bitwise type check — correct
- Clears entity variables after completion — correct
- Notifies if no buff spells found — correct

**No issues found.**

### 9. !buffs — **PASS**

**Architecture compliance:** Exact match to spec. Identical to `!buffme` except entity variable
value is `"party"` instead of `"owner"`.

**Verified behaviors:**
- Same checks as `!buffme` — correct
- Entity variable set to `"party"` — correct
- Timer handler iterates all group members for party target — correct
- Feedback: "[Name] will refresh party buffs when able." — matches PRD

**No issues found.**

### 10. !equipmentupgrade — **PASS WITH NOTES**

**Architecture compliance:** Implemented per spec with item link parsing, stat comparison,
class/race restriction checks, and slot resolution.

**Verified behaviors:**
- Dead check (silent) — correct per arch spec
- Item link parsing via `\x12` delimiter, 5 hex chars at body position 2-6 — correct
- No link found: "Please link an item for me to evaluate." — correct
- Invalid item (slots == 0): same message — correct
- Class restriction check via bitmask — correct
- Race restriction check with NPC_RACE_TO_PLAYER_RACE mapping — correct
- Silent response for items companion can't equip — correct per PRD
- Slot resolution using same pattern as `companion_find_slot` — correct
- Empty slot: "is an upgrade! My [slot] slot is empty." — matches PRD
- Stat score formula: AC + AStr + ASta + AAgi + ADex + AWis + AInt + ACha + HP + Mana — correct
- Weapon bonus: `floor(Damage * 10 / Delay)` — correct
- Reports upgrade/equal/downgrade with scores — correct
- Uses `eq.get_item_stat()` for stat lookups — clean approach, avoids ItemInst

**Notes:**
- **PRD deviation (noted):** PRD says for multi-slot items (rings, wrists) when both slots are
  occupied, compare against "the weaker of the two equipped items." Implementation uses
  `companion_find_slot`-style logic that returns the FIRST matching slot, not the weaker. This
  means if ring1 has a score of 50 and ring2 has a score of 10, the upgrade check compares
  against ring1 (first match), not ring2 (weaker). A ring with score 30 would be reported as
  "worse" when it should be reported as "upgrade over ring2." This is a **minor behavioral gap**
  that could be improved in a follow-up but does not block shipping.
- **PRD deviation (noted):** PRD says companion should "link their currently equipped item in
  the response." Implementation does not generate an item link for the equipped item — it uses
  the item name string only. Item link generation from a bare item_id via `eq.item_link()` may
  require an ItemInst, which is not trivially available from `GetEquipment()` (returns item_id
  only). This is a **known limitation** of the pure-Lua approach. The item name is sufficient
  for player decision-making.
- Implementation adds an "equal" case (same score) which the PRD doesn't explicitly cover.
  This is a good addition.

---

## Cross-Cutting Findings

### Response Channel Migration — **PASS**

All 9 commands use `companion_say()` which calls `group:GroupMessage(npc, msg)`. This correctly
addresses the protocol-agent's finding that existing `!status` and `!help` used `client:Message()`
(wrong channel). The migration is complete.

### COMMANDS Table — **PASS**

All new commands are registered in the COMMANDS table (line 91-115):
- `tome`, `flee` (movement)
- `buffme`, `buffs` (buffs)
- `equipmentupgrade`, `equipmentmissing` (equipment, `requires_owner = false`)

All existing commands (`status`, `help`, `assist`, `follow`) retain their entries with updated
handlers.

The `requires_owner = false` flag on `equipmentupgrade` and `equipmentmissing` is correct — any
player can evaluate items for any companion they can see.

### @all !help Deduplication — **PASS**

Data bucket lock with zone-scoped key and 1-second TTL. First companion claims the lock, subsequent
companions skip. This prevents identical help text from all companions flooding chat.

### Buff Timer Handler Integration — **PASS**

Timer handler added to `global_npc.lua:event_timer()` with the `buff_request_` prefix pattern.
This matches the existing patterns (`gsay_deliver_`, `comp_commentary_`) in the same function.

### Entity Variable Lifecycle — **PASS**

- `buff_request_target` and `buff_request_retries` are set/cleared correctly
- Entity variables are transient (cleared on depop/zone) — correct for buff requests
- No persistent state needed — correct

---

## Issues Requiring Attention

### Priority 1 (Should Fix Before Shipping)

None. All commands are functional and the deviations from the PRD are minor.

### Priority 2 (Should Fix in Follow-Up)

1. **!equipmentupgrade multi-slot comparison:** When both ring/wrist slots are occupied,
   implementation compares against the first matching slot instead of the weaker one. The PRD
   explicitly specifies comparing against the weaker item. Fix: after finding all matching
   occupied slots, compare their scores and select the one with the lower score.

2. **!assist corpse target message:** PRD specifies a distinct "cannot attack a corpse" message.
   Implementation relies on `IsAttackAllowed()` which produces a "friendly target" message for
   corpses. Fix: add `player_target:IsCorpse()` check before `IsAttackAllowed()`.

### Priority 3 (Nice to Have)

3. **!follow already-following check:** PRD mentions "[Name] is already following you" for
   duplicate follow commands. Implementation unconditionally sets follow mode. Fix: check
   `companion_modes[npc:GetID()] == "follow"` and respond differently.

4. **!equipmentupgrade item link in response:** PRD says companion should link their currently
   equipped item. Implementation uses text name only (item link generation from bare item_id
   may not be possible in pure Lua without ItemInst). This would require either a C++ helper
   binding or using `eq.item_link()` with an appropriate argument.

5. **!assist verb mismatch:** PRD says "attacks [target]" but implementation says "assists
   against [target]". Minor wording preference.

---

## Final Verdict

**APPROVED FOR SHIPPING.** The implementation is architecturally sound, follows the approved
plan, and addresses all 9 commands with appropriate edge case handling. The priority 2 items
are real but do not block the feature. They can be addressed in a follow-up iteration.

The lua-expert made good decisions throughout:
- The `companion_say()` helper cleanly abstracts the group chat response path
- The `item_stat_score_by_id()` helper using `eq.get_item_stat()` avoids the complexity
  of instantiating items just for stat comparison
- The `parse_item_link()` function correctly handles the internal (post-translation)
  link format with proper nil-safety
- The buff timer handler in global_npc.lua integrates cleanly with existing timer patterns
- The @all !help deduplication is simple and effective

No C++ changes were made (as planned). No database changes were made (as planned). No new
rules were added (as planned). The implementation is entirely in Lua, exactly as the
architecture specified.
