# Recruited NPC Controls — Lore Notes

> **Feature branch:** `feature/recruited-npc-controls`
> **Author:** lore-master
> **Date started:** 2026-02-28

---

## Feature Concept

A command prefix system (`!`) to disambiguate explicit companion management commands from natural conversation. Unprefixed player speech flows to the LLM; `!`-prefixed text is parsed as a mechanical directive. This separates the control layer from the roleplay layer cleanly.

Lore implication: this is a pure UI/interaction mechanic. No zones, NPCs, factions, deities, or expansion-specific content is involved. The lore concern is confined to command vocabulary register and NPC response phrase authenticity.

---

## Lore Research

### Zones

Not applicable — this feature has no zone-specific content.

### NPCs & Characters

Not applicable — this feature affects all companion NPCs universally, not specific named NPCs.

### Factions

Not applicable.

### Deities & Races

Not applicable — the feature is race/deity agnostic. Race-specific companion voice is handled by the existing `companion_culture.lua` system and is unchanged by this feature.

### Historical Context

Not applicable. No expansion lore is touched.

**EQ command language precedents (relevant context):**

EQEmu already uses two meta-layer prefix conventions that players accept as system-level directives rather than spoken dialogue:
- `#` prefix: GM commands (`#goto`, `#kill`, `#zone`)
- `^` prefix: Bot commands

The `!` prefix fits this established pattern without collision. Players in this environment already understand that certain prefixed text operates at a system layer above natural speech.

**Classic EQ dialogue register:**

EQ NPC speech is terse, atmospheric, and period-appropriate. It avoids modern verbosity. The existing companion system establishes this baseline correctly:
- "I will join you." — recruitment success
- "Farewell." — dismissal
- "I will hold here." — guard mode
- "Understood. I will fight passive." — stance change

The "I will [verb]." sentence pattern is the established register for companion command acknowledgments throughout the codebase. New response phrases should conform to this pattern.

---

## Era Compliance Review

| Element | Era | Compliant? | Notes |
|---------|-----|------------|-------|
| `!` prefix character | N/A (UI mechanic) | Yes | No lore reference; meta-layer convention |
| Command vocabulary: `!passive`, `!balanced`, `!aggressive` | Classic | Yes | Tactical shorthand; era-neutral |
| Command vocabulary: `!follow`, `!guard`, `!recall` | Classic | Yes | Natural military/companion orders |
| Command vocabulary: `!dismiss` | Classic | Yes | Medieval register, natural |
| Command vocabulary: `!target`, `!assist` | Classic | Yes | Era-neutral utility words |
| Command vocabulary: `!status`, `!equip`, `!equipment`, `!help` | Classic | Yes | Era-neutral utility words |
| NPC response phrases | Classic | Yes (with corrections — see PRD Section Reviews) | See Issues 1 and 2 |
| Removal of natural-language aliases | Classic | Yes | Improves immersion |

**Hard stops:** None identified. This feature contains no post-Luclin references.

---

## PRD Section Reviews

### Review: Full PRD — 2026-02-28

- **Date:** 2026-02-28
- **Verdict:** APPROVED WITH MINOR ISSUES
- **Approved items:**
  - `!` prefix choice — consistent with established meta-layer conventions (`#`, `^`); no lore concerns
  - Recruitment staying keyword-based — correct; the act of persuading an NPC to join should feel like conversation, not a system command
  - Removal of natural-language aliases (`farewell`, `goodbye`, `leave`, `stay`, `inventory`, etc.) — this is an immersion improvement; players can now speak naturally to companions without accidentally triggering commands
  - Era compliance — confirmed; no zone, faction, deity, or expansion-specific references
  - Example scenario dialogue (Guard Hansl, North Karana) — dialogue is exactly the right register; "I served the south gate for eight years. The merchants come through at dawn, the trouble comes after dark. I do not miss the cold." is the terse, specific, atmospheric voice that defines Classic EQ
  - All response phrases except the two flagged below
  - New command vocabulary (`!recall`, `!target`, `!assist`, `!status`, `!equip`, `!help`) — all era-neutral utility words; no lore concerns
  - Error messages — displayed as system messages to player, not NPC speech; do not need to be in-character
- **Issues found:**
  - ISSUE 1: "I will fight at your side." (balanced stance response) — "at your side" carries warm/relational weight that violates the mercenary word prohibition established in `companion_culture.lua`. For companions (loyal type) this phrase is appropriate; for mercenaries (type=1) it implies partnership that contradicts their cold, transactional characterization. Correction: split response by companion_type (loyal: "I will fight at your side." / mercenary: "Understood."), or use neutral "Understood." for both types.
  - ISSUE 2: "Targeting." and "Assisting." (combat command responses) — one-word present-participles read as UI status output, not NPC speech. Breaks the "I will [verb]." sentence pattern established throughout the companion system. Compare: "I will follow.", "I will hold here.", "I will stand down." — all complete sentences. Correction: replace "Targeting." with "I see your target." and replace "Assisting." with "I will assist."
