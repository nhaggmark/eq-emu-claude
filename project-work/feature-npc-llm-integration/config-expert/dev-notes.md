# NPC LLM Integration — Dev Notes: config-expert

> **Feature branch:** `feature/npc-llm-integration`
> **Agent:** config-expert
> **Task:** #2 — Assess server rules and config for LLM integration
> **Date started:** 2026-02-23
> **Current stage:** Socialize

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 2 | Assess server rules and config for LLM integration | None | Complete |

---

## Stage 1: Plan

### Files Examined

| File | What You Found |
|------|----------------|
| `akk-stack/server/eqemu_config.json` | Server DB connection, hot reload enabled, no sidecar section |
| `eqemu/common/ruletypes.h` (lines 681, 753-763, 930-932) | Range:Say default=15 (overridden in DB), Chat rules, NPC:SayPauseTimeInSec |
| `eqemu/common/data_bucket.cpp` (lines 158-165) | eq.get_data() uses simple string key, no auto NPC scoping |
| `eqemu/zone/lua_general.cpp` (lines 936-953, 6076-6079) | eq.get_data/set_data confirmed available |
| `akk-stack/server/quests/global/global_npc.lua` | Only has event_spawn (Halloween costume logic) — no event_say |
| `akk-stack/server/quests/abysmal/Brevik_Kalaner.lua` | Real-world data bucket usage: `e.other:GetBucket("key")` |
| `rule_values` DB query results | Chat, NPC, Range rules — see Stage 2 findings |

### Key Findings (initial)

- No LLM rules exist anywhere in the codebase
- global_npc.lua has no event_say handler — clean insertion point
- eq.get_data() is available and uses simple string keys
- Quest hot reload is enabled — Lua changes take effect without server restart

---

## Stage 2: Research

### 2.1 Chat:AutoInjectSaylinksToSay

**Current value:** `true`
**Default in ruletypes.h:** `true`
**Effect:** Wraps `[bracketed text]` in NPC `Say()` output with clickable saylinks.

**LLM implication:** The LLM response pipeline must NOT produce bracketed text in
Phase 1 responses. The PRD already prohibits quest offers/rewards, which are the
primary use case for saylinks. If an LLM response accidentally contains brackets
(e.g., describing "[gnoll fangs]"), the server will auto-inject a clickable link.
The Lua post-processing filter should strip square brackets from LLM output to
prevent unintended saylinks. The rule itself should NOT be changed — it is correct
behavior for the rest of the server.

**Recommendation: No rule change. Add bracket-stripping to llm_bridge post-processing.**

### 2.2 Chat:QuestDialogueUsesDialogueWindow

**Current value:** `false`
**Default in ruletypes.h:** `false`
**Effect:** When true, pipes NPC dialogue through the Dialogue Window popup.

**LLM implication:** The PRD specifies standard chat window delivery. Keeping this
false is correct — LLM responses via `e.self:Say()` appear in the chat channel
where they belong for conversational exchange. The Dialogue Window is more
appropriate for lengthy lore dumps or quest text, not back-and-forth conversation.

**Recommendation: No rule change. Leave at false.**

### 2.3 Range:Say — Critical Discrepancy

**Code default (ruletypes.h line 754):** `15` units
**Database override (rule_values):** `135` units

The server's actual Say trigger range is **135 units**, not 200 as stated in the
PRD appendix. The PRD appendix states: "Say range: RuleI(Range, Say) default 200
units, checked via DistanceNoZ()". Both the "default" (actually our DB value) and
the "200" figure are wrong: our DB value is 135, not 200.

**LLM implication:** The event_say hook fires only when the player is within 135
units. This is enforced by the server before the Lua handler is called — the Lua
bridge does NOT need to check distance. The typing indicator emote range (Range:Emote
= 135) matches Say range exactly, so any player who can trigger the LLM call will
also see the emote. This is ideal behavior.

