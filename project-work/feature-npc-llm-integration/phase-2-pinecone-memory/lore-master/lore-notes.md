# NPC Conversation Memory (Pinecone Integration) — Lore Notes

> **Feature branch:** `feature/npc-llm-integration`
> **Author:** lore-master
> **Date started:** 2026-02-24

---

## Feature Concept

Phase 2 adds persistent NPC conversation memory via Pinecone vector DB. NPCs remember past interactions with individual players. Lore review ensures:
- Memory acknowledgment stays within each city's voice and culture
- Impressionistic recall does not tip into uncanny-perfect memory
- Era compliance inherited from Phase 1 is not undermined by stored content
- Culturally distinct NPCs (Neriak, Iksar, Vah Shir, Oggok) express memory appropriately for their culture rather than generically

---

## Lore Research

### Zones and NPC Scenarios Reviewed

| Zone | Short Name | NPC | Review Finding |
|------|-----------|-----|----------------|
| South Qeynos | qeynos2 | Guard Hanlon (example) | Name plausible; Sabertooth gnoll threat accurate; Rodcet Nife invocation correct |
| East Commonlands | eastcommons | Merchant Talia (example) | Befallen reference accurate; holy water item plausible; generic merchant voice appropriate |
| West Freeport | freportw | Guard Brixton (example) | Freeport militia tolerance of dark elves accurate; Deathfist orc threat geographically correct; cynical voice appropriate |
| Greater Faydark | gfaydark | Guard Leafwalker (example) | Crushbone orc threat accurate; "moon" time reference authentic EQ phrasing; southern platform reference plausible |
| Neriak Foreign Quarter | neriaka | Darkguard Kaylorn (example) | Hostile emote for Scowling faction — correct; no memory stored or retrieved — correct |

### Faction and Cultural Context for Memory Tone

A critical lore finding: the game-designer's Scenario 3 (Guard Brixton, Freeport faction change) is the only example of memory-driven faction change acknowledgment. The PRD does not provide examples for Neriak, Cabilis, Oggok, or Shar Vahl — the four most tonally distinctive cities. Memory acknowledgment in each of these cities has specific lore requirements:

**Neriak (dark elf, Innoruuk):**
The Neriak NPC voice is calculating, contemptuous, and never warm — even toward Ally-faction players. Dark elves of Neriak treat outsiders (and even allies) with cool pragmatism. An NPC in Neriak recalling past conversations must NEVER use warm phrasing like "Good to see you again" or "I remember our discussion fondly." The correct framing is transactional: "You again. Last time you asked about the Bloodsabers. The answer has not changed." or "You have returned. What use are you to me now?" Any memory acknowledgment that reads as warm, friendly, or nostalgic is a Neriak lore violation.

**Cabilis (Iksar, Cazic-Thule):**
Iksar NPCs are deeply xenophobic toward non-Iksar. Even Iksar at Ally faction toward an outsider adventurer maintain suspicion and distance — the outsider has proved useful, not earned genuine belonging. Memory acknowledgment for Iksar must remain terse and achievement-oriented: "You return. Your previous service has been noted by the Brood." or "You were here before. The Ring of Scale has long memory for those who serve Sebilis." Warm familiarity from an Iksar is impossible.

**Oggok / Grobb (Ogre/Troll, Rallos Zek / Cazic-Thule):**
Simple syntax is mandatory. Ogre and Troll NPCs speak in short sentences with limited vocabulary. Memory acknowledgment should be blunt: "You come back. You fight good last time. What you want?" The PRD handles this through the INT-scaled voice system, but the memory injection prompt must not produce grammatically complex memory callbacks for Ogre/Troll NPCs.

**Shar Vahl (Vah Shir, Luclin):**
Vah Shir remember through honor and tribal framework. Memory is framed as recognizing proven worth: "You have been here before. Your deeds against the Grimlings were remembered." The Vah Shir are proud, direct, and would not use human-style social pleasantries when recalling past meetings.