- **Suggestions offered:**
  - The `stance_change` event type is listed in `companion_culture.lua`'s header comment but has no handler in `_get_event_prompt()` — falls through to `return ""` silently. Command acknowledgments are hardcoded, not LLM-generated. This is correct behavior for `!`-prefixed commands; flagged so architect does not assume LLM involvement in command responses.
- **Game-designer response:** Confirmed both corrections 2026-02-28. Balanced stance split by companion_type; combat commands updated to "I see your target." and "I will assist."

---

## Decisions & Rationale

| # | Decision | Rationale | Alternatives Rejected |
|---|----------|-----------|----------------------|
| 1 | All existing command vocabulary is era-clean | Words like `passive`, `balanced`, `aggressive`, `follow`, `guard`, `dismiss` are all era-neutral; no post-Luclin references | N/A |
| 2 | Avoid abbreviated prefixes (`c`, `comp`) | Abbreviations feel like text messaging, not Norrathian speech; breaks immersion more than a symbol prefix | "c follow", "comp guard" |
| 3 | `!` prefix is acceptable as meta-layer convention | Players in EQEmu already accept `#` and `^` as system-layer directives; `!` fits this pattern without collision | Name-based prefix (too complex for arbitrary NPC names); long spoken prefix ("companion, follow") |
| 4 | Name-based prefix deferred as Non-Goal | NPC names in EQ are unpredictable ("a Qeynos guard", names with spaces); parsing complexity outweighs immersion benefit for initial implementation | Name-based prefix was lore-master's top immersion preference but accepted the complexity argument |
| 5 | Removal of natural-language aliases is an immersion improvement | Players can now speak naturally ("Farewell, old friend") and receive LLM responses instead of accidental dismissal | Keeping keyword aliases alongside prefix system (creates confusion, partial solution) |
| 6 | "Targeting." and "Assisting." must be replaced | One-word present-participles are UI status text, not speech; violates the terse-but-complete sentence register established throughout the companion system | Keeping single-word responses |
| 7 | "I will fight at your side." needs companion/mercenary split or neutral alternative | "At your side" implies partnership; violates mercenary word prohibition in companion_culture.lua | Single phrase for both types |

---

## Final Sign-Off

- **Date:** 2026-02-28
- **Verdict:** APPROVED
- **Summary:** The PRD is lore-sound. The `!` prefix system is era-compliant, the command vocabulary is appropriate, and the design decision to preserve keyword-based recruitment while moving management to a prefix is correct from a lore perspective. The removal of natural-language aliases is an immersion improvement. Two response phrase corrections were required and confirmed by the game-designer: (1) balanced stance splits by companion_type — loyal "I will fight at your side." / mercenary "Understood." — preserving the mercenary word prohibition from companion_culture.lua; (2) combat commands "Targeting." and "Assisting." replaced with "I see your target." and "I will assist." to maintain the established "I will [verb]." sentence pattern.
- **Remaining concerns:** None. No era compliance risks, no faction sensitivities, no NPC characterization concerns. PRD is ready for the architect.

---

## Context for Next Phase

**For the architect and implementation team:**

1. **Command acknowledgments are hardcoded, not LLM-generated.** The `stance_change` event type exists in companion_culture.lua's header but has no handler — it falls through silently. `!`-prefixed command responses should always be hardcoded brief phrases, never routed through the LLM. This is correct and intentional.

2. **Mercenary word prohibition applies to hardcoded phrases too.** The `companion_culture.lua` prohibition on warm/relational language for mercenary-type companions (companion_type=1) is not just an LLM constraint — it should inform hardcoded response phrases as well. When a mercenary companion changes stance to balanced, "I will fight at your side." is wrong; "Understood." is correct.

3. **The "I will [verb]." pattern is the established voice.** All new command acknowledgment phrases should follow this pattern: "I will follow.", "I will hold here.", "I will stand down.", "I will assist." Deviations need a strong reason.

4. **Dialogue register for `!dismiss` response.** The companion's "Farewell." response to `!dismiss` goes through the LLM dismiss event handler in companion_culture.lua (event_type="dismiss"), which generates culturally appropriate parting dialogue. The hardcoded "Farewell." in the PRD command table may be a fallback — implementer should verify whether the dismiss command triggers the LLM event or just uses the hardcoded phrase. If the latter, the LLM dismiss event context is being bypassed and companions lose their cultural parting voice.

5. **No lore constraints on new commands** (`!recall`, `!target`, `!assist`, `!status`, `!equip`, `!help`). Implementation is unconstrained from a lore perspective.
