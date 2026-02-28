# NPC LLM Phase 3: Soul & Story — Test Plan

> **Feature branch:** `feature/npc-llm-phase3`
> **Author:** game-tester
> **Date:** 2026-02-25
> **Server-side result:** FAIL — container restart required before in-game testing

---

## Test Summary

Phase 3 adds three enrichments to the NPC LLM sidecar: (1) individual backstory overrides
for 137 key NPCs across all 15 starting cities, (2) a Tier 2 quest hint system that gives
scripted quest NPCs natural LLM fallback for off-keyword speech, and (3) a soul element
framework providing personality traits, motivations, and recruitment disposition via Layer 6
of the prompt assembler. No C++ or database changes were made.

### Inputs Reviewed

- [x] PRD at `game-designer/prd.md` — reviewed, 18 acceptance criteria identified
- [x] Architecture plan at `architect/architecture.md` — reviewed, validation plan followed
- [x] status.md — Tasks 1-5 marked Complete; Tasks 6-7 (content authoring) marked In Progress / Not Started

**Implementation gap note:** Status.md shows Tasks 6 (backstory authoring) as "In Progress" and Task 7
(soul element data) as "Not Started" — but both are in fact complete in the config files. The status
was not updated to reflect completion. All 137 backstory entries and 70 soul element entries are present.

---

## Part 1: Server-Side Validation

### Results

| # | Check | Result | Details |
|---|-------|--------|---------|
| 1 | Sidecar health endpoint | PASS | Status "ok", model loaded (Hermes-3-Llama-3.1-8B), ChromaDB connected |
| 2 | global_contexts.json JSON validity | PASS | Valid JSON, 137 npc_overrides |
| 3 | soul_elements.json JSON validity | PASS | Valid JSON, 4 role_defaults, 70 npc_overrides |
| 4 | Backstory city coverage (all 15 cities) | PASS | All 15 starting cities have entries. Qeynos: 35, Shar Vahl: 12, Kaladim: 12, Felwithe: 12, Freeport: 11, Halas: 11, Erudin: 10, Kelethin: 9, Neriak: 9, Paineel: 9, Rivervale: 9, Cabilis: 9, Grobb: 5, Ak'Anon: 5, Oggok: 3 |
| 5 | PRD minimum: 50+ backstory overrides | PASS | 137 total, well above minimum |
| 6 | Duplicate NPC type ID pairs | PASS | Plagus Ladeson (9112/382059), Valeron Dushire (8077/383027), Lady Shae (9058/383073) — all pairs present and text identical |
| 7 | SoulElementProvider loads + role detection | PASS | 4 role defaults, 70 NPC overrides loaded. Role detection: guard/captain/merchant/guildmaster/priest all correct |
| 8 | Soul element formatting (Captain Tillin) | PASS | Produces valid natural-language personality paragraph with deity reference |
| 9 | Deity alignment spot check (3 NPCs) | PASS | Rodcet Nife (1068), Tribunal (29056), Innoruuk (42019) all satisfy PRD minimum constraints |
| 10 | Config reload endpoint accessible | FAIL | Running container was started at 00:37 UTC before Phase 3 code was written. /v1/config/reload returns 404. Container restart required. |
| 11 | SoulElementProvider registered at startup | FAIL | Container startup log shows GlobalContextProvider loaded but NOT SoulElementProvider. Old code running in memory. |
| 12 | LLM_BUDGET_SOUL env var in container | FAIL | Container has LLM_BUDGET_SOUL=0 (pre-Phase 3 value). Should be 150. Soul elements disabled. |
| 13 | LLM_BUDGET_QUEST_HINTS env var | FAIL | Env var absent from running container. Code defaults to 150, so quest hints budget works from code default — but operators cannot override without restart. |
| 14 | SOUL_ELEMENTS_PATH env var | FAIL | Absent from running container. SoulElementProvider uses hardcoded fallback path (/config/soul_elements.json) which is correct — but env var not visible to operators. |
| 15 | Lua syntax — llm_bridge.lua | PASS | Clean compile |
| 16 | Lua syntax — all 31 Tier 2 quest scripts | PASS | 31/31 PASS, 0 FAIL |
| 17 | npc_deity in llm_bridge.build_context() | PASS | `npc_deity = e.self:GetDeity()` present at line 98 |
| 18 | build_quest_context() function present | PASS | Defined at lines 116-121, merges quest_hints and quest_state |
| 19 | quest_hints/quest_state in generate_response() | PASS | Both forwarded to sidecar at lines 148-149 |
| 20 | Quest scripts have bracketed keywords | PASS | All 31 Tier 2 scripts contain [bracketed] keywords in quest_hints |
| 21 | quest_hints/quest_state in ChatRequest model | PASS | Both optional fields present in models.py lines 27-28 |
| 22 | Layer 5.5 (quest hints) in prompt assembler | PASS | Implemented at lines 181-188 of prompt_assembler.py |
| 23 | Layer 6 (soul elements) in prompt assembler | PASS | Implemented at lines 190-204. Correctly skips when budget_soul=0 |
| 24 | Existing test suite (15 regression tests) | PASS | 15/15 PASS. No regression in Tier 1 NPC behavior |
| 25 | NPC ID correctness: Captain Tillin | WARN | Captain_Tillin.lua footer comment says "ID:1077" but DB confirms Captain Tillin = 1068, not 1077. ID 1077 is Danon_Fletcher (a merchant). Both 1068 and 1077 have Captain Tillin backstories — 1077's backstory will apply to the wrong NPC. |
| 26 | Duplicate keys in soul_elements.json | WARN | 5 NPC IDs appear twice: 9100 (Arinna Trueblade), 75075 (Overlord Virate Manaar), 42019 (High Priestess Alexandria), 82044 (Harbinger Glosk), 155151 (King Raja Kerrath). Python json.load silently uses the last occurrence. Both entries look thematically consistent for each NPC — the later entry is richer — but this is a data hygiene issue. |
| 27 | DB integrity: no C++ or schema changes | PASS | Architecture confirmed no database changes; verified no new tables or modified columns |
| 28 | Build verification | PASS (N/A) | No C++ changes. Server rebuild not required. |
| 29 | Server logs for LLM errors | PASS | No LLM or quest script errors in zone or world logs |