**Recommendation: No rule change. Inform architect that PRD appendix has wrong
range value (200 should be 135 for this server). The architect may want to correct
the PRD or architecture doc.**

### 2.4 Range:Emote

**Current value:** `135` units
**Effect:** NPC emotes are visible to players within 135 units.

**LLM implication:** Since Range:Emote = Range:Say = 135, the typing indicator
emote (`e.self:Emote(...)`) is perfectly scoped — visible exactly to players who
can trigger the conversation. No mismatch.

**Recommendation: No rule change.**

### 2.5 NPC:SayPauseTimeInSec

**Code default:** `5` seconds
**DB values:** Shows both `10` and `5` in rule_values (historical duplicates).
Active value is the most recently set (likely `5` based on code default).

**LLM implication:** After `e.self:Say()` fires, the NPC pauses movement for 5
seconds. For 1-2 second LLM inference, this means the NPC will be stationary from
the moment the emote fires until well after the response is delivered. Good UX —
NPC appears focused on the player during the exchange.

**Recommendation: No rule change.**

### 2.6 Existing LLM Rules

No rules with `LLM%` prefix exist in rule_values. No `LLM` category exists in
ruletypes.h. The LLM feature has zero existing server-side configuration.

### 2.7 eqemu_config.json

- **Quest hot reload:** `"hotReload": true` under `web-admin.quests`.
  Lua module and global_npc.lua changes are hot-reloaded automatically. No server
  restart needed to test Lua changes.
- **No sidecar config section:** The server config has no concept of external
  HTTP services. This is correct — the sidecar URL belongs in Lua config, not here.
- **No changes needed to eqemu_config.json for Phase 1.**

### 2.8 Data Buckets — Per-NPC Opt-Out

**API confirmed from source:**

`eq.get_data(string)` in Lua maps to:
```cpp
DataBucket::GetData(&database, DataBucketKey{.key = bucket_key}).value
```

This is a simple global string key lookup — no automatic NPC type scoping. The
integration plan's pattern `"llm_enabled-" .. e.self:GetNPCTypeID()` is correct
and creates a unique global key per NPC type ID.

**Key behavior:**
- Key not found / never set: returns `""` (empty string)
- Key set to `"0"`: LLM disabled for this NPC type
- The opt-out model (default = LLM on, set "0" to opt out) requires ZERO database
  rows for the happy path. No setup needed until an NPC needs to be disabled.

**Enabling opt-out for a specific NPC:**
```sql
-- Disable LLM for NPC type ID 12345:
INSERT INTO data_buckets (key_, value, expires) VALUES ('llm_enabled-12345', '0', 0)
ON DUPLICATE KEY UPDATE value = '0';
```
Or via in-game Lua: `eq.set_data("llm_enabled-12345", "0")`

**Recommendation: Use `eq.get_data("llm_enabled-" .. npc_type_id)` exactly as
the integration plan describes. quest_globals is NOT appropriate (character-scoped,
legacy system). data_buckets is the right choice.**

### 2.9 Proposed LLM Rules (Phase 3, Not Phase 1)

The PRD appendix suggests adding `LLM:*` rules to ruletypes.h. These are NOT
needed for Phase 1 because:
1. Phase 1 has no C++ changes
2. All LLM config can live in `llm_config.lua` (hot-reloadable)
3. Adding C++ rules requires a full server rebuild

**Phase 1 config approach:** Store in `akk-stack/server/lua_modules/llm_config.lua`:
```lua
return {
    sidecar_url = "http://akk-stack-npc-llm:8100",
    timeout_seconds = 3,
    min_npc_intelligence = 30,
    max_response_length = 450,
    hostile_cooldown_seconds = 60,
    enable_typing_indicator = true,
    fallback_on_error = true,
}
```

**Phase 3 C++ rules (deferred):** When c-expert adds the LLM category to
ruletypes.h, these rules should be added:

