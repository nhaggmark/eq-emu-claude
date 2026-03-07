# Group Chat Companion Addressing — Dev Notes: Config Expert

> **Feature branch:** `feature/group-chat-addressing`
> **Agent:** config-expert
> **Task(s):** Task #3 — Assess configuration needs for group chat addressing
> **Date started:** 2026-03-07
> **Current stage:** Complete (architecture advisory — no implementation tasks yet)

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 3 | Assess configuration needs for group chat addressing | — | Complete |

---

## Stage 1: Plan

### Files Examined

| File | What You Found |
|------|----------------|
| `eqemu/common/ruletypes.h` | 47 rule categories, ~1186 rules. No existing Companion category. Chat category has 20 rules (anti-spam, saylinks, dialogue, channel flags). No rules touching group chat parsing, NPC name matching, or LLM response timing. |
| `rule_values` table (DB query) | Chat: and Channels: categories confirmed in DB. No companion-specific rules. No group-chat-routing rules. |
| `game-designer/prd.md` | Feature is entirely Lua/C++ implemented. PRD explicitly marks Rule values and Server configuration as unchecked affected systems. Open Question 5: "Should prefix list be configurable via a rule?" |
| `agent-conversations.md` | Lore-master approved prefix list: Guard, Captain, Lady, Lord, Sir, Priestess, High Priestess, Scout, Merchant, Innkeeper, Banker, Sage, Elder, Master, Apprentice, Lieutenant, Warden, Keeper, Deputy, Sergeant. |

### Key Findings

**No existing rules interact with this feature.** The Chat category covers anti-spam,
saylink injection, and channel permissions — none of which touch group-chat message
routing or companion name resolution. The Channels category covers UCS channel
administration. Neither category has rules relevant to `@name` parsing, companion
addressing, or LLM response staggering.

There is no existing Companion rule category. The Bots category is the closest
analogue (boolean to enable/disable, timing delays for AI, etc.) but Bots are a
completely separate system from recruited NPC companions.

---

## Stage 2: Research — Configuration Assessment

### Question 1: Should there be an enable/disable rule?

**Recommendation: Yes, a feature-enable boolean rule.**

Precedent: `Bots:Enabled` (default false) is the standard pattern for toggling
optional server features. A `Companion:GroupChatAddressingEnabled` rule (or
equivalent under whatever category the architect creates) follows this pattern
and gives server operators a clean on/off switch without code changes.

However: the architect should decide whether this belongs in an existing category
(Chat? Companion? World?) or warrants a new category. Since there is no Companion
rule category today, adding one is a c-expert task (ruletypes.h edit). The data-expert
would insert the rule_values row.

**Proposed rule:**
```
RULE_BOOL(Companion, GroupChatAddressingEnabled, true, "Enable @Name companion addressing via /gsay group chat")
```

Default `true` is appropriate — this is a core feature of our companion system, not
an optional add-on. An explicit `false` default would require every new install to
opt in before companions respond to group chat.

### Question 2: Should the NPC prefix strip list be configurable via rules?

**Recommendation: No — hardcode the list in Lua/C++, do not expose as a rule.**

Rationale:
- Rules are scalar values (int, real, bool, string). There is no rule type for a
  comma-separated list that the server can parse at runtime into a collection.
  String rules (`RULE_STR`) would require the consuming code to split and trim the
  string — fragile and complex for what amounts to a static configuration item.
- The prefix list is a content concern, not a server tuning knob. It does not need
  per-instance variation. The lore-master already audited it against the PEQ
  Classic–Luclin NPC database and approved 20 prefixes. This list is stable.
- Maintainability: a rule string like `"Guard,Captain,Lady,Lord,Sir,Priestess,..."`
  is opaque and error-prone for a server operator to edit. Code or a Lua table is
  self-documenting and version-controlled.
- If the architect decides the list needs to live in a config file rather than code
  (e.g., a JSON array in `eqemu_config.json` or a Lua table in a module), that is
  a reasonable alternative that avoids the rule system entirely.

**Verdict for architect:** Hardcode the approved 20-prefix list in whatever layer
owns the name matching logic (C++ parser or Lua module). No rule needed.

Approved prefix list from lore-master:
Guard, Captain, Lady, Lord, Sir, Priestess, High Priestess, Scout, Merchant,
Innkeeper, Banker, Sage, Elder, Master, Apprentice, Lieutenant, Warden, Keeper,
Deputy, Sergeant.

### Question 3: Should the response stagger delay be configurable via rules?

**Recommendation: Yes — expose as a rule, but as a simple integer (milliseconds).**