---

### CRITICAL BLOCKER: Container Restart Required

**The sidecar container must be restarted before any in-game Phase 3 testing can be performed.**

The container was started before Phase 3 code was written. The bind-mounted `/app/app` directory
contains the Phase 3 code on disk, but the running uvicorn process loaded the old module at
startup time. The following Phase 3 features are non-functional until restart:

1. Soul elements (Layer 6) — `LLM_BUDGET_SOUL=0` in container env, `SoulElementProvider` not initialized
2. Config reload endpoint (`/v1/config/reload`) — returns 404 (route not registered in old code)
3. Quest hints budget env var (`LLM_BUDGET_QUEST_HINTS`) — absent, falls back to code default of 150

**Quest hints (Layer 5.5) will work after restart** because the code default is 150 tokens and the
Python module on disk has the implementation.

**Restart command:**
```bash
cd /mnt/d/Dev/EQ/akk-stack && make down-llm && make up
```
Or from Spire at http://192.168.1.86:3000, restart the npc-llm service.

---

### Database Integrity

No database tables were modified by this feature. The architecture confirmed this is a
sidecar + Lua + config-only change. DB integrity checks are not applicable to this feature.

Verified that key NPCs referenced in the quest scripts exist in the database:

```sql
SELECT id, name, race, class, npc_faction_id
FROM npc_types
WHERE id IN (1068, 1085, 4057, 54088, 29056, 9018, 42019);
```

Results: All 7 queried NPCs exist. No orphan references.

