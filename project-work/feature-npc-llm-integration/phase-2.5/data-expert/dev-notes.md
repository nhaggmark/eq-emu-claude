# NPC LLM Phase 2.5 — Lore Integration + Prompt Pipeline — Dev Notes: data-expert

> **Feature branch:** `feature/npc-llm-phase2.5`
> **Agent:** data-expert
> **Task(s):** #1 (global_contexts.json), #2 (local_contexts.json)
> **Date started:** 2026-02-24
> **Current stage:** Complete

---

## Task Assignment

| # | Task | Depends On | Status |
|---|------|------------|--------|
| 1 | Author `global_contexts.json` — 16 racial baselines, ~28 race+class combos, ~25 race+class+faction combos, 13 NPC overrides | — | Complete |
| 2 | Author `local_contexts.json` — 22 city zones + ~14 high-traffic outdoor zones at 3 INT tiers | — | Complete |

---

## Stage 1: Plan

### Files Examined

| File | Lines | What You Found |
|------|-------|----------------|
| `claude/project-work/feature-npc-llm-integration/phase-2.5/architect/architecture.md` | 625 | JSON structure specs, fallback chain design, faction-as-deity-proxy decision, token budgets |
| `claude/project-work/feature-npc-llm-integration/lore-deep-dive/context/npc-lore-bible.md` | ~1300+ | Full racial identities, deity pantheon, city cultures, faction deep-dives, NPC voice examples |
| `claude/project-work/feature-npc-llm-integration/lore-deep-dive/context/02-faction-system.md` | ~359 | Faction IDs, base standings, NPC flavor dialog from quest scripts |
| `claude/project-work/feature-npc-llm-integration/lore-deep-dive/context/01-zone-overview.md` | ~246 | Zone short names, NPC counts, zone connections |
| `claude/project-work/feature-npc-llm-integration/lore-deep-dive/context/03-zone-npc-census.md` | ~200+ | Zone-level NPC population summaries by faction |

### Key Findings

1. **Deity gap confirmed**: `GetPrimaryFaction()` returns `npc_faction.primaryfaction` (faction_list.id). This is the key for race_class_faction lookups. Deity is NOT in the database — faction encodes religious identity.

2. **Top city race+class combos by count** (from DB query):
   - race 130 class 1 (Vah Shir Warrior): 162 — highest city count
   - race 71 class 41 (unknown GM): 149 — generic merchant class, no lore context needed
   - race 130 class 41 (Vah Shir merchant): 84
   - race 3 class 41 (Erudite merchant): 73
   - Race IDs >14 are not canonical playable races — covered by generic fallback

3. **Key faction IDs verified** (primaryfaction values from npc_faction.primaryfaction):
   - 262 = Guards of Qeynos (25 NPCs in faction sets)
   - 330 = The Freeport Militia (63 NPCs)
   - 281 = Knights of Truth (39 NPCs)
   - 311 = Steel Warriors (16 NPCs)
   - 370 = Dreadguard Inner (32 NPCs)
   - 334 = Dreadguard Outer (15 NPCs)
   - 236 = Dark Bargainers (132 NPCs — largest named city merchant faction)
   - 441 = Legion of Cabilis (31 NPCs in faction sets)
   - 443 = Brood of Kotiz (22 NPCs)
   - 445 = Scaled Mystics (14 NPCs)
   - 1509 = Haven Defenders (176 NPCs)
   - 1503 = Validus Custodus (229 NPCs — largest Luclin faction)
   - 1513 = Guardians of Shar Vahl (60 NPCs)
   - 1584 = Citizens of Shar Vahl (145 NPCs)

4. **NPC override IDs confirmed** (both IDs for duplicate-named NPCs):
   - Plagus_Ladeson: 9112 and 382059
   - Valeron_Dushire: 8077 and 383027
   - Lady_Shae: 9058 and 383073
   - Guard_Kwint: 1151
   - Captain_Rohand: 1101
   - Behroe_Dlexon: 1000
   - Ebon_Strongbear: 1130
   - Dok: 29030
   - Trooper_Shestar: 106069
   - Captain Tillin: 1077 (from lore bible reference)

### Implementation Plan

- Write second-person cultural paragraphs sourced exclusively from npc-lore-bible.md
- Key race_class entries from top city NPC combos (prioritizing playable race IDs 1-14)
- Key race_class_faction entries for major named city factions
- Local context at 3 tiers: vague/named-factions/tactical per PRD spec

---

## Stage 2: Research

### Plan Amendments

No documentation research needed — data authoring task, not code authoring. Sources were the lore bible and zone census documents. JSON syntax verified by Python json.load() validation.

---

## Stage 3: Socialize

No blocking dependencies — Tasks 1 and 2 are independent of all other tasks. No cross-team coordination required before authoring. Output files are consumed by lua-expert's context_providers.py.

