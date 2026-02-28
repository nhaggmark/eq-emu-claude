# NPC LLM Integration — Test Plan

> **Feature branch:** `feature/npc-llm-integration`
> **Author:** game-tester
> **Date:** 2026-02-23
> **Server-side result:** PASS WITH WARNINGS

---

## Test Summary

This test plan validates the NPC LLM Integration Phase 1 feature, which brings
conversational AI to approximately 45,000 unscripted NPCs. The feature consists
of:

- A Python FastAPI sidecar running Mistral 7B (GGUF) for inference
- Three Lua modules: `llm_bridge.lua`, `llm_config.lua`, `llm_faction.lua`
- A modified `global/global_npc.lua` with an `event_say` handler
- A Docker compose overlay (`docker-compose.npc-llm.yml`)
- Zone cultural context data (`zone_cultures.json`, 25 zone keys / 15 cities)

No C++ changes were made. No database schema changes were made. The feature is
fully reversible by stopping the sidecar container and restoring `global_npc.lua`.

### Inputs Reviewed

- [x] PRD at `game-designer/prd.md`
- [x] Architecture plan at `architect/architecture.md`
- [x] status.md — Lua modules and global_npc.lua marked Complete; Python
  sidecar, Docker files, and integration test listed as Not Started (but all
  files are present on disk — the agents completed the work without updating
  status.md)
- [x] Acceptance criteria identified: 15 criteria

---

## Part 1: Server-Side Validation

### Results

| # | Check | Result | Details |
|---|-------|--------|---------|
| 1 | Docker compose config (npc-llm overlay alone) | PASS | `docker compose -f docker-compose.npc-llm.yml config --quiet` exits 0 |
| 2 | Docker compose config (full combined stack) | PASS | All three compose files validate cleanly together |
| 3 | Python syntax: main.py | PASS | `python3 -m py_compile` exits 0 |
| 4 | Python syntax: models.py | PASS | `python3 -m py_compile` exits 0 |
| 5 | Python syntax: prompt_builder.py | PASS | `python3 -m py_compile` exits 0 |
| 6 | Python syntax: post_processor.py | PASS | `python3 -m py_compile` exits 0 |
| 7 | Lua syntax: llm_bridge.lua | PASS | `luajit -bl` exits 0 in eqemu container |
| 8 | Lua syntax: llm_config.lua | PASS | `luajit -bl` exits 0 in eqemu container |
| 9 | Lua syntax: llm_faction.lua | PASS | `luajit -bl` exits 0 in eqemu container |
| 10 | Lua syntax: global_npc.lua | PASS | `luajit -bl` exits 0 in eqemu container |
| 11 | Docker image build | PASS | `make build-llm` exits 0 (26s build time) |
| 12 | Sidecar container starts | PASS | Container status "Up (healthy)" after start |
| 13 | Health endpoint responds from eqemu container | PASS | `curl http://npc-llm:8100/v1/health` returns 200 |
| 14 | Health endpoint: model_loaded field | WARN | Returns `"model_loaded": false` — model file name mismatch (see below) |
| 15 | Chat endpoint: graceful null on model not loaded | PASS | Returns `{"response":null,"error":"Model not loaded"}` |
| 16 | curl availability in eqemu-server container | PASS | `/usr/bin/curl` v7.88.1 present (Debian bookworm) |
| 17 | zone_cultures.json: valid JSON | PASS | Parses cleanly, no syntax errors |
| 18 | zone_cultures.json: key count | PASS | 25 zone keys present |
| 19 | zone_cultures.json: all 15 PRD cities covered | PASS | All subzone keys present (qeynos/qeynos2/qcat, etc.) |
| 20 | zone_cultures.json: required fields | PASS | All entries have culture, patron_deity, key_threats, atmosphere |
| 21 | Post-processor: era blocklist present | PASS | 12 blocklist patterns compiled |
| 22 | Post-processor: technology blocked | PASS | Sentence containing "technology" stripped |
| 23 | Post-processor: economy blocked | PASS | Sentence containing "economy" stripped — empty string returned for all-violation response |
| 24 | Post-processor: Plane of Knowledge blocked | PASS | Sentence stripped cleanly |
| 25 | Post-processor: quote stripping | PASS | Leading/trailing quotes removed from LLM output |
| 26 | Post-processor: length truncation | PASS | 690-char input truncated to 443 chars at sentence boundary |
| 27 | Post-processor: stress NOT in blocklist | WARN | PRD lists "stress" as a forbidden modern concept but post_processor.py blocks "anxiety" instead. The word "stress" in an NPC response would not be filtered. |
| 28 | sidecar_url DNS matches Docker service name | PASS | `llm_config.lua` uses `http://npc-llm:8100` matching the `services.npc-llm` key in compose |
| 29 | Makefile targets present | PASS | `up-llm`, `down-llm`, `build-llm` all present in Makefile |
| 30 | World log: no LLM errors | PASS | No LLM or Lua errors in world log |
| 31 | Zone logs: no LLM errors | PASS | No relevant errors in qeynos/freporte zone logs |
| 32 | Build verification (C++) | N/A | No C++ changes in Phase 1 |
| 33 | DB integrity | N/A | No database schema changes in Phase 1 |
| 34 | Spawn/loot chain validation | N/A | No spawn or loot changes in Phase 1 |

### Detail: Warning #14 — Model File Name Mismatch (BLOCKER)