**NPC ID discrepancy found (WARN #25):**
- Captain Tillin database ID: **1068** (confirmed via `WHERE name LIKE '%Tillin%'`)
- Captain_Tillin.lua script comment says: `-- END of FILE Zone:qeynos  ID:1077`
- NPC type ID 1077 is actually **Danon_Fletcher** (race 71 Human, class 41 Merchant, merchant_id 1077)
- The quest script loads by NPC name (not ID), so Captain_Tillin.lua fires correctly for Captain Tillin
- However, `global_contexts.json` and `soul_elements.json` have entries for both 1068 AND 1077
- ID 1068 correctly gets Captain Tillin's backstory and soul elements
- ID 1077 (Danon Fletcher, a merchant) also gets Captain Tillin's backstory — this is wrong

---

### Quest Script Syntax

All 31 Tier 2 upgraded scripts and the llm_bridge.lua module pass Lua syntax check.

| Script | Language | Result | Notes |
|--------|----------|--------|-------|
| lua_modules/llm_bridge.lua | Lua | PASS | |
| freporte/Bronto_Thudfoot.lua | Lua | PASS | |
| freportn/Groflah_Steadirt.lua | Lua | PASS | |
| freportn/Kalatrina_Plossen.lua | Lua | PASS | |
| grobb/Basher_Avisk.lua | Lua | PASS | |
| grobb/Bregna.lua | Lua | PASS | |
| halas/Alec_McMarrin.lua | Lua | PASS | |
| halas/Lysbith_McNaff.lua | Lua | PASS | |
| halas/Shamus_Felligan.lua | Lua | PASS | |
| halas/Waltor_Felligan.lua | Lua | PASS | |
| kaladima/Kennelia_Gwieal.lua | Lua | PASS | |
| kaladima/Vacto_Molunel.lua | Lua | PASS | |
| oggok/Ambassador_K-Ryn.lua | Lua | PASS | |
| oggok/Clurg.lua | Lua | PASS | |
| oggok/Puwdap.lua | Lua | PASS | |
| paineel/Nivold_Predd.lua | Lua | PASS | |
| qey2hh1/Einhorst_McMannus.lua | Lua | PASS | |
| qey2hh1/Furball_Miller.lua | Lua | PASS | |
| qeynos/Caleah_Herblender.lua | Lua | PASS | |
| qeynos/Captain_Rohand.lua | Lua | PASS | |
| qeynos/Captain_Tillin.lua | Lua | PASS | |
| qeynos/Ebon_Strongbear.lua | Lua | PASS | |
| qeynos/Exterminator_Rasmon.lua | Lua | PASS | |
| qeynos/Gahlith_Wrannstad.lua | Lua | PASS | |
| qeynos2/Aenia_Ghenson.lua | Lua | PASS | |
| qeynos2/Astaed_Wemor.lua | Lua | PASS | |
| qeynos2/Brohan_Ironforge.lua | Lua | PASS | |
| qeytoqrg/Rilca_Leafrunner.lua | Lua | PASS | |
| rivervale/Ace_Slighthand.lua | Lua | PASS | |
| rivervale/Beek_Guinders.lua | Lua | PASS | |
| sharvahl/Dar_Khura_Pyjek.lua | Lua | PASS | |
| sharvahl/Vlarha_Myticla.lua | Lua | PASS | |

Tier 2 zone coverage (31 scripts, excluding llm_bridge.lua): Qeynos: 6, Halas: 4,
North Qeynos: 3, Oggok: 3, Shar Vahl: 2, Rivervale: 2, Qeynos Hills: 2, Kaladim: 2,
Grobb: 2, North Freeport: 2, Qeynos-to-Qeynos-Hills: 1, Paineel: 1, East Freeport: 1.
All 11 zones represented. PRD minimum of 20 scripts exceeded (31 delivered).

---

### Log Analysis

| Log File | Errors Found | Severity | Related To |
|----------|-------------|----------|------------|
| world_175.log | None | N/A | No LLM or quest errors |
| zone logs (6 most recent) | None | N/A | No LLM or quest errors |
| akk-stack-npc-llm-1 container logs | 3x 404 /v1/config/reload | High | Our test calls; endpoint not in running code |

---

### Rule Validation

No EQEmu rule values were changed. `AutoInjectSaylinksToSay` was confirmed by the architect
(pre-implementation) to default to true. No new rule validation needed.

---

### Spawn Verification

No spawn changes. Not applicable to this feature.

---

### Loot Chain Validation

No loot changes. Not applicable to this feature.

---

### Build Verification

No C++ changes. Server rebuild not required or performed.

---

## Part 2: In-Game Testing Guide

**PREREQUISITE FOR ALL TESTS:** The sidecar container must be restarted before performing
any in-game tests. Soul elements will not work until LLM_BUDGET_SOUL=150 takes effect.

**Restart command:**
```bash
cd /mnt/d/Dev/EQ/akk-stack && make down-llm && make up
```

Wait for the sidecar to report healthy before beginning in-game tests:
```bash
docker exec akk-stack-npc-llm-1 curl -s http://localhost:8100/v1/health
```

Expected response after restart: `{"status":"ok","model_loaded":true,...}`

Also verify Phase 3 env vars are active:
```bash
docker exec akk-stack-npc-llm-1 env | grep -E "SOUL|QUEST_HINTS"
```
Expected: `LLM_BUDGET_SOUL=150`, `LLM_BUDGET_QUEST_HINTS=150`, `SOUL_ELEMENTS_PATH=/config/soul_elements.json`

### Prerequisites

- A GM-level character (to use `#goto` for fast travel)
- Character level 1 is fine — we are testing NPC dialogue, not combat
- The Titanium client connected to 192.168.1.86
- The sidecar restarted with Phase 3 env vars active (see above)

**Recommended GM commands for fast setup:**
```
#goto qeynos       -- teleport to South Qeynos
#goto halas        -- teleport to Halas
#goto kelethin     -- teleport to Kelethin
#goto grobb        -- teleport to Grobb
#goto sharvahl     -- teleport to Shar Vahl
#reloadquests      -- reload quest scripts after any script change
```

---

### Test 1: Backstory NPC vs Generic NPC Contrast (Qeynos)

**Acceptance criterion:** "A player speaking to a backstoried NPC receives dialogue that
reflects the NPC's individual history, distinguishable from a generic NPC of the same race/class/faction."

**Prerequisite:** GM character in South Qeynos. Sidecar running with Phase 3 env vars.

**Steps:**
1. Use `#goto qeynos` to teleport to South Qeynos.
2. Target Captain Tillin (the named captain, NPC ID 1068, near the gate).
3. Say: `Tell me about yourself.`
4. Expected: Tillin responds with specific personal detail about his fifteen years of service to Antonius Bayle IV, his knowledge of guard rotations, his concern about gnoll raids, and his worry about Bloodsaber corruption. He should close with "Rodcet Nife" or "Prime Healer" language. The response must not sound like a generic guard.
5. Note the response. Then target any nearby unnamed guard (e.g., "Guard Dunix" or a patrol guard).
6. Say the same to the unnamed guard: `Tell me about yourself.`
7. Expected: The nameless guard responds with the standard Qeynos Guard faction context — professional but without Tillin's personal depth.
8. Compare the two responses. Tillin's should feel meaningfully more specific.

**Pass if:** Tillin's response references at least one of: gnolls, Blackburrow, Bloodsaber corruption, Antonius Bayle IV by name, fifteen years, or South Qeynos specifically. The unnamed guard's response does not match Tillin's.

**Fail if:** Both NPCs give identical or near-identical generic responses.

**GM commands for setup:**
```
#goto qeynos
#findnpc Captain Tillin
```

---

### Test 2: Backstory Coverage — Cross-City Guard Identity Contrast

**Acceptance criterion:** "Guard backstories reflect city-specific guard force identity (Freeport Militia
is NOT virtuous, Halas guards use brogue, etc.)"