The PRD specifies 1–2 seconds between responses for multi-companion conversations.
This is a UX tuning value. Server operators may want to tighten or loosen this.
For a 1-player server vs. a 3-player server, the optimal delay may differ. The
LLM sidecar response time also varies; operators should be able to tune this.

**Proposed rules (two, for min/max of random range):**
```
RULE_INT(Companion, GroupChatResponseStaggerMinMS, 1000, "Minimum stagger delay in ms between companion LLM responses in group chat (for @all / multi-companion conversations)")
RULE_INT(Companion, GroupChatResponseStaggerMaxMS, 2000, "Maximum stagger delay in ms between companion LLM responses in group chat (for @all / multi-companion conversations)")
```

Defaults: min=1000ms, max=2000ms — exactly as specified in the PRD.

This follows the pattern of `Bots:AEMezSuccessDelay` (5000ms default, tunable int).
The implementing agent picks a random value in [min, max] per companion response.

### Question 4: Any existing rules that interact with group chat or companion behavior?

**None found that directly interact.** Closest candidates reviewed and dismissed:

| Rule | Category | Relevant? | Why Not |
|------|----------|-----------|---------|
| Chat:EnableAntiSpam | Chat | Potentially | Anti-spam tracks messages per interval. Companion LLM responses sent as NPCs speaking in group chat likely go through a different code path than player messages. Architect should verify companion GroupSay does not hit anti-spam accounting. |
| Chat:MaximumMessagesPerInterval | Chat | Potentially | Same concern as above — only relevant if companion responses are processed as player messages. |
| Chat:AlwaysCaptureCommandText | Chat | No | Governs # and ^ command capture, not @ parsing. |
| Bots:Enabled | Bots | No | Controls the EQEmu bot system, not recruited NPC companions. |

**Flag for architect:** Confirm that group chat messages sent by companion NPCs (via
`GroupSay` or equivalent) do not count against the player's anti-spam quota in
`Chat:EnableAntiSpam`. If they do, companion `@all` conversations could trigger
kick thresholds.

### Question 5: What rule category should these belong to?

**Recommendation: New `Companion` category in ruletypes.h.**

Rationale:
- No existing category fits. Chat covers player chat mechanics. Bots is a distinct
  system. World/Zone are infrastructure. NPC is for NPC behavior generally.
- The companion system is a custom feature of this server and will likely grow
  additional rules over time (e.g., max companions in group, LLM request timeout,
  conversation history depth). A dedicated Companion category is the right investment.
- The category name `Companion` is unambiguous and not in conflict with any existing
  category (verified against ruletypes.h).

**This requires a c-expert task:** Adding a new rule category means editing
`eqemu/common/ruletypes.h` and rebuilding. This is not a config-expert task.

---

## Stage 3: Socialize

_To be done after architect reviews this assessment. Architect may adjust based on
technical implementation decisions (e.g., if the stagger is handled entirely in
Python sidecar rather than C++/Lua, the rule may need to be passed differently)._

### Messages Sent

| To | Subject | Key Question |
|----|---------|-------------|
| architect | Config assessment complete | See findings — 2 rules recommended, prefix list hardcoded, new Companion category needed |

---

## Summary for Architect

**Rules recommended (2 new rules, new category):**

| Rule | Type | Default | Purpose |
|------|------|---------|---------|
| `Companion:GroupChatAddressingEnabled` | BOOL | true | Enable/disable the entire feature |
| `Companion:GroupChatResponseStaggerMinMS` | INT | 1000 | Min delay between multi-companion LLM responses |
| `Companion:GroupChatResponseStaggerMaxMS` | INT | 2000 | Max delay between multi-companion LLM responses |

**Not recommended as rules:**
- NPC prefix strip list — hardcode in Lua/C++ (not a tunable scalar)

**New category required:**
- `Companion` category in `ruletypes.h` — c-expert task (requires build)
- `rule_values` INSERT for the 3 rules above — data-expert task

**Watch for:** Verify companion GroupSay messages don't hit `Chat:EnableAntiSpam`
player message accounting.

**No existing rules** need to be changed for this feature.

---

## Context for Next Agent

If picked up after context compaction: this file contains the full config assessment
for the group-chat-addressing feature. The architect asked whether rules are needed;
the answer is yes (3 rules, new Companion category). The architect decides the final
rule names and whether they belong in C++ or Lua implementation. The data-expert
inserts rule_values rows once c-expert adds the ruletypes.h definitions.

Key paths:
- `eqemu/common/ruletypes.h` — where new rules are defined
- MariaDB `peq.rule_values` — where rule defaults are stored in DB
- `claude/project-work/feature/group-chat-addressing/agent-conversations.md` — conversation log