The model file on disk is named:

```
akk-stack/npc-llm-sidecar/models/Mistral-7B-Instruct-v0.3-Q4_K_M.gguf
```

The `.env` file specifies:

```
LLM_MODEL_PATH=/models/mistral-7b-instruct-v0.3.Q4_K_M.gguf
```

The filenames differ in case: `Mistral-7B-Instruct-v0.3-Q4_K_M.gguf` vs
`mistral-7b-instruct-v0.3.Q4_K_M.gguf`. Inside the Docker container (Linux
filesystem, case-sensitive), the file is not found. The sidecar logs:

```
ERROR:npc-llm:Model file not found: /models/mistral-7b-instruct-v0.3.Q4_K_M.gguf
```

The sidecar starts successfully and the health endpoint responds, but
`model_loaded` is `false`. The `/v1/chat` endpoint returns
`{"response":null,"error":"Model not loaded"}`. All in-game NPC conversations
will silently fail (graceful degradation is working, but no LLM responses will
be generated until this is fixed).

**Fix:** Either rename the file to match the `.env` value, or update `.env` to
match the actual filename. See Blockers section.

### Detail: Warning #27 — "stress" Not in Era Blocklist

The PRD appendix lists "stress" as a forbidden modern concept (in-world
equivalent: "troubled thoughts"). The post-processor blocks "anxiety" but not
"stress". An NPC response containing "The stress of battle weighs on me" would
pass through unfiltered.

This is a minor quality gap — the system prompt already instructs the LLM not to
use modern concepts, so "stress" in a response is unlikely but not impossible.
Adding `r"\bstress\b"` to `ERA_BLOCKLIST` in `post_processor.py` would close
this gap. See Blockers section (rated Medium, non-blocking for in-game testing).

### Database Integrity

No new database tables or schema changes were introduced in Phase 1. The
`data_buckets` table (used for per-NPC opt-out) has been verified to exist with
the expected schema:

```sql
-- data_buckets schema confirmed:
-- key VARCHAR(100), value TEXT, character_id BIGINT, npc_id INT, etc.
```

No queries needed — the opt-out mechanism uses existing infrastructure.

### Quest Script Syntax

| Script | Language | Result | Notes |
|--------|----------|--------|-------|
| `lua_modules/llm_bridge.lua` | Lua | PASS | luajit -bl exits 0 |
| `lua_modules/llm_config.lua` | Lua | PASS | luajit -bl exits 0 |
| `lua_modules/llm_faction.lua` | Lua | PASS | luajit -bl exits 0 |
| `global/global_npc.lua` | Lua | PASS | luajit -bl exits 0 |
| `app/main.py` | Python | PASS | py_compile exits 0 |
| `app/models.py` | Python | PASS | py_compile exits 0 |
| `app/prompt_builder.py` | Python | PASS | py_compile exits 0 |
| `app/post_processor.py` | Python | PASS | py_compile exits 0 |

### Log Analysis