**Prerequisite:** GM character, ability to travel between cities.

**Steps — Halas:**
1. Use `#goto halas` to teleport to Halas.
2. Target any Halas guard or Lysbith McNaff.
3. Say: `What keeps you busy here?`
4. Expected: The guard uses brogue dialect: "ye", "o'", "dinnae", or similar Barbarian speech patterns. They reference the Tribunal, snow orcs, or Everfrost.

**Steps — Freeport:**
1. Use `#goto freportn` (North Freeport) or `#goto freporte` (East Freeport).
2. Target any Freeport Militia guard.
3. Say: `What is your job here?`
4. Expected: The guard is pragmatic, references Sir Lucan D'Lere, and is NOT described as virtuous. They should sound self-interested or dutiful to Lucan, not idealistic.

**Steps — Neriak (optional, requires Dark Elf or good faction):**
1. Use `#goto neriaka` (Neriak Foreign Quarter).
2. Target Guard V'Retta or any Dreadguard Outer.
3. Say: `Who do you serve?`
4. Expected: Cold, contemptuous response. References Innoruuk or Teir'Dal superiority. No warmth.

**Pass if:** Each city's guard speaks in a distinctly different cultural register — Halas with brogue, Freeport pragmatic-corrupt, Neriak cold/contemptuous.

**Fail if:** Guards from different cities give near-identical responses without cultural differentiation.

---

### Test 3: Quest Hint System — Off-Keyword Speech Handled

**Acceptance criterion:** "When a player speaks off-keyword to an upgraded quest NPC, the NPC
responds naturally in character and includes at least one valid quest keyword in [brackets]."

**Prerequisite:** GM character in South Qeynos. Quest scripts reloaded (`#reloadquests`).

**Steps:**
1. Use `#goto qeynos` and find Captain Tillin (NPC ID 1068).
2. Say `hail` — expected: scripted greeting fires. Note that NPC says something about Qeynos.
3. Now say something completely off-keyword: `What do you think about the weather today?`
4. Expected: Captain Tillin responds naturally in character with some reference to his concerns (gnolls, guard duty, corrupt guards) and includes at least one keyword in [brackets] such as [gnolls] or [corrupt guards]. He does NOT go silent.
5. Click the bracketed saylink (if it appears clickable) or type the keyword manually.
6. Expected: Scripted dialogue fires for that keyword.

**Pass if:** Off-keyword speech produces an in-character response with at least one [bracketed] keyword. Clicking/typing that keyword triggers the scripted dialogue path.

**Fail if:** Off-keyword speech produces silence. Or the NPC responds but with no [brackets]. Or clicking a bracket sends a saylink that triggers another off-keyword LLM response instead of scripted dialogue.

**GM commands for setup:**
```
#goto qeynos
#reloadquests
```

---

### Test 4: Quest Hint System — Rilca Leafrunner (qeytoqrg)

**Acceptance criterion:** Same as Test 3, in a different zone. Verifies the pattern works
beyond Qeynos and in a wilderness zone.

**Prerequisite:** GM character, `#goto qeytoqrg` (Qeynos Hills).

**Note:** Rilca Leafrunner spawns and despawns on a random 20-60 minute timer. If she is not
present, wait or use `#spawn 4057` as a substitute test with Holly Windstalker.

**Steps:**
1. Use `#goto qeytoqrg` and find Rilca Leafrunner (if present) or Holly Windstalker (NPC ID 4057).
2. For Rilca: say `hail`. Expected scripted greeting mentions "do something [for me]".
3. Say something off-keyword: `Are you a ranger? What do you do out here?`
4. Expected: Rilca responds in character about her ranger duties, gnoll intelligence, and the gnoll invasion plan, mentioning at least one keyword in [brackets] like [for me] or [invasion] or [Blackburrow] or [Surefall].
5. For Holly Windstalker (if using her): say off-keyword speech about the wolves or the hills. Expected: she responds about wolf packs or ranger duties with a bracketed keyword.

**Pass if:** Off-keyword speech produces a natural in-character response with [bracketed] keywords guiding the player.

**Fail if:** Silence on off-keyword speech.

**GM commands for setup:**
```
#goto qeytoqrg
#findnpc Rilca Leafrunner
```

---

### Test 5: Quest Hint System — Scripted Path Not Disrupted by Fallback

**Acceptance criterion:** "When a player speaks a valid keyword, the scripted quest dialogue fires
normally — the LLM fallback does not interfere."

**Prerequisite:** GM character in South Qeynos, Captain Tillin.

**Steps:**
1. Target Captain Tillin.
2. Say exactly: `gnolls`
3. Expected: Scripted dialogue fires. Captain Tillin says something scripted about gnolls from Blackburrow. The LLM is NOT invoked for keyword matches.
4. Say exactly: `gnoll fangs`
5. Expected: Scripted dialogue about the bounty quest fires.
6. Hand Captain Tillin a single gnoll fang (if available) by trading it to him.
7. Expected: Trade scripted response fires. You receive a Moonstone. No LLM involvement.