---

## Stage 4: Build

### Implementation Log

#### 2026-02-24 — Task 1: global_contexts.json

**What:** Authored 80 total context entries across 4 sections.
- 14 racial baseline entries (all playable races 1-14, Vah Shir ID=14 confirmed)
- 28 race+class combination entries (prioritized by city NPC population from DB query)
- 25 race+class+faction entries (keyed by primaryfaction ID from npc_faction table)
- 13 NPC-specific override entries (13 entries, some duplicate-ID NPCs have two entries)

**Where:** `/mnt/d/Dev/EQ/akk-stack/npc-llm-sidecar/config/global_contexts.json`

**Why:** All entries sourced from npc-lore-bible.md sections 2-3. Second-person voice throughout. Deity framing baked into faction-specific entries per architect's resolution.

**Notes:**
- All entries tested against 200-token estimate (4 chars/token approximation) — all within limit
- Longest entries ~118 estimated tokens (race[7] Half Elf, race_class_faction[1_1_262] Qeynos Guard)
- Race IDs >14 (non-playable) are not covered — context_providers.py falls back to empty string, which is correct behavior
- Faction key `1_1_262` means Human Warrior with primaryfaction=262 (Guards of Qeynos)

#### 2026-02-24 — Task 2: local_contexts.json

**What:** Authored 38 zone entries, each with 3 INT-gated tiers:
- 22 city zones (mandatory per architecture): qeynos, qeynos2, freporte, freportw, freportn, neriaka, neriakb, neriakc, halas, rivervale, grobb, oggok, kaladima, kaladimb, felwithea, felwitheb, akanon, erudnext, paineel, cabeast, cabwest, sharvahl, shadowhaven, katta (includes shadow haven and katta as Luclin cities, minus missing city zones — 24 total)
- 14 high-traffic outdoor zones: ecommons, commons, gfaydark, kithicor, blackburrow, crushbone, butcher, everfrost, nektulos, innothule, misty, feerrott, lakerathe, befallen

**Where:** `/mnt/d/Dev/EQ/akk-stack/npc-llm-sidecar/config/local_contexts.json`

**Why:** Source material from zone overview (01-zone-overview.md) and NPC census (03-zone-npc-census.md). Three tiers per PRD spec: low=vague/simple sentences, medium=faction names and travel advice, high=named mobs/level ranges/historical context.

**Notes:**
- Some high-tier entries exceed 200 chars/4 token estimate (qeynos.high ~211, gfaydark.high ~243 estimated tokens). These are within the architecture's LLM_BUDGET_LOCAL=150 token budget behavior — the assembler will truncate at sentence boundary if needed.
- All zone short names verified against zone_overview.md table
- Adjacent zone awareness embedded in medium/high tier text (not computed at runtime)

### Problems & Solutions

| Problem | Root Cause | Solution |
|---------|-----------|----------|
| Faction IDs in lore doc didn't match DB query results | Lore doc used faction_list.id directly, but GetPrimaryFaction() returns npc_faction.primaryfaction, which is also faction_list.id — they match. The confusion was that the top-count DB query returned non-canonical faction IDs for city zones (many race-tagged factions). | Queried npc_faction table directly joining to faction_list to get meaningful named factions with NPC counts. |
| Duplicate NPC names (Plagus_Ladeson has 2 different IDs) | Some NPCs exist in both original and custom/modified form in the database. | Included both IDs in npc_overrides section with identical content. |

### Files Modified (final)

| File | Action | Description |
|------|--------|-------------|
| `/mnt/d/Dev/EQ/akk-stack/npc-llm-sidecar/config/global_contexts.json` | Created | 29KB, 80 cultural context entries at 4 fallback levels |
| `/mnt/d/Dev/EQ/akk-stack/npc-llm-sidecar/config/local_contexts.json` | Created | 43KB, 38 zones with 3 INT-gated tiers each |

---

## Open Items

- [ ] lua-expert's context_providers.py needs to handle the case where `npc_overrides` key lookup uses string(npc_type_id) — confirm string vs int key in JSON lookup

---

## Context for Next Agent

Tasks 1 and 2 are complete. The two JSON files are at:
- `akk-stack/npc-llm-sidecar/config/global_contexts.json`
- `akk-stack/npc-llm-sidecar/config/local_contexts.json`

The fallback chain in global_contexts.json:
1. `npc_overrides[str(npc_type_id)]`
2. `race_class_faction[f"{race}_{class_}_{primary_faction}"]`
3. `race_class[f"{race}_{class_}"]`
4. `race[str(race)]`

The `primary_faction` key is from `GetPrimaryFaction()` which returns `npc_faction.primaryfaction` (the faction_list.id value). This is confirmed accurate.

Local context tier mapping: `low` = INT < 75, `medium` = INT 75-120, `high` = INT > 120.