### Historical Context

**Befallen** (West Commonlands): The dungeon is a ruined temple that fell to dark corruption — originally built by a necromancer named Miragul in some accounts, though the dungeon's specific history is somewhat ambiguous in Classic era. The canonical Classic lore is that Befallen is an evil, undead-infested ruin in the Commonlands. Merchant Talia's advice about undead and holy water is accurate.

**Blackburrow** (Qeynos Hills): The gnoll caves beneath Blackburrow Hills, home of the Sabertooth gnoll clan. Guard Hanlon's reference to the Sabertooth gnolls pushing toward city walls is accurate — the Sabertooth clan is the constant Classic-era threat to Qeynos from the north.

**Crushbone** (Greater Faydark): The orc stronghold ruled by Emperor Crush (later Dvinn). Constant military threat to Kelethin and the wood elves. Guard Leafwalker's reference to losing scouts is accurate to the ongoing conflict.

**Deathfist Orcs** (East Commonlands): The Deathfist orc clan occupies much of the East Commonlands east of Freeport. Guard Brixton's reference to "east of the tunnel" is geographically accurate — the Freeport-to-North-Freeport tunnel connects the city zones, and the Deathfist orcs are indeed east of the city walls.

---

## Era Compliance Review

| Element | Era | Compliant? | Notes |
|---------|-----|------------|-------|
| Memory system (Pinecone) | Classic infrastructure | Yes | Technical infrastructure; no lore content |
| Scenario 1 — Sabertooth gnolls, Qeynos | Classic | Yes | Correct clan name, correct threat direction |
| Scenario 2 — Befallen, holy water | Classic | Yes | Accurate dungeon reference for Classic era |
| Scenario 3 — Deathfist orcs, Freeport | Classic | Yes | Correct faction name, correct geography |
| Scenario 4 — Crushbone, Kelethin | Classic | Yes | Correct threat, correct "moon" time-phrasing |
| Faction change acknowledgment mechanic | Classic | Yes | Faction system is Classic-era; memory metadata references it |
| 90-day TTL / memory decay | N/A | Yes | Invisible to players; no lore implication |
| Impressionistic recall style | Classic | Yes | Consistent with EQ's environmental storytelling approach |
| Per-character memory (not per-account) | Classic | Yes | Characters as distinct entities is the correct EQ framing |
| Memory inheritance of Phase 1 era compliance | Classic | Yes | Stored content was filtered by Phase 1 post-processor |

**Hard stops:** None found. Phase 2 introduces no new era violations. Memory content inherits Phase 1's era boundary enforcement.

**One watchpoint (not a hard stop):** If a Phase 1 response slipped an era violation past the post-processor, that violation would be stored as a memory vector and could resurface. The PRD correctly identifies this and mitigates it with: (1) continued post-processor filtering on all final responses, and (2) memories included as context rather than quoted verbatim. This mitigation is sufficient.

---

## PRD Section Reviews

### Review: Example Scenarios (Scenarios 1–6)

- **Date:** 2026-02-24
- **Verdict:** APPROVED with one suggestion

**Approved items:**
- Scenario 1 (Guard Hanlon, South Qeynos): Correct faction, deity, threat. Dialogue tone appropriate for civic-duty Qeynos guard. Memory acknowledgment ("You asked about the gnolls a few days past") is natural human recall.
- Scenario 2 (Merchant Talia, East Commonlands): Befallen reference accurate. "The undead there do not take kindly to the living" is authentic EQ flavor. Return-visit memory ("Ah, the one bound for Befallen") is impressionistic and natural.
- Scenario 3 (Guard Brixton, Freeport faction change): Dark elf tolerance in Freeport is accurate. Deathfist orc threat is correct. "Well now, you have been making friends around here" — perfect Freeport cynical voice. "I remember when the Militia kept a closer eye on you" — excellent faction-change acknowledgment. Approved as written.
- Scenario 4 (Guard Leafwalker, Kelethin): Crushbone threat accurate. "This moon" time reference is authentic EQ phrasing. "Speak with the ranger captain near the southern platform" is plausible Kelethin detail.
- Scenario 5 (Neriak guard, Scowling): No memory, hostile emote only. Consistent with Phase 1 decision. Correct.
- Scenario 6 (Fresh character, no memories): Phase 1-equivalent response. Correct.