**Pass if:** All keyword-matched speech and trades produce scripted responses without LLM involvement. Responses fire instantly (no "thinking" indicator before scripted dialogue).

**Fail if:** Scripted keywords trigger LLM fallback instead of scripted response. Or trade event does not fire correctly.

**GM commands for setup:**
```
#goto qeynos
#summonitem 13915    -- Gnoll Fang (item ID from script)
```

---

### Test 6: Quest Hint System — Halas Tier 2 NPC

**Acceptance criterion:** "At least 20 quest scripts upgraded to Tier 2 with LLM fallback."
This test validates a non-Qeynos city upgrade works correctly.

**Prerequisite:** GM character in Halas.

**Steps:**
1. Use `#goto halas` and find Lysbith McNaff (shaman NPC near the Tribunal temple area).
2. Say `hail`. Expected: scripted greeting about serving Halas and the Wolves of the North.
3. Say something off-keyword: `What dangers face Halas this season?`
4. Expected: Lysbith responds in Barbarian brogue about snow orcs, ice goblins, and her bounty duties. She includes [bracketed] keywords like [serve Halas] or [ice goblins]. Her response uses "ye", "o'", or similar brogue.
5. Compare her voice to a Qeynos guard's response to verify cultural differentiation is preserved.

**Pass if:** Lysbith responds in character with brogue dialect and [bracketed] keywords. Her cultural voice is distinctly different from Qeynos NPCs.

**Fail if:** She responds in generic fantasy English without brogue. Or silence.

**GM commands for setup:**
```
#goto halas
#findnpc Lysbith McNaff
```

---

### Test 7: Soul Elements — Brave vs. Content NPC Contrast

**Acceptance criterion:** "Soul elements influence dialogue tone observably: a brave NPC speaks
more boldly about threats than a cowardly one; a restless NPC occasionally hints at wanderlust."

**Prerequisite:** Sidecar running with LLM_BUDGET_SOUL=150 (requires container restart). GM character.

**Steps:**
1. In South Qeynos, find Captain Tillin (soul: courage +2, loyalty +3, rooted disposition).
2. Say: `Do you ever worry about the gnolls breaking through?`
3. Expected: Tillin responds CONFIDENTLY — he confronts the threat directly, speaks with authority about defensive measures. His courage (+2) should produce bold language, not hedging.
4. Now find Guard Lasen or Guard Dunix (soul: via role defaults — guard courage +1, loyal, content).
5. Say the same: `Do you ever worry about the gnolls breaking through?`
6. Expected: The nameless guard responds professionally but without Tillin's confidence and personal investment. More generic duty-focused language.

**Pass if:** Tillin's response is noticeably more confident and personally invested than the generic guard's response to the same question.

**Fail if:** Both NPCs give identical responses. Or soul budget is still 0 (confirm via `docker exec akk-stack-npc-llm-1 env | grep LLM_BUDGET_SOUL`).

---

### Test 8: Soul Elements — Restless vs. Rooted Disposition

**Acceptance criterion:** "A restless NPC occasionally hints at wanderlust."

**Prerequisite:** Sidecar with LLM_BUDGET_SOUL=150. In North Qeynos or Qeynos area.

**Background:** The soul system uses restless/rooted disposition. The PRD example mentions Guard Noyan
(restless, hints at wider world) vs Guard Dunson (rooted, content). In our implementation:
- Guard Beren (ID 1090, soul: honesty +2, loyalty +2 — content disposition)
- Reinforcing example: Captain Tillin (ID 1068, rooted disposition)

Note: Not every restless NPC will hint at wanderlust in every response. You may need 2-3
interactions. Pick NPCs with "restless" or "curious" disposition in soul_elements.json.

**Steps:**
1. Find an NPC with "restless" or "curious" disposition. Suggest: Guard Calik (ID 1149, disposition: restless).
2. Ask about their daily routine: `What do you do on a typical day?`
3. Ask about adventure: `Have you ever thought about leaving Qeynos?`
4. Expected: A restless NPC should exhibit some hint of wanderlust, wondering about the wider world, or sighing about monotony. A rooted NPC (like Captain Tillin) should give a duty-focused answer with no wanderlust.

**Pass if:** Restless NPC shows measurable difference in disposition compared to a rooted NPC for the same question. Even subtle ("sometimes I wonder") counts.

**Fail if:** Both restless and rooted NPCs give identical responses with no disposition differentiation.

---

### Test 9: Soul Elements — Racial Identity Not Flattened

**Acceptance criterion:** "Soul elements do NOT flatten racial/cultural identity: an Iksar
guildmaster sounds fundamentally different from a High Elf guildmaster even when both have
similar soul trait scores."

**Prerequisite:** Ability to travel to Cabilis (Iksar city, Kunark) and Felwithe (High Elf city, Faydwer).
Note: Cabilis is hostile to non-Iksar characters. Use `#faction` or create an Iksar character.

**Steps:**
1. In Felwithe, target Kinool Goldsinger (Enchantment GM, ID 62020, piety +2, curiosity +2).
2. Say: `Tell me about your craft.`
3. Note the response — formal High Elf tone, Tunare references, patrician academic framing.
4. In Cabilis, target Harbinger Glosk (ID 82044, piety +3, loyalty +3, curiosity +2 — similar traits).
5. Say: `Tell me about your craft.`
6. Expected: Similar trait scores but entirely different cultural voice. Iksar cold/xenophobic tone, Cazic-Thule references, Sebilisian Empire framing, zero warmth.