| Rule | Type | Default | Notes |
|------|------|---------|-------|
| `LLM:Enabled` | bool | true | Global master toggle via `#rules` |
| `LLM:MinNPCIntelligence` | int | 30 | INT threshold |
| `LLM:SidecarURL` | string | `http://akk-stack-npc-llm:8100` | Sidecar endpoint |
| `LLM:TimeoutSeconds` | int | 3 | HTTP timeout |
| `LLM:HostileCooldownSeconds` | int | 60 | Threatening/Scowling cooldown |
| `LLM:MaxResponseLength` | int | 450 | Chat character cap |

### Documentation Consulted

| Item | Source | Verified |
|------|--------|---------|
| `Range:Say` code default = 15 | `eqemu/common/ruletypes.h:754` | Yes |
| `Range:Say` server value = 135 | `rule_values` DB query | Yes |
| `Chat:AutoInjectSaylinksToSay` = true | `rule_values` DB query + ruletypes.h:930 | Yes |
| `Chat:QuestDialogueUsesDialogueWindow` = false | `rule_values` DB query + ruletypes.h:932 | Yes |
| `eq.get_data()` simple string key | `eqemu/common/data_bucket.cpp:158-160` | Yes |
| `eq.get_data/set_data` Lua API | `eqemu/zone/lua_general.cpp:6076-6079` | Yes |
| Quest hot reload enabled | `akk-stack/server/eqemu_config.json:96` | Yes |
| No existing LLM rules | `rule_values` DB query + ruletypes.h grep | Yes |
| global_npc.lua has no event_say | File read | Yes |

### Plan Amendments

The PRD appendix cites `Range:Say` default as 200 units. This is incorrect for
this server. The actual DB override is 135. No plan amendment needed — the Lua
bridge doesn't check distance (server enforces it before event fires). But the
architect's docs should reflect 135.

---

## Stage 3: Socialize

Findings sent to architect via SendMessage (see agent-conversations.md).

### Messages Sent

| To | Subject | Key Points |
|----|---------|-----------|
| architect | Config/rules assessment complete | Range:Say=135 (not 200); no rule changes needed Phase 1; use llm_config.lua not rule_values; data_buckets confirmed for opt-out |

### Feedback Received

Awaiting architect response.

### Consensus Plan

_To be filled in after architect confirms._

---

## Stage 4: Build

This task is advisory only — no config changes are made. All findings are
documented above for the architect's use.

**No files modified.**

---

## Open Items

- [ ] Architect to confirm whether Range:Say discrepancy (135 vs PRD's "200") affects design
- [ ] Architect to confirm Phase 1 uses llm_config.lua (not rule_values) for LLM parameters
- [ ] Phase 3: c-expert to add LLM category to ruletypes.h; config-expert to insert rule_values rows

---

## Context for Next Agent

If you pick up config-expert work on this feature after context compaction:

**Key facts established:**
- Range:Say = 135 units on this server (not 200 as PRD says)
- Range:Emote = 135 (matches Say range — typing indicator visibility is correct)
- No LLM rules exist; none needed for Phase 1
- eq.get_data("llm_enabled-NPC_TYPE_ID") is confirmed working for opt-out
- Quest hot reload is enabled — Lua changes don't need server restart
- eqemu_config.json needs no changes for Phase 1
- Chat:AutoInjectSaylinksToSay=true means LLM responses must not contain [brackets]

**Phase 1 config deliverables (when architect assigns them):**
- Create `akk-stack/server/lua_modules/llm_config.lua` with sidecar URL, timeout, etc.
- No rule_values inserts needed until Phase 3

**Phase 3 config deliverables (future):**
- After c-expert adds LLM category to ruletypes.h and server is rebuilt:
  Insert rule_values rows for LLM:Enabled, LLM:MinNPCIntelligence, LLM:SidecarURL,
  LLM:TimeoutSeconds, LLM:HostileCooldownSeconds, LLM:MaxResponseLength