**Suggestion:**
Add one scenario demonstrating memory acknowledgment for a tonally extreme city — either Neriak (at a positive faction level) or Cabilis. This would demonstrate that city culture governs the *tone* of memory acknowledgment, not just the subject. Without this example, the implementation team may default to warm/generic phrasing for all memory callbacks. See "Lore Note for Architect" below.

### Review: Game Design Details — What NPCs Remember

- **Date:** 2026-02-24
- **Verdict:** APPROVED

**Approved items:**
- "Reference, do not recite" instruction: Correct. This is the core lore-protective constraint.
- "Impressionistic recall" — aligned with EQ's environmental storytelling style. NPCs speak from their own perspective, not from a log file.
- "Appropriate to role" — guard/merchant/scholar differentiation: Correct and lore-consistent.
- "Not forced" — memory only referenced when relevant: Correct. Forced callbacks are immersion-breaking.

### Review: Era Compliance Section

- **Date:** 2026-02-24
- **Verdict:** APPROVED

Phase 2 correctly defers era compliance to Phase 1's mechanisms. The edge case (era-violating content stored in memory) is correctly identified and mitigated.

### Review: Goals and Non-Goals

- **Date:** 2026-02-24
- **Verdict:** APPROVED

Memory as purely atmospheric (Goal 6: "No gameplay advantage from memory") is the correct lore-protective design choice. It keeps NPC memory in the realm of characterization rather than mechanics.

No cross-NPC memory (Non-Goal) is correct for Phase 2 — each NPC knows only what they personally experienced, consistent with how individuals work in Norrath.

---

## Decisions & Rationale

| # | Decision | Rationale | Alternatives Rejected |
|---|----------|-----------|----------------------|
| 1 | Impressionistic recall over transcript recall | EQ's storytelling style is atmospheric and environmental, not precise. NPCs referencing exact words would feel like a database query, not natural memory. | Verbatim quote retrieval — rejected because NPCs are characters, not logs |
| 2 | City culture must govern memory tone, not just memory content | A Neriak dark elf saying "Good to see you again" is a lore violation regardless of what they remember. The HOW of memory acknowledgment matters as much as the WHAT. | Generic warm-recall phrasing — rejected as breaking Neriak, Iksar, Ogre/Troll character |
| 3 | No lore constraints on 90-day TTL | Memory decay is invisible to players. It has no in-world meaning; it is a technical necessity. No lore guidance needed. | Shorter or longer TTL values — technically irrelevant to lore |
| 4 | Per-character memory (not per-account) is lore-consistent | EQ characters are distinct individuals in Norrath. A dark elf necromancer and a high elf paladin on the same account are different people to the world. NPCs treating them as different is correct. | Per-account memory — rejected as collapsing distinct characters into one |
| 5 | Neriak NPCs must never use warm phrasing in memory acknowledgment | Neriak culture is defined by cool calculation, contempt, and power dynamics. Even Ally-faction Neriak NPCs do not like outsiders — they merely find them useful. Warmth would shatter the city's identity. | Treating faction-level-1 (Ally) as a universal signal for warm recall — rejected because city culture supersedes faction warmth for Neriak |

---

## Final Sign-Off