**Pass if:** Same questions produce responses with distinctly different cultural voices despite similar soul scores. Felwithe: formal and refined. Cabilis: cold and xenophobic.

**Fail if:** Both NPCs sound like generic "wise teacher" archetypes without racial differentiation.

**GM commands for setup:**
```
#goto felwithe
#goto cabilis
```

---

### Test 10: Config Reload Endpoint

**Acceptance criterion:** "The sidecar handles hot-reload of config files without container restart."

**Prerequisite:** Container restarted with Phase 3 code. Sidecar running.

**Steps:**
1. Confirm the sidecar has the reload endpoint after restart:
   ```bash
   docker exec akk-stack-npc-llm-1 curl -s http://localhost:8100/openapi.json | python3 -c "import sys,json; d=json.load(sys.stdin); print('/v1/config/reload' in d['paths'])"
   ```
   Expected: `True`
2. Make a small test modification to `soul_elements.json` (e.g., add a comment-like unused key).
3. Call the reload endpoint:
   ```bash
   docker exec akk-stack-npc-llm-1 curl -s -X POST http://localhost:8100/v1/config/reload
   ```
4. Expected response: `{"status":"reloaded"}`
5. Revert the test modification.
6. Call reload again and verify it still returns `{"status":"reloaded"}`.

**Pass if:** The reload endpoint returns `{"status":"reloaded"}` and is accessible after container restart.

**Fail if:** Endpoint returns 404 (container not restarted). Or endpoint crashes the sidecar.

---

### Test 11: Config Reload — Malformed JSON Graceful Failure

**Acceptance criterion:** "Config reload with malformed JSON returns error without crashing sidecar."

**Prerequisite:** Container restarted. Sidecar running.

**Steps:**
1. Create a backup: `cp /mnt/d/Dev/EQ/akk-stack/npc-llm-sidecar/config/soul_elements.json /mnt/d/Dev/EQ/akk-stack/npc-llm-sidecar/config/soul_elements.json.bak`
2. Introduce invalid JSON: add a trailing comma at the end of a JSON object (making it invalid).
3. Call the reload endpoint:
   ```bash
   docker exec akk-stack-npc-llm-1 curl -s -X POST http://localhost:8100/v1/config/reload
   ```
4. Expected: Returns `{"status":"partial","errors":["assembler: ..."]}` or similar error response — NOT a 500 error, NOT a crash.
5. Verify sidecar is still responding: `docker exec akk-stack-npc-llm-1 curl -s http://localhost:8100/v1/health`
6. Restore backup: `cp /mnt/d/Dev/EQ/akk-stack/npc-llm-sidecar/config/soul_elements.json.bak /mnt/d/Dev/EQ/akk-stack/npc-llm-sidecar/config/soul_elements.json`
7. Call reload again to restore good state.

**Pass if:** Sidecar returns an error response for invalid JSON but does NOT crash. Subsequent health checks still return OK.

**Fail if:** Sidecar crashes or becomes unresponsive on malformed config.

---

### Test 12: Tier 1 Regression — Unscripted NPC Still Works

**Acceptance criterion:** "No regression in Tier 1 (unscripted NPC) conversation quality."

**Prerequisite:** GM character in any zone with unscripted NPCs.

**Steps:**
1. In South Qeynos, find an unscripted NPC (a nameless patrol guard with no local quest script).
2. Say: `hail`
3. Expected: The NPC responds via LLM (Tier 1 path through global_npc.lua). A thinking indicator appears briefly, then a response.
4. Ask: `What is your biggest concern today?`
5. Expected: In-character response about Qeynos guard duties, gnolls, or city security. No error message. No silence.

**Pass if:** Unscripted NPC responds naturally via LLM with correct faction tone and cultural voice.

**Fail if:** Unscripted NPC goes silent or produces an error.

---

### Test 13: Tier 2 Grobb NPC — Cultural Voice Verification

**Acceptance criterion:** "Quest hint system works across all race/class combinations."

**Prerequisite:** Troll or well-factioned character for Grobb access. GM character.

**Steps:**
1. Use `#goto grobb` to teleport to Grobb.
2. Find Basher Avisk or Bregna (upgraded Tier 2 Troll quest NPCs).
3. Say `hail` to get the scripted greeting.
4. Say something off-keyword: `What do you think about the frogloks?`
5. Expected: The Troll NPC responds in direct, simple language consistent with Troll culture. Cazic-Thule or fear-themed language. Possibly references Guk or froglok enemies. Includes a [bracketed] keyword from the script.
6. Voice should be distinctly different from a Qeynos guard's response.

**Pass if:** Troll NPC responds with species-appropriate voice and [bracketed] keyword.

**Fail if:** Troll NPC speaks like a Qeynos guard. Or silence.

**GM commands for setup:**
```
#goto grobb
#findnpc Basher Avisk
```

---

### Test 14: Shar Vahl Tier 2 NPC — Luclin Zone Verification

