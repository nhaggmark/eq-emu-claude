# NPC Companion Context — Agent Conversations Log

> **Feature branch:** `feature/npc-companion-context`
> **Created:** 2026-03-02

This file preserves cross-agent communication for context durability. When
context windows compact, this log ensures decisions, coordination, and
rationale are never lost.

**Every agent on a team MUST log their SendMessage exchanges here.**

**Rules:**
1. Log ALL exchanges, including "no concerns" / "no constraints" responses
2. Log the date, sender, recipient, content summary, and outcome
3. An empty section for a team phase means the team process was skipped
4. "APPROVED — no issues" is a valid and valuable finding; it must be logged
5. This file is the audit trail that proves peer review actually happened

---

## Design Team Conversations

_game-designer + lore-master exchanges during Phase 2._

### 2026-03-02 — Initial Feature Concept and Lore Context Request

**From:** game-designer → **To:** lore-master

> Starting PRD for NPC Companion Context feature. Core concept: when NPC is
> recruited as companion, LLM context shifts so they talk as group member, not
> original role. Will send lore-sensitive sections for review. Key areas:
> race/class/culture personality variation, zone awareness, era compliance.

**Response from** lore-master:

> Acknowledged. Ready to review sections as they come in.

**Outcome:** Initial coordination established. Lore-master aware of incoming review.

---

### 2026-03-02 — PRD Draft Lore Review Request

**From:** game-designer → **To:** lore-master

> PRD draft complete. Sent three sections for lore review:
> 1. Example scenario using Tegea Prendyn (Surefall Glade Druid) — verify NPC
>    exists, gnoll clan in West Karana, Surefall Glade details
> 2. Personality variation by race/culture (Erudite, Barbarian, Dark Elf,
>    Halfling, Troll, Vah Shir archetypes) — verify accuracy
> 3. Era compliance — Vah Shir/Luclin references, PoP boundary

**Response from** lore-master:

> APPROVED WITH ONE ISSUE AND SEVERAL NOTES:
>
> **ISSUE #1 (Required fix):** Gnoll clan error — Splitpaw clan is in
> Southern Karana, not West Karana. West Karana gnolls are the Sabertooth
> clan (based in Blackburrow). A Surefall Glade druid would know the
> difference.
>
> **Suggestions incorporated:**
> - Vah Shir: Primary threats are grimlings and Akheva, not Shissar.
>   Shissar are distant/secondary (Grey region, Ssraeshza Temple).
> - Vah Shir oral culture: Written records banned. Knowledge passed via
>   hymnists and mnemonic scribes. They blame Erudite written magic for
>   exile to Luclin. Rich personality territory.
> - Iksar KOS constraints: Cannot reference good-aligned old-world cities
>   as familiar. Welcome only in Cabilis, Thurgadin, Luclin cities.
> - Erudite distinction: Erudin (good) vs Paineel (heretics). Class
>   identifies origin city (necromancer = Paineel, paladin = Erudin).
> - Era compliance additions: Froglok (monster only), Berserker (does not
>   exist), PoP exclusion.
> - Luclin fixed-lighting zones: Day/night commentary invalid on some
>   Luclin zones.
>
> **All other sections approved:** Problem statement, goals, non-goals,
> player flow, druid-underground discomfort, Surefall Glade waterfall,
> Befallen undeath reference, identity shift mechanics, balance
> considerations, affected systems, acceptance criteria, technical appendix.
>
> **Existing companion_culture.lua framings confirmed lore-accurate:**
> Ogre panic behavior, Dark Elf cold precision, Iksar disciplined/insular,
> Troll feral aggression.

**Outcome:** All findings incorporated into PRD. Gnoll clan fixed to
Sabertooth. Vah Shir, Iksar, Erudite, era compliance sections enriched.
New Iksar acceptance criterion added. Luclin lighting open question added.
Lore-master implementation notes added to technical appendix.

---

### 2026-03-02 — Lore Corrections Confirmation

**From:** game-designer → **To:** lore-master

> Confirmed all 10 changes incorporated into PRD:
> 1. Splitpaw -> Sabertooth gnolls
> 2. Vah Shir threats: grimlings/Akheva primary, Shissar secondary
> 3. Vah Shir oral culture (hymnists, banned written records)
> 4. Iksar KOS constraints with city list
> 5. Iksar acceptance criterion added
> 6. Erudite Erudin/Paineel distinction
> 7. Froglok/Berserker era exclusions
> 8. Luclin fixed-lighting note + open question
> 9. Lore-master implementation notes in technical appendix
> 10. PRD header updated with lore approval

**Response from** lore-master:

> _(confirmation acknowledged)_

**Outcome:** PRD finalized with full lore sign-off. Ready for architecture.

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

### [Date] — [Topic]

**From:** [agent] → **To:** [agent]

> [Message content or summary]

**Response from** [agent]:

> [Response content or summary]

**Outcome:** _What was decided or changed as a result_

---

## Implementation Team Conversations

_Expert-to-expert exchanges during Phase 4._

### [Date] — [Topic]

**From:** [agent] → **To:** [agent]

> [Message content or summary]

**Response from** [agent]:

> [Response content or summary]

**Outcome:** _What was decided or changed as a result_

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication.
This table is the quick-reference for anyone catching up._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | West Karana gnolls are Sabertooth clan, not Splitpaw | game-designer, lore-master | 2026-03-02 | Example scenario correction |
| 2 | Vah Shir primary threats are grimlings and Akheva, not Shissar | game-designer, lore-master | 2026-03-02 | Cultural accuracy |
| 3 | Vah Shir oral culture (banned written records) is a defining personality trait | game-designer, lore-master | 2026-03-02 | Personality differentiation |
| 4 | Iksar companions must not reference good-aligned old-world cities as familiar | game-designer, lore-master | 2026-03-02 | KOS lore constraint |
| 5 | Erudite companions should distinguish Erudin vs Paineel origin by class | game-designer, lore-master | 2026-03-02 | Personality enrichment |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| (none) | | | |