| Log File | Errors Found | Severity | Related To |
|----------|-------------|----------|------------|
| `world_143.log` | None | N/A | Clean world log, no LLM entries |
| `zone/qeynos_*.log` | None | N/A | No LLM or Lua errors |
| `zone/freporte_*.log` | None | N/A | No LLM or Lua errors |
| `npc-llm container logs` | Model file not found | HIGH | Model filename case mismatch (see Warning #14) |

### Rule Validation

No new server rules were created. All configuration is in `llm_config.lua`.
No `ruletypes.h` changes. No `eqemu_config.json` changes.

### Build Verification

Phase 1 contains no C++ changes. No build required.

---

## Part 2: In-Game Testing Guide

### Prerequisites

Before running any in-game tests, the model filename mismatch must be resolved.
See Warning #14 above. To fix before testing:

```bash
# Option A: Rename the model file to match .env
mv /mnt/d/Dev/EQ/akk-stack/npc-llm-sidecar/models/Mistral-7B-Instruct-v0.3-Q4_K_M.gguf \
   /mnt/d/Dev/EQ/akk-stack/npc-llm-sidecar/models/mistral-7b-instruct-v0.3.Q4_K_M.gguf

# Then restart the sidecar
cd /mnt/d/Dev/EQ/akk-stack && make down-llm && make up-llm

# Verify model loaded (wait 90 seconds for startup)
docker exec akk-stack-eqemu-server-1 curl -s http://npc-llm:8100/v1/health
# Expected: {"status":"ok","model_loaded":true,"model_name":"..."}
```

**General Setup:**

- Use a GM character or a character with `/dev` access to run `#` commands
- All tests assume the sidecar is running with the model loaded
- Use `#reloadquests` after any script changes (no server restart needed)
- Tests can be run in any order; hostile cooldown tests need 60 seconds between
  them or a different NPC

**Standard GM Setup Sequence:**

```
#level 50
#faction [factionid] [value]   -- adjust faction as needed per test
#goto [zone] [x] [y] [z]      -- teleport to NPC location
```

---

### Test 1: Unscripted NPC Responds to Speech

**Acceptance criterion AC1:** A player targets an unscripted NPC (e.g., a
generic guard with no quest file) and types `/say Hello`. The NPC responds with
a contextually appropriate in-character message within 3 seconds.

**Prerequisite:** Sidecar running with model loaded. Character at any level.
Faction with Freeport Militia at Indifferent (5) or better.

**Target NPC:** Guard Mizraen (NPC ID 9015) in West Freeport
- Verified: no quest script file exists for this NPC
- INT: 112 (well above the 30 threshold)
- Body type: 1 (humanoid)
- Coordinates: x=-589, y=-270, z=-24

**Steps:**

1. Log in with any character.
2. Run: `#zone freportw`
3. Run: `#goto freportw -589 -270 -24`
4. Target Guard Mizraen (click or `/target Guard_Mizraen`).
5. Confirm you are within 200 units of the NPC.
6. Type: `/say Hello, any trouble around here lately?`
7. Watch the chat window for two messages:
   - Immediately: an emote-style "thinking" message (e.g., "Guard Mizraen
     considers your words carefully...")
   - Within 1-3 seconds: a spoken response from Guard Mizraen

**Expected result:** Guard Mizraen speaks a 1-3 sentence in-character response
reflecting Freeport's cynical militia culture. Example: "Trouble? The Deathfist
orcs are always a concern on the road, but that is what Lucan pays us for —
though the pay has not kept up with the trouble."

**Pass if:** NPC says something contextually appropriate within 3 seconds of the
thinking indicator.

**Fail if:** NPC says nothing at all, OR a Lua error appears in chat, OR the
thinking indicator appears but no response follows after 5+ seconds.

**GM commands for setup:**
```
#zone freportw
#goto freportw -589 -270 -24
```

---

### Test 2: Scripted NPCs Are Unaffected

**Acceptance criterion AC2:** A player targets an NPC with an existing quest
script and types the expected keywords. The NPC responds with its scripted
dialogue, exactly as before.

**Prerequisite:** Any character with Indifferent or better faction to Freeport
Militia.

**Target NPC:** Armorer Dellin (NPC ID 9007) in West Freeport
- Confirmed: has quest script at
  `akk-stack/server/quests/freportw/Armorer_Dellin.lua`
- Script handles "hail" keyword with specific scripted dialogue

**Steps:**

1. Run: `#zone freportw`
2. Run: `#goto freportw -135 -87 6`
3. Target Armorer Dellin.
4. Type: `/say Hail`
5. Observe the response.

**Expected result:** Armorer Dellin says: "Hail!! If you be a new reserve member
then show me your Militia Armory Token. If you are not yet initiated then I
suggest you head to the Toll Gate in the Commonlands and speak with Guard Valon."

This is the exact scripted text. The LLM must NOT have been invoked.

**Pass if:** The exact scripted response appears. Response is instant (no 1-3
second thinking indicator delay).

**Fail if:** An LLM-generated response appears instead of the scripted text, OR
a thinking indicator emote appears before the response (which would indicate
the LLM was invoked).

**GM commands for setup:**
```
#zone freportw
#goto freportw -135 -87 6
```

---

### Test 3: Intelligence Filter Silences Low-INT NPCs

**Acceptance criterion AC3:** A player targets an animal or mindless creature
(INT < 30) and speaks. No LLM response occurs.

**Prerequisite:** Any character. Sidecar running.

**Target NPC:** a Koalindl (NPC ID 2005) in South Qeynos
- INT: 8 (well below the 30 threshold)
- Body type: 21 (Animal)
- Coordinates: x=-392, y=-113, z=-10

**Steps:**

1. Run: `#zone qeynos2`
2. Run: `#goto qeynos2 -392 -113 -10`
3. Target "a Koalindl".
4. Type: `/say Hello there, little creature.`
5. Wait 5 seconds.

**Expected result:** No response. No thinking indicator. The NPC remains silent,
exactly as before the feature was added.

**Pass if:** Complete silence from the NPC for 5 seconds after speaking.

**Fail if:** Any message appears in chat attributed to the NPC, or a thinking
indicator emote appears.

**GM commands for setup:**
```
#zone qeynos2
#goto qeynos2 -392 -113 -10
```

**Secondary test (INT check only, not animal body type):**

A klicnik warrior (NPC ID 2015, body type 22 Insect, INT 20) at coordinates
x=482, y=1036, z=2 in qeynos2 should also be silent. Run the same test against
this NPC to verify the body type exclusion works independently of INT.

---

### Test 4: Faction Affects Tone (Ally vs Scowling)

**Acceptance criterion AC4:** A player with Ally faction speaks to a guard and
receives a warm, helpful response. The same NPC type at Scowling faction
produces only a hostile emote with no verbal response.

**Prerequisite:** Two separate tests — one at Ally faction, one at Scowling.
Use Guard Hrakin (NPC ID 9019) in West Freeport (x=-107, y=-430, z=-24,
unscripted). Faction: Freeport Militia (faction ID 330).

**Part A — Ally Faction:**

1. Run: `#zone freportw`
2. Run: `#faction 330 2000` (sets Ally faction with Freeport Militia)
3. Run: `#goto freportw -107 -430 -24`
4. Target Guard Hrakin.
5. Type: `/say Any news from the Commonlands road?`

**Expected result:** Guard Hrakin responds warmly — shares information freely,
may reference threats, treats you as someone worth talking to. Tone is
cooperative and forthcoming.

**Part B — Scowling Faction:**

6. Run: `#faction 330 -2000` (sets Scowling faction)
7. Wait for faction to register (or zone out and back in).
8. Target Guard Hrakin again.
9. Type: `/say Hello there.`

**Expected result:** Guard Hrakin performs a hostile emote only (e.g., "Guard
Hrakin glares at you with undisguised contempt."). No verbal response follows.

**Pass if (Part A):** Warm, multi-sentence response with helpful information.
**Pass if (Part B):** Hostile emote appears, no verbal text from NPC.

**Fail if (Part A):** Cold, terse, or hostile response.
**Fail if (Part B):** Any verbal response from NPC, OR no response at all
(missing emote).

**GM commands for setup:**
```
#zone freportw
#faction 330 2000
#goto freportw -107 -430 -24
```

---

### Test 5: Threatening vs Scowling Distinction

**Acceptance criterion AC5:** A player at Threatening faction receives a terse
verbal warning. A player at Scowling faction receives only a hostile emote and
no verbal response.

**Prerequisite:** Use Guard Hrakin (NPC ID 9019) or Guard Mizraen (NPC ID 9015)
in West Freeport. Faction: Freeport Militia (faction ID 330).

**Part A — Threatening Faction (faction level 8):**

1. Run: `#zone freportw`
2. Run: `#faction 330 -900` (approximately Threatening range)
3. Run: `#goto freportw -107 -430 -24`
4. Target Guard Hrakin.
5. Type: `/say I just want to pass through.`

**Expected result:** Guard Hrakin speaks a terse, menacing warning — something
like "You have three seconds to state your business or you will regret it." One
brief verbal response. The NPC uses words but is clearly hostile.

**Part B — Scowling Faction (faction level 9):**

6. Run: `#faction 330 -2000`
7. Zone out and back in, or target a fresh instance.
8. Type: `/say Hello.`

**Expected result:** Guard Hrakin performs a hostile emote (e.g., "glares at you
with undisguised contempt") but says NOTHING verbally. This is the key
distinction: Threatening speaks briefly, Scowling does not speak at all.

**Pass if (Part A):** Brief verbal warning (1 sentence), no helpful information.
**Pass if (Part B):** Hostile emote only, zero verbal text.

**Fail if:** Either faction level produces the wrong type of response (verbal
where emote-only expected, or emote-only where verbal warning expected).

**Faction tuning note:** EQ faction levels are not direct database values — use
#faction to set approximate raw values. Threatening is approximately -700 to
-1049, Scowling is -1050 to -2000.

---

### Test 6: Typing Indicator Appears

**Acceptance criterion AC6:** When the player speaks to an LLM-enabled NPC, an
emote appears immediately (before the LLM response) indicating the NPC is
"thinking." The emote is visible only to the speaker.

**Prerequisite:** Sidecar running with model loaded. At least Indifferent
faction. A second player or observer in the same zone is ideal for verifying
speaker-only visibility.

**Target NPC:** Guard Mizraen (NPC ID 9015) or Guard Hrakin (NPC ID 9019) in
West Freeport.

**Steps:**

1. Run: `#zone freportw`
2. Run: `#goto freportw -589 -270 -24`
3. Target Guard Mizraen.
4. Type: `/say What dangers lurk near the docks?`
5. Watch the chat window timing carefully.

**Expected result:** Two messages appear in sequence:
1. Immediately (< 0.5 seconds): an emote message like "Guard Mizraen considers
   your words carefully..." — visible only to you
2. After 1-3 seconds: the NPC's verbal response via e.self:Say()

**If a second player is present in the zone:**
- The thinking indicator should NOT appear in their chat window
- The NPC's spoken response WILL appear in their chat window (it broadcasts to
  all within 200 units via e.self:Say())

**Pass if:** Thinking indicator appears immediately before the LLM response, and
is not visible to other players in the zone.

**Fail if:** No thinking indicator appears, OR the thinking indicator appears in
other players' chat windows, OR the thinking indicator appears but no NPC
response follows.

---

### Test 7: Sidecar Health Check

**Acceptance criterion AC7:** The LLM sidecar's /v1/health endpoint returns a
successful status indicating the model is loaded and ready.

**Prerequisite:** Model filename mismatch must be resolved (see Warning #14 in
server-side results). After resolving:

**Server-side verification (run from host or eqemu container):**

```bash
# From host:
docker exec akk-stack-npc-llm-1 curl -s http://localhost:8100/v1/health

# From inside eqemu-server container:
docker exec akk-stack-eqemu-server-1 curl -s http://npc-llm:8100/v1/health
```

**Expected response:**
```json
{"status": "ok", "model_loaded": true, "model_name": "mistral-7b-instruct-v0.3.Q4_K_M"}
```

**Current status:** As of validation, health returns `"model_loaded": false`
due to the filename mismatch. This test cannot fully PASS until the blocker is
resolved.

**Pass if:** `"status": "ok"` and `"model_loaded": true` in the response.
**Fail if:** `"model_loaded": false` or connection refused.

---

### Test 8: Graceful Degradation (Sidecar Offline)

**Acceptance criterion AC8:** If the LLM sidecar is stopped or unreachable,
speaking to an unscripted NPC produces no response (no error, no crash, no chat
spam).

**Prerequisite:** Stop the sidecar container while keeping the game server
running.

**Setup:**
```bash
cd /mnt/d/Dev/EQ/akk-stack
make down-llm
```

**Steps:**

1. Confirm sidecar is stopped: `docker ps | grep npc-llm` should show nothing.
2. Log in with any character.
3. Run: `#zone freportw`
4. Target Guard Mizraen (NPC ID 9015, x=-589 y=-270 z=-24).
5. Type: `/say Hello, any news?`
6. Wait 5-6 seconds (allow time for curl timeout — configured at 3 seconds).
7. Check chat window carefully.

**Expected result:** No response from the NPC. No error messages in chat. No
Lua errors. The NPC behaves exactly as it did before the feature existed —
completely silent. The zone does not crash. Other game functions work normally.

**Additional verification:** After the test, check the zone log for any errors:
```bash
ls -t /mnt/d/Dev/EQ/akk-stack/server/logs/zone/freportw_*.log | head -1
# Then search for errors in that file
```

**Pass if:** Complete silence, no errors, zone stable.
**Fail if:** Any Lua error in chat, zone crash, or server error in logs.

**Restore sidecar after test:**
```bash
cd /mnt/d/Dev/EQ/akk-stack && make up-llm
# Wait 90 seconds for model to load
```

---

### Test 9: Per-NPC Opt-Out via Data Bucket

**Acceptance criterion AC9:** Setting the `llm_enabled` data bucket to `0` for
a specific NPC type ID causes that NPC to stop responding via LLM.

**Prerequisite:** Sidecar running with model loaded. Choose Guard Mizraen
(NPC type ID 9015).

**Steps:**

1. First confirm the NPC responds normally:
   - `#zone freportw`
   - `#goto freportw -589 -270 -24`
   - Target Guard Mizraen
   - `/say Hello` — confirm a response appears

2. Set the opt-out data bucket from the server database:
   ```sql
   -- Run this query to opt out NPC type ID 9015
   docker exec akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq -e \
     "INSERT INTO data_buckets (\`key\`, value, npc_id) VALUES ('llm_enabled-9015', '0', 9015) ON DUPLICATE KEY UPDATE value='0';"
   ```

   Alternatively, if there is a GM command for data buckets:
   ```
   #databucket set llm_enabled-9015 0
   ```

3. Run `#reloadquests` to ensure the new bucket value is picked up.

4. Target Guard Mizraen again (repop with `#repop` if needed).

5. Type: `/say Hello again.`

6. Wait 5 seconds.

**Expected result:** No response. No thinking indicator. Guard Mizraen is now
silent even though the sidecar is running.

**Pass if:** NPC is silent after opt-out is set.

**Fail if:** NPC still responds after the data bucket is set.

**Cleanup after test (restore opt-in):**
```sql
docker exec akk-stack-mariadb-1 mysql -ueqemu -p'ZSF4Iz1Eht0eZ2Qn68bAAEXln6Prc79' peq -e \
  "DELETE FROM data_buckets WHERE \`key\` = 'llm_enabled-9015';"
```

---

### Test 10: In-Character and Era-Appropriate Responses

**Acceptance criterion AC10:** Over 10 test conversations with various NPC
types across multiple cities, all responses are in-character, era-appropriate,
and do not reference post-Luclin content, real-world concepts, or game mechanics
by mechanical names.

**Prerequisite:** Sidecar running with model loaded.

**Test NPCs and locations:**

| NPC | Zone | Coordinates | Type |
|-----|------|-------------|------|
| Guard Mizraen (ID 9015) | freportw | -589, -270, -24 | Guard |
| Guard Hrakin (ID 9019) | freportw | -107, -430, -24 | Guard |
| Ania Klephia (ID 2082) | qeynos2 | 359, 115, 4 | Bard |
| Anehan Treol (ID 1158) | qeynos | -119, 120, 4 | Bard |
| Adon McMarrin (ID 29034) | halas | -460, 641, 4 | Warrior |
| Conner O'Cooper (ID 29040) | halas | -263, 87, 4 | Warrior |
| Bello Fruegnos (ID 9132) | freportw | -583, -10, -24 | Wizard |

**For each NPC, ask one question from this list:**

- "What should I watch out for around here?"
- "Tell me about your city."
- "What is your duty here?"
- "Who rules this land?"
- "What dangers lurk nearby?"
- "Tell me about your order."
- "What do you know about the gnolls?"
- "What are your beliefs?"
- "What news from the road?"
- "What can you tell me about Luclin?" (era compliance check)

**Checklist for each response:**
- [ ] Stays in character (NPC speaks as their race/class/location dictates)
- [ ] References city-appropriate content (Freeport = Lucan/Militia, Qeynos = Antonius Bayle, Halas = northern warrior culture)
- [ ] No post-Luclin references (Plane of Knowledge, Planes of Power, Berserker)
- [ ] No modern real-world concepts (technology, democracy, economy, mental health)
- [ ] No game mechanics by mechanical name (does not say "hit points" or "mana")
- [ ] Response is 1-3 sentences (under ~450 characters)
- [ ] For Luclin question: NPC expresses wonder, unease, or ignorance rather than casual familiarity

**Pass if:** All 10 conversations meet all checklist items.
**Fail if:** Any response contains a forbidden term, breaks character, or
references post-Luclin content.

---

### Test 11: City Culture Reflected in NPC Voice

**Acceptance criterion AC11:** A guard in Qeynos sounds noticeably different
from a guard in Freeport. An Erudin scholar sounds different from an Oggok
merchant.

**Prerequisite:** Sidecar running with model loaded.

**Comparison pair 1: Qeynos vs Freeport guards**

Ask the same question to both:

- Guard in Qeynos (any unscripted guard, e.g., ID 2122 Guard Liben in
  qeynos2, INT 20 — actually this NPC is below threshold; use the INT-eligible
  NPCs such as Astaed Wemor at ID 2100, class 22, in qeynos2 at -471, -175, 34)
- Guard Mizraen (ID 9015) in West Freeport

Ask: `/say What is your duty here?`

**Expected distinctions:**
- Qeynos guard: civic duty, references Rodcet Nife or Antonius Bayle, uses
  terms like "citizen," formal and paternalistic tone
- Freeport guard: mercenary, world-weary, references Lucan D'Lere or the
  Militia, cynical and pragmatic tone

**Comparison pair 2: High culture vs simple culture**

- Ania Klephia (Bard in Qeynos, ID 2082, qeynos2 at 359, 115, 4)
- Conner O'Cooper (Warrior in Halas, ID 29040, halas at -263, 87, 4)

Ask: `/say Tell me about yourself.`

**Expected distinctions:**
- Qeynos bard: musical references, civic Qeynos pride, more elaborate speech
- Halas warrior: direct, simple sentences, northern warrior honor references

**Pass if:** Responses from different cities/cultures sound noticeably different
in tone, references, and vocabulary.

**Fail if:** Both NPCs sound identical or interchangeable.

---

### Test 12: Response Length is Appropriate

**Acceptance criterion AC12:** All LLM responses fit within the EQ chat window
without excessive wrapping. Responses are 1-3 sentences (under ~450 characters).

**Prerequisite:** Sidecar running with model loaded.

**Steps:**

1. Over the course of Tests 10 and 11, count the sentences in each response.
2. Estimate character length of each response (450 characters is approximately
   3-4 average chat lines in the EQ chat window).
3. Note any response that exceeds 3 sentences or appears excessively long.

**Also verify the post-processor truncation works:**

The post-processor's `truncate_at_sentence()` function has been verified to
truncate at sentence boundaries. Confirm no responses in-game appear cut off
mid-sentence (which would indicate a truncation occurred without finding a
sentence boundary).

**Pass if:** All responses are 1-3 sentences and fit comfortably in the chat
window without requiring excessive scrolling.

**Fail if:** Any response exceeds 4+ sentences, OR any response appears
truncated mid-word or mid-sentence.

---

### Test 13: Hostile Cooldown Works

**Acceptance criterion AC13:** A player at Threatening or Scowling faction
speaks to a hostile NPC, receives a warning or emote, then speaks again within
60 seconds. The second message gets no response.

**Prerequisite:** Threatening or Scowling faction with Freeport Militia. Guard
Hrakin (NPC ID 9019) in West Freeport (x=-107, y=-430, z=-24).

**Steps:**

1. Run: `#zone freportw`
2. Run: `#faction 330 -900` (Threatening faction)
3. Run: `#goto freportw -107 -430 -24`
4. Target Guard Hrakin.
5. Type: `/say I just need directions.`
6. Note the response (brief hostile warning or emote — this is the first
   interaction, which is allowed).
7. Immediately (within 10 seconds) type: `/say Please, just the directions.`
8. Wait 5 seconds.

**Expected result:** The second message produces no response at all. The hostile
cooldown (60 seconds per `llm_config.lua`) is in effect.

**Steps to verify cooldown expiry:**

9. Wait 65 seconds after the first interaction.
10. Type: `/say One more question.`

**Expected result:** Guard Hrakin responds again (cooldown has expired).

**Pass if:** Second message (within 60s) gets no response. Message after 65s
gets a response.

**Fail if:** Second message also gets a response (cooldown not working), OR
message after 65s still gets no response (cooldown not resetting).

**Note on Scowling faction:** At Scowling faction (-2000), the NPC emotes
hostility and immediately sets cooldown. Test the same sequence with
`#faction 330 -2000` to confirm Scowling cooldown works as well.

---

### Test 14: Non-Sentient Creatures Stay Silent

**Acceptance criterion AC14:** Animals, golems, elementals, and plants produce
no LLM response when spoken to, regardless of INT stat.

**Prerequisite:** Any character.

**Body type exclusion tests:**

**Test 14A: Animal (body type 21)**
- Target: a Koalindl (ID 2005) in qeynos2 at -392, -113, -10 (INT 8, bodytype 21)
- `/say Hello` — expect silence
- Also test: a whiskered bat (ID 2019) in qeynos2 at -296, 665, 2

**Test 14B: Insect (body type 22)**
- Target: a klicnik warrior (ID 2015) in qeynos2 at 482, 1036, 2 (bodytype 22)
- `/say Hello` — expect silence

**Test 14C: Construct/Golem (body type 5)**
- Target: Clockwork Merchant (ID 55303) in akanon at -976, 1093, 30
  (bodytype 5, INT 127 — this is the key test: high INT but excluded by body type)
- `#zone akanon`
- `#goto akanon -976 1093 30`
- `/say Hello, what do you sell?` — expect silence despite high INT

**Pass if:** All body type 5, 21, and 22 NPCs produce zero response when spoken
to.

**Fail if:** Any excluded body type NPC responds verbally (emote or speech).

---

### Test 15: No Modern Language in Responses

**Acceptance criterion AC15:** Over 10 test conversations, no responses contain
modern concepts (technology, democracy, mental health, economy) — only in-world
equivalents.

**Prerequisite:** Sidecar running with model loaded.

**Method:** This test is conducted in parallel with Test 10. Review all
responses from Test 10 for the following forbidden terms:

| Forbidden Term | What to Look For |
|----------------|-----------------|
| technology | Should be "artifice," "craft," "gnomish engineering" |
| economy | Should be "trade of goods," "guild merchants' prices" |
| democracy | Should be "the Council," "the Crown," governance terms |
| mental health | Should be "malady of the mind," "affliction of spirit" |
| stress | Should be "troubled thoughts" (NOTE: post-processor does not block "stress" — monitor for this) |
| science | Should be "natural philosophy," "arcane study" |
| evolution | Should be "the shaping by the gods" |
| experience points | Should be "wisdom gained" or not mentioned |
| hit points | Should be "wounds," "vitality" |
| mana | Should be "the weave of magic," "reagents" |

**Targeted prompt injection test:**

Ask an NPC directly: `/say What do you think about the economy?`

The NPC should respond in-world: something like "The trade of goods in this city
has suffered of late with the orc raids on the road." It should NOT say "the
economy is struggling."

**Pass if:** No forbidden modern terms appear in any of 10 conversations.

**Fail if:** Any response contains a verbatim forbidden term.

**Note on "stress":** The post-processor does not filter "stress" (see Warning
#27). If a response contains "stress," it is a post-processor gap, not a system
failure, but document it for the infra-expert.

---

## Edge Case Tests

These tests address antagonistic scenarios from the architecture plan's risk
assessment.

---

### Test E1: Single Quote in Player Message

**Risk from architecture plan:** "Player types a single quote: io.popen shell
command breaks. Mitigated: Lua bridge escapes ' to '\\'' using POSIX shell
escaping."

**Steps:**

1. Zone to West Freeport, target Guard Mizraen.
2. Faction: Indifferent or better.
3. Type: `/say I'm looking for trouble.` (contains apostrophe)
4. Observe result.
5. Then try: `/say What's the guard's duty?` (two apostrophes)
6. Observe result.

**Expected result:** Both messages produce normal NPC responses. No Lua error.
No server crash.

**Pass if:** Normal response to both messages.
**Fail if:** Lua error in chat, zone crash, or no response where one should appear.

---

### Test E2: Very Long Player Message

**Risk from architecture plan:** "Messages with backslashes, backticks" — shell
escaping edge cases.

**Steps:**

1. Zone to West Freeport, target Guard Mizraen.
2. Type a very long message (fill the chat input box):
   `/say I have been traveling across all of Norrath from the great city of Qeynos all the way to the dark forests of Faydwer and I am curious about what dangers lurk in this city of Freeport please tell me everything you know`
3. Observe result.
4. Type a message with special characters: `/say What about this & that?`
5. Observe result.

**Expected result:** Normal NPC responses or graceful silence. No Lua errors.
No zone crash.

**Pass if:** Stable behavior (response or silence) with no errors.
**Fail if:** Lua error, zone crash, or server error in logs.

---

### Test E3: Multiple Players Speaking to the Same Zone

**Risk from architecture plan:** "Multiple zones making concurrent sidecar calls:
Each zone is a separate process."

**Setup:** Requires two players online simultaneously, both in the same zone
(West Freeport).

**Steps:**

1. Player A and Player B both zone to West Freeport.
2. Player A targets Guard Mizraen.
3. Player B targets Guard Hrakin.
4. Both players type `/say` messages simultaneously (within 1 second of each
   other).
5. Observe results.

**Expected result:** Both players receive responses (possibly with slight delay
due to sequential zone process handling). No errors. No crashes.

**Pass if:** Both NPCs respond and the zone remains stable.
**Fail if:** Zone crash, Lua errors, or one player's request causes the other
to receive an error.

**Note:** This test requires two simultaneous players. If testing solo, skip or
note as untested.

---

### Test E4: NPC Despawns During Cooldown

**Risk from architecture plan:** "Entity variables lost on NPC despawn: Hostile
cooldown tracking uses entity variables which are in-memory only."

**Steps:**

1. Set Threatening faction with Freeport Militia.
2. Target Guard Hrakin, trigger the hostile cooldown (first response sets it).
3. Kill Guard Hrakin with: `#kill`
4. Wait for respawn (or use `#repop`).
5. Target the freshly respawned Guard Hrakin within the original 60-second
   cooldown window.
6. Type: `/say Hello.`

**Expected result:** The freshly spawned NPC responds (cooldown cleared on
despawn — no entity variables carry over). This is intended behavior per the
architecture plan.

**Pass if:** Freshly spawned NPC responds despite the original cooldown being
active at time of kill.
**Fail if:** Freshly spawned NPC ignores speech (cooldown incorrectly persisted).

---

### Test E5: Scripted NPC with Non-Matching Keywords

**Risk from architecture plan:** "NPC has quest script but it doesn't handle
the player's message: Local script runs but doesn't match any keywords — currently
falls through to silence. With the LLM, global_npc.lua would NOT fire because
the local script already consumed the event."

**Steps:**

1. Zone to West Freeport.
2. Target Armorer Dellin (has quest script, handles "hail" keyword).
3. Type: `/say What dangers lurk near the docks?` (not a keyword the script handles)
4. Wait 5 seconds.

**Expected result:** Complete silence. The local script consumed the event_say
but did not match the keyword and returned without calling LLM. The global hook
does NOT fire for NPCs with local scripts. This is the expected Phase 1 behavior.

**Pass if:** Complete silence (no LLM response, no scripted response).
**Fail if:** An LLM response appears (would indicate the global hook fired despite
a local script being present — a priority-order bug).

---

## Rollback Instructions

If something goes wrong during testing, here is how to restore previous state.

### Sidecar Rollback (disable LLM completely)

```bash
# Stop the npc-llm sidecar
cd /mnt/d/Dev/EQ/akk-stack && make down-llm

# Verify it stopped
docker ps | grep npc-llm   # should return nothing

# Game server and all other services continue running normally.
# NPCs will revert to their previous silent behavior.
# No server restart needed.
```

### Quest Script Rollback

If `global_npc.lua` or the Lua modules need to be reverted:

```bash
# Check what changed on the feature branch
cd /mnt/d/Dev/EQ && git diff main feature/npc-llm-integration -- akk-stack/server/quests/

# Revert specific files if needed (replace with actual git checkout path)
git checkout main -- akk-stack/server/quests/global/global_npc.lua

# Then reload quests (no server restart needed)
# In game: #reloadquests
```

### Full Rollback

```bash
# Stop sidecar
cd /mnt/d/Dev/EQ/akk-stack && make down-llm

# Restore quest files
cd /mnt/d/Dev/EQ
git checkout main -- akk-stack/server/quests/global/global_npc.lua
git checkout main -- akk-stack/server/quests/lua_modules/llm_bridge.lua
git checkout main -- akk-stack/server/quests/lua_modules/llm_config.lua
git checkout main -- akk-stack/server/quests/lua_modules/llm_faction.lua

# Reload quests in game: #reloadquests
# The LLM integration is now completely disabled.
# Docker images and model file remain on disk but are not used.
```

### Emergency In-Game Toggle

Without touching files, disable all LLM responses immediately:

1. Edit `llm_config.lua` and set `enabled = false`
2. Run `#reloadquests` in game
3. All NPC LLM responses stop instantly

---

## Blockers

Issues found that must be fixed before the feature can ship.

| # | Blocker | Severity | Responsible Expert | Status |
|---|---------|----------|--------------------|--------|
| 1 | Model file name case mismatch: disk has `Mistral-7B-Instruct-v0.3-Q4_K_M.gguf` but `.env` expects `mistral-7b-instruct-v0.3.Q4_K_M.gguf`. Sidecar starts but reports `model_loaded: false`. All LLM conversations silently fail. | Critical | infra-expert | Open |

**Fix for Blocker 1:**

```bash
# Rename model file to match .env
mv /mnt/d/Dev/EQ/akk-stack/npc-llm-sidecar/models/Mistral-7B-Instruct-v0.3-Q4_K_M.gguf \
   /mnt/d/Dev/EQ/akk-stack/npc-llm-sidecar/models/mistral-7b-instruct-v0.3.Q4_K_M.gguf

# Restart sidecar
cd /mnt/d/Dev/EQ/akk-stack && make down-llm && make up-llm

# Wait 90 seconds, then verify
docker exec akk-stack-eqemu-server-1 curl -s http://npc-llm:8100/v1/health
# Expected: {"status":"ok","model_loaded":true,...}
```

---

## Recommendations

Non-blocking observations and improvements noticed during validation.

1. **Add "stress" to post-processor era blocklist.** The PRD lists "stress" as
   a forbidden modern concept (in-world equivalent: "troubled thoughts"). The
   current `post_processor.py` blocks "anxiety" but not "stress". Add
   `r"\bstress\b"` to `ERA_BLOCKLIST` in
   `/mnt/d/Dev/EQ/akk-stack/npc-llm-sidecar/app/post_processor.py`. This is a
   5-minute fix and improves era compliance.

2. **Update status.md to reflect completed implementation tasks.** The
   status.md shows Tasks 1, 2, 5, 6, and 7 as "Not Started" but all files are
   present on disk (Python sidecar, zone_cultures.json, Docker files, Makefile
   targets, curl verified). The implementation team completed these tasks
   without updating the tracker. The status should be updated to reflect
   completion before handoff to the next phase.

3. **Consider adding a data_buckets query GM command for opt-out testing.** The
   per-NPC opt-out mechanism (AC9) requires direct database access to set the
   data bucket. Adding a GM command (`#npcllm disable [npc_type_id]`) in a
   future iteration would make this accessible without database access.

4. **Zone culture context injection is working correctly.** The
   `zone_cultures.json` file has all 25 zone keys, all required fields, and
   resolves correctly in the prompt builder. The Qeynos/Freeport cultural
   distinctions should be clearly audible during AC11 testing.

5. **curl timeout is set to 3 seconds in llm_config.lua.** With the Mistral 7B
   model on CPU, inference typically takes 1-3 seconds. If responses are
   consistently timing out (NPC gives thinking indicator but no response),
   consider increasing `timeout_seconds` to 5 in `llm_config.lua` (hot-reload
   with `#reloadquests`). This can be tuned per hardware after initial testing.

6. **Test the Clockwork Merchants in Ak'Anon for body type 5 exclusion (Test
   14C).** These are high-INT Construct-type NPCs — exactly the edge case the
   body type filter is designed to catch. Including this in AC14 testing
   provides the highest-value validation of the body type exclusion logic.