**Acceptance criterion:** "1-2 quest NPCs in a Kunark or Luclin zone."

**Prerequisite:** GM character with access to Shar Vahl (Luclin). Use the Nexus spire or `#goto sharvahl`.

**Steps:**
1. Use `#goto sharvahl` to teleport to Shar Vahl.
2. Find Dar Khura Pyjek or Vlarha Myticla (Tier 2 Vah Shir quest NPCs).
3. Say `hail` to get the scripted greeting.
4. Say something off-keyword: `What do you know about the Grimling War?`
5. Expected: The Vah Shir NPC responds in character about the Grimling War, Shar Vahl, and Vah Shir culture. Includes a [bracketed] keyword. Response references the moon Luclin or the Grimling threat appropriately.
6. Era check: The NPC should not mention Planes of Power, Plane of Knowledge, or any post-Luclin content.

**Pass if:** Vah Shir NPC responds with culturally appropriate dialogue and [bracketed] keyword. No era violations.

**Fail if:** Silence, or era violations (mentions PoK, etc.).

**GM commands for setup:**
```
#goto sharvahl
#findnpc Dar Khura Pyjek
```

---

### Test 15: Faction-Appropriate Tone with Soul Elements

**Acceptance criterion:** "Soul elements influence dialogue tone observably" while "faction political
constraints are not violated in any soul assignment."

**Prerequisite:** GM character with Amiable or better faction to Knights of Truth in Freeport.

**Steps:**
1. In North Freeport, find Groflah Steadirt or Kalatrina Plossen (Knights of Truth quest NPCs).
2. Say `hail` — get scripted greeting.
3. Say: `Do you ever fear Sir Lucan?`
4. Expected: Knights of Truth response: brave, honor-bound, references Mithaniel Marr, actively concerned about Lucan's corruption. Soul elements for these NPCs should have Courage +2, Honesty +2 which color their responses.
5. Now find a Freeport Militia guard (different faction).
6. Say: `What do you think of the Knights of Truth?`
7. Expected: Militia guard is pragmatic, dismisses the Knights as dangerous idealists. Does NOT sound like a Knight himself.

**Pass if:** Knights of Truth NPCs speak with courage and honor-bound tone. Militia guards sound pragmatic and Lucan-loyal. The contrast is clear.

**Fail if:** Both factions sound interchangeable.

---

### Test 16: Combined System — Backstory + Soul + Quest Hints Together

**Acceptance criterion:** "All three features work together: a backstoried quest NPC with soul
elements responds to off-keyword speech using quest hints, with personality influenced by soul elements."

**Prerequisite:** All Phase 3 features active (container restarted). Captain Tillin in South Qeynos.

**Captain Tillin integration profile:**
- Backstory: ID 1068, 15 years of service, knows every guard rotation, worries about Bloodsaber corruption
- Soul elements: courage +2, honesty +2, loyalty +3, piety +1, rooted disposition, desires recognition, fears Bloodsaber corruption
- Quest hints: gnolls, Blackburrow, gnoll fangs, corrupt guards

**Steps:**
1. Target Captain Tillin.
2. Say: `What troubles you most about your work?`
3. Expected: Response that weaves together all three layers:
   - Backstory: mentions specific details (Bloodsaber concern, fifteen-year career, Antonius Bayle IV)
   - Soul: spoken with confidence (courage), directly (honesty), with strong loyalty to Qeynos
   - Quest hints: naturally mentions [gnolls] or [corrupt guards] as specific concerns
   - Deity: references Rodcet Nife or the Prime Healer
4. The response should feel like a complete, multi-layered character — not a generic guard saying "duty is important."

**Pass if:** Response contains at least 2 of the following: (a) a specific personal detail from the backstory, (b) confident/direct speech consistent with courage +2, (c) a [bracketed] quest keyword, (d) a Rodcet Nife/Prime Healer reference.

**Fail if:** Response is generic guard flavor with no backstory depth or soul coloring.

---

### Edge Case Tests

### Test E1: LLM Generates Invalid Keyword in Brackets

**Risk from architecture plan:** "LLM generates [brackets] that don't match valid keywords.
Worst case: player clicks a saylink that doesn't match any keyword, which triggers the LLM
fallback again."

**Steps:**
1. Target any Tier 2 quest NPC (Captain Tillin works).
2. Say something vague: `Can you help me?`
3. If the NPC responds with a [bracketed keyword] that is NOT in the quest_hints valid keywords list, click it.
4. Expected: The bad saylink fires event_say with that text. No valid keyword matches. LLM fallback activates again. The NPC should respond naturally (not crash or loop forever). The second response may guide you back to valid keywords.

**Pass if:** Clicking an invalid saylink produces another natural LLM response, not silence or a crash. The loop terminates because the player must actively click each time.

**Fail if:** The bad saylink causes an error, crash, or infinite automated loop.

---

### Test E2: Quest Hint NPC When Sidecar Is Down

**Risk from architecture plan:** "If sidecar is down, off-keyword speech produces silence (same
as current Tier 1 failure mode)."