- **Date:** 2026-02-24
- **Verdict:** APPROVED WITH NOTES
- **Summary:** The Phase 2 PRD is lore-sound. All six example scenarios use accurate EverQuest Classic-era references, correct threat factions, appropriate deities, and authentic NPC voice for their respective cities. The memory acknowledgment mechanic (impressionistic recall, not transcript recall) is aligned with EQ's environmental storytelling tradition. Era compliance is correctly inherited from Phase 1 with adequate mitigations for the stored-content edge case. The 90-day TTL has no lore implications. The one area requiring attention is that city culture must govern the *tone* of memory acknowledgment — the PRD specifies this correctly ("memory reflects the NPC's character") but the implementation team needs explicit guidance on the four most tonally extreme cities: Neriak, Cabilis, Oggok/Grobb, and Shar Vahl. This is captured in the "Context for Next Phase" section below.
- **Remaining concerns:** The implementation team must enforce city-culture tone for memory acknowledgment in the system prompt. Failure to do so risks Neriak NPCs sounding warm and Iksar NPCs sounding familiar — both of which would be notable lore violations that players familiar with EQ would notice immediately.

---

## Context for Next Phase

### Phase 1 Lore Decisions Carrying Forward (Binding)

- Threatening gives verbal warning; Scowling gives hostile emote only — no memory stored or retrieved at either level
- INT filter is sentience check, not intelligence commentary
- Zone Cultural Context table with 15 cities governs NPC voice
- Explicit modern concept blocklist in system prompt
- Broad rollout via opt-out model
- 11 body types excluded; Undead/Dragon/Monster NOT excluded

### Phase 2 New Lore Constraints (Binding for Implementation)

**Constraint 1: City culture governs the TONE of memory acknowledgment**

The system prompt for memory-enabled responses must instruct the LLM that the city's cultural voice applies to HOW memories are referenced, not just what content is referenced. The architect and python-expert should add language like:

> "When referencing past conversations, maintain the same cultural voice and attitude appropriate to your city and role. Do not shift to warm or familiar phrasing simply because you remember the player."

**Constraint 2: Neriak NPCs must use cold/transactional phrasing for memory**

Memory callbacks from Neriak NPCs must sound calculating, not warm. Acceptable: "You were here before. You asked about the Bloodsabers. Your curiosity could still get you killed." Unacceptable: "Ah, I remember you well. It is good to see you again." This applies at ALL faction levels — even Ally-faction Neriak NPCs do not show warmth.

**Constraint 3: Iksar NPCs must use suspicious/achievement-oriented phrasing for memory**

Memory callbacks from Cabilis Iksar must acknowledge past service without warmth. Acceptable: "You return. Your previous actions were noted." Unacceptable: "I am glad you came back — I was wondering how things went for you." Iksar do not worry about outsiders' wellbeing.

**Constraint 4: Ogre/Troll NPCs must maintain simple syntax in memory callbacks**

Memory references from Oggok/Grobb NPCs must be syntactically simple. The LLM should not produce complex, multi-clause memory acknowledgments for these NPC types. The system prompt for Oggok/Grobb should include an explicit instruction limiting sentence complexity.

**Constraint 5: Vah Shir (Shar Vahl) frame memory through honor/tribal recognition**

Vah Shir memory acknowledgment uses the honor framework: "You have proven yourself before. The Vah Shir remember those who stand against the Grimlings." Not "You are back! I was hoping you would return." The Vah Shir are proud and direct, not effusive.

### Lore Note on Example Scenarios for Implementation Team

The six example scenarios in the PRD are all lore-accurate and can be used as reference dialogue. The guard names (Hanlon, Brixton, Leafwalker) are plausible fictional names appropriate to their races and cities. The scenarios are not canonical EQ database NPCs — they are illustrative examples. Implementation team does not need to create these specific named NPCs; the memory system applies to all eligible NPC types.

### Recommendation: Add Seventh Example Scenario

I recommend the game-designer add a Scenario 7 to the PRD showing memory acknowledgment from a tonally distinctive city (Neriak or Cabilis) at a positive faction level. This would demonstrate to the implementation team that memory tone must follow city culture, not just faction level. Without this example, the implementation team may assume that Ally faction always produces warm recall — which is correct for Qeynos and Kelethin but wrong for Neriak and Cabilis.