**Steps:**
1. Stop the sidecar: `docker exec akk-stack-npc-llm-1 kill 1` or use Spire to stop the npc-llm service.
2. Target a Tier 2 quest NPC (Captain Tillin).
3. Say `hail`. Expected: scripted dialogue fires normally (sidecar not involved for keyword matches).
4. Say something off-keyword: `Tell me about the city.`
5. Expected: NPC goes silent (no response). This is acceptable degraded behavior. The NPC should NOT crash the zone.
6. Restart the sidecar: `make up-llm` or via Spire.
7. Use `#reloadquests` in-game to reload scripts after sidecar restart.
8. Repeat the off-keyword test — expected: LLM fallback works again.

**Pass if:** Scripted keywords work with sidecar down. Off-keyword produces silence (not a crash). Full functionality restored after sidecar restart.

**Fail if:** Zone crashes when sidecar is down and NPC tries to call it.

---

### Test E3: Token Budget — Prompt With All Layers Active

**Risk from architecture plan:** "Token budget total stays within LLM_N_CTX=2048 for prompts
that include all layers."

**Steps:**
1. Enable debug prompts temporarily:
   ```bash
   # Edit .env to set LLM_DEBUG_PROMPTS=true, then restart sidecar
   ```
2. Trigger Captain Tillin off-keyword to produce a full prompt (backstory + soul + quest hints + memory if any).
3. Check sidecar logs for the "Prompt assembled: N tokens" log line.
4. Expected: Total token count under 1550 (leaving 500 for LLM_N_CTX=2048 response).

**Pass if:** Full prompt with all layers fits under 1550 tokens.

**Fail if:** Total prompt exceeds 1550 tokens, leaving no room for the model response.

**GM commands for setup:**
```
# No in-game command needed. Check sidecar logs:
docker logs akk-stack-npc-llm-1 2>&1 | grep "Prompt assembled"
```

---

## Rollback Instructions

All Phase 3 changes are non-destructive. No database changes were made. Rollback steps:

**To revert config files (backstories and soul elements):**
```bash
cd /mnt/d/Dev/EQ/akk-stack
git checkout npc-llm-sidecar/config/global_contexts.json
git checkout npc-llm-sidecar/config/soul_elements.json
```

**To revert quest scripts:**
```bash
git checkout server/quests/
```

**To revert Lua bridge:**
```bash
git checkout server/quests/lua_modules/llm_bridge.lua
```

**To revert sidecar Python code:**
```bash
git checkout npc-llm-sidecar/app/
git checkout npc-llm-sidecar/docker-compose.npc-llm.yml
```

**To revert .env Phase 3 vars:**
```bash
git checkout akk-stack/.env
```

After any revert, restart the sidecar:
```bash
make down-llm && make up
```

---

## Blockers

| # | Blocker | Severity | Responsible Expert | Status |
|---|---------|----------|-------------------|--------|
| 1 | Container not restarted after Phase 3 code deployment. Soul elements disabled (LLM_BUDGET_SOUL=0 in running container). /v1/config/reload returns 404. All Phase 3 sidecar features inactive. | Critical | sidecar-expert (restart) or user (make down-llm && make up) | Open |
| 2 | NPC ID 1077 has Captain Tillin backstory but 1077 = Danon Fletcher (merchant). The backstory and soul elements for 1077 will apply to the wrong NPC. Captain Tillin's correct ID is 1068 (which also has correct data). The erroneous 1077 entry should be removed or corrected. | High | content-author | Open |
| 3 | soul_elements.json has 5 duplicate NPC type ID keys (9100, 75075, 42019, 82044, 155151). Python json.load silently discards the first occurrence, keeping the last. The later entries appear to be the more complete versions, but this should be resolved to a single authoritative entry per NPC. | Medium | content-author | Open |
| 4 | Status.md shows Task 6 (backstory authoring) as "In Progress" and Task 7 (soul elements) as "Not Started" but both are complete. Status tracking was not updated to reflect completion. | Low | content-author | Open |

---

## Recommendations

- After fixing Blocker 1 (container restart), re-run all in-game tests. The soul element system
  was never active in the running container — you are effectively seeing Phase 2.5 behavior until restart.

- For Blocker 2 (NPC ID 1077): Remove the `"1077"` entry from both `global_contexts.json` and
  `soul_elements.json`. Captain Tillin's data is already correct under ID `1068`. The entry for
  `1077` (Danon Fletcher) should instead receive a Danon Fletcher-appropriate merchant backstory
  if desired, or be left with no override.

- For Blocker 3 (duplicate soul_elements.json keys): Remove the first (earlier, less complete)
  occurrence of each duplicate. The second occurrence in each case has more specific and richer
  data.

- The Tier 2 quest script pattern is well-implemented and consistent across all 31 scripts.
  The zone coverage (11 zones across 7 starting cities) is good for a representative set.
  Full conversion of all quest NPCs remains future work per the PRD non-goals.

- The 137 backstory overrides significantly exceed the PRD's 50-NPC minimum and cover all
  15 starting cities. Content quality could not be validated through automated checks — the
  in-game tests above will reveal if any backstories produce lore-incorrect dialogue.

- Oggok has only 3 backstory entries and Ak'Anon has 5 — both below other cities. These cities
  have fewer named quest NPCs so the lower count may be appropriate, but worth noting for
  future content passes.
