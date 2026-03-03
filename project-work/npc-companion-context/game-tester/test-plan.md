# NPC Companion Context — Test Plan

> **Feature branch:** `feature/npc-companion-context`
> **Author:** game-tester
> **Date:** 2026-03-02
> **Server-side result:** FAIL — C++ rebuild required before in-game testing

---

## Test Summary

This plan validates the NPC Companion Context feature, which adds a
companion-aware context layer to the LLM dialogue system. Recruited NPCs now
receive an enriched context payload that signals their identity shift from
original role to group member. The affected systems are:

- `companion_context.lua` (new) — context builder
- `companion_culture.lua` (modified) — extended to all 14 Classic-Luclin races
- `companion_commentary.lua` (new) — unprompted commentary timer system
- `llm_bridge.lua` (modified) — companion context integration
- `llm_config.lua` (modified) — commentary timing config
- `global_npc.lua` (modified) — timer setup and death tracking
- `eqemu/zone/companion.cpp` and `lua_companion.cpp` (modified) — two new Lua bindings

### Inputs Reviewed

- [x] PRD at `game-designer/prd.md`
- [x] Architecture plan at `architect/architecture.md`
- [x] status.md — Tasks 2-7 marked Complete; Task 1 (C++ bindings) marked Not Started (status.md is stale — the C++ commit `e203d3dc0` was made on 2026-03-02)
- [x] Acceptance criteria identified: 12 criteria from PRD

### Critical Finding: Rebuild Required

The C++ commit `e203d3dc0` (adds `GetTimeActive()` and `GetRecruitedZoneID()`
to `companion.cpp`, `companion.h`, `lua_companion.cpp`, `lua_companion.h`) was
pushed on 2026-03-02 at 21:36 EST. The zone binary in
`eqemu/build/bin/zone` is dated Mar 1 18:39 — it predates the C++ changes.

The server cannot run until the binary is rebuilt and the server is restarted.
All Lua syntax checks require a running container. In-game testing cannot begin
until after the rebuild and restart cycle.

---

## Pre-Test Setup

Perform these steps before running any test. The Docker containers are
currently stopped.

### Step 1: Rebuild the server

```bash
cd /mnt/d/Dev/eq/akk-stack
make up
docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"
```

Expect build time of 3-8 minutes. Watch for errors — only warnings are
acceptable. Any compilation error is a blocker.

### Step 2: Start server processes

Start in this order inside the container, waiting the indicated time between each:

```bash
docker exec -it akk-stack-eqemu-server-1 bash -c "cd /home/eqemu/server && ./shared_memory"
# Wait for shared_memory to complete (prints 'Shared memory created')
docker exec -it akk-stack-eqemu-server-1 bash -c "cd /home/eqemu/server && ./loginserver &"
# Wait 3 seconds
docker exec -it akk-stack-eqemu-server-1 bash -c "cd /home/eqemu/server && ./world &"
# Wait 8 seconds for DB load
docker exec -it akk-stack-eqemu-server-1 bash -c "cd /home/eqemu/server && ./zone dynamic_01 &"
```

Or use Spire at http://192.168.1.86:3000 to restart.

### Step 3: Hot-reload Lua scripts

After the zone process is running, connect in-game and run:

```
#reloadquests
```

This flushes the Lua module cache so fresh versions of all modified scripts
load on the next NPC interaction.

---

## Part 1: Server-Side Validation

### Results

| # | Check | Result | Details |
|---|-------|--------|---------|
| 1 | Build verification — zone binary predates C++ commits | FAIL | zone binary dated Mar 1 18:39; C++ commit is Mar 2 21:36. Rebuild required. |
| 2 | Lua syntax: companion_context.lua | DEFERRED | Container not running. Run after rebuild. |
| 3 | Lua syntax: companion_culture.lua | DEFERRED | Container not running. Run after rebuild. |
| 4 | Lua syntax: companion_commentary.lua | DEFERRED | Container not running. Run after rebuild. |
| 5 | Lua syntax: llm_bridge.lua | DEFERRED | Container not running. Run after rebuild. |
| 6 | Lua syntax: global_npc.lua | DEFERRED | Container not running. Run after rebuild. |
| 7 | Lua syntax: llm_config.lua | DEFERRED | Container not running. Run after rebuild. |
| 8 | Database integrity — no DB changes made | PASS | Feature adds no new tables, columns, or FK references. Architecture confirmed no DB schema changes needed. |
| 9 | Log analysis — no post-feature logs available | DEFERRED | Server not restarted since feature was implemented. Run after restart. |
| 10 | Race ID correctness in companion_culture.lua | PASS | File header comment documents verified IDs. Human=1, Barbarian=2, Erudite=3, Wood Elf=4, High Elf=5, Dark Elf=6, Half Elf=7, Dwarf=8, Troll=9, Ogre=10, Halfling=11, Gnome=12, Iksar=128, Vah Shir=130. |
| 11 | Iksar KOS constraint present in companion_culture.lua | PASS | Lines 268-272: explicit constraint prohibiting Qeynos, Freeport, Felwithe, Kaladim, Erudin reference for race 128. Present in both loyal (line 268) and mercenary (line 313) framings. |
| 12 | Vah Shir oral culture constraint present | PASS | Lines 278-287: explicit constraint on books/scrolls/written magic; "hymnists say" phrasing mandated; Erudite blame cited. |
| 13 | Erudite Erudin/Paineel distinction present | PASS | Lines 177-183: class-based city origin coded. Necromancer/Shadow Knight = Paineel; all others = Erudin. |
| 14 | Luclin fixed-light zone table in companion_context.lua | PASS | Lines 23-42: 13 zones enumerated. Includes nexus, umbral, griegsend, akheva, sseru, katta, sharvahl, paludal, fungusgrove. Surface zones (dawnshroud, scarlet, tenebrous, twilight, bazaar) correctly marked false. |
| 15 | llm_config.lua commentary config values | PASS | Lines 43-48: all six commentary config values present with documented defaults (enabled=true, min_interval=600s, hard_cap=900s, probability=25, grace_period=120s, combat_block=true). |
| 16 | companion_context.build() integrated into llm_bridge.build_context() | PASS | llm_bridge.lua lines 154-166: companion detection with pcall-guarded require and field merge. |
| 17 | All companion context fields forwarded in generate_response() | PASS | llm_bridge.lua lines 216-238: all 22 companion fields explicitly included in the sidecar request table. |
| 18 | Companion timer set in event_spawn | PASS | global_npc.lua lines 212-222: timer named "comp_commentary_<entity_id>", interval from config, five entity variables initialized. |
| 19 | event_timer dispatches to companion_commentary | PASS | global_npc.lua lines 227-237: timer name prefix check, pcall-guarded require, timer restart. |
| 20 | event_death_zone updates all companion recent_kills | PASS | global_npc.lua lines 243-298: iterates all clients' groups, updates last-5 kill list, flags named kills. |

### Database Integrity

No database changes were made in this feature. The architecture plan explicitly
states: "No new database tables or columns are needed." All companion context
data is derived from live entity state and existing `companion_data` table fields.

No database queries are required for validation.

**Findings:** PASS. No database integrity issues possible from this feature.

### Quest Script Syntax

Run the following after the container is started:

```bash
# companion_context.lua
docker exec -it akk-stack-eqemu-server-1 bash -c \
  "luajit -bl /home/eqemu/server/quests/lua_modules/companion_context.lua > /dev/null && echo PASS || echo FAIL"

# companion_culture.lua
docker exec -it akk-stack-eqemu-server-1 bash -c \
  "luajit -bl /home/eqemu/server/quests/lua_modules/companion_culture.lua > /dev/null && echo PASS || echo FAIL"

# companion_commentary.lua
docker exec -it akk-stack-eqemu-server-1 bash -c \
  "luajit -bl /home/eqemu/server/quests/lua_modules/companion_commentary.lua > /dev/null && echo PASS || echo FAIL"

# llm_bridge.lua
docker exec -it akk-stack-eqemu-server-1 bash -c \
  "luajit -bl /home/eqemu/server/quests/lua_modules/llm_bridge.lua > /dev/null && echo PASS || echo FAIL"

# llm_config.lua
docker exec -it akk-stack-eqemu-server-1 bash -c \
  "luajit -bl /home/eqemu/server/quests/lua_modules/llm_config.lua > /dev/null && echo PASS || echo FAIL"

# global_npc.lua
docker exec -it akk-stack-eqemu-server-1 bash -c \
  "luajit -bl /home/eqemu/server/quests/global/global_npc.lua > /dev/null && echo PASS || echo FAIL"
```

| Script | Language | Result | Notes |
|--------|----------|--------|-------|
| companion_context.lua | Lua | DEFERRED | Run after container start |
| companion_culture.lua | Lua | DEFERRED | Run after container start |
| companion_commentary.lua | Lua | DEFERRED | Run after container start |
| llm_bridge.lua | Lua | DEFERRED | Run after container start |
| llm_config.lua | Lua | DEFERRED | Run after container start |
| global_npc.lua | Lua | DEFERRED | Run after container start |

### Log Analysis

After the server restart, check the zone logs for errors related to the new
Lua modules. The zone process loads Lua scripts on first use.

```bash
# Check for Lua errors in the zone log after first companion interaction
ls -lt /mnt/d/Dev/eq/akk-stack/server/logs/zone/ | head -5
# Then read the most recent zone log:
grep -i "companion_context\|companion_commentary\|companion_culture\|llm_bridge\|GetTimeActive\|GetRecruitedZoneID" \
  /mnt/d/Dev/eq/akk-stack/server/logs/zone/<latest-zone-log>
```

Look for:
- `[SCRIPT ERROR]` or `[QUEST ERROR]` lines referencing new modules
- "attempt to call a nil value" on `GetTimeActive` or `GetRecruitedZoneID` (would indicate rebuild did not succeed)
- `llm_bridge: JSON decode failed` (sidecar communication issue, separate from this feature)

| Log File | Errors Found | Severity | Related To |
|----------|-------------|----------|------------|
| zone/*.log | DEFERRED | — | Check after first companion interaction post-restart |

### Rule Validation

No new EQEmu rule values (`ruletypes.h`) were added. All timing parameters
are in `llm_config.lua`. No rule validation queries are needed.

| Rule | Category | Value | Valid Range | Result |
|------|----------|-------|-------------|--------|
| (none) | — | — | — | PASS — no rule changes |

### Spawn Verification

No new spawn points were added. This feature affects only LLM dialogue
content. No spawn verification is required.

### Loot Chain Validation

No loot table changes were made. No loot validation is required.

### Build Verification

**Build command:**
```bash
cd /mnt/d/Dev/eq/akk-stack
make up
docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"
```

- **Result:** FAIL (pre-check) — zone binary is stale. The binary at
  `eqemu/build/bin/zone` is dated Mar 1 18:39, but the C++ changes
  (`companion.cpp`, `companion.h`, `lua_companion.cpp`, `lua_companion.h`)
  were committed on Mar 2 21:36. A full rebuild is required.
- **Expected result after rebuild:** PASS (no new compilation errors introduced;
  the two new methods are simple getters)
- **Files changed in the C++ commit:** `zone/companion.cpp`, `zone/companion.h`,
  `zone/lua_companion.cpp`, `zone/lua_companion.h`

---

## Part 2: In-Game Testing Guide

### Prerequisites

- A GM-level character on the Titanium client
- The LLM sidecar must be running (check at http://192.168.1.86:8100/health
  or equivalent sidecar health endpoint)
- Server rebuilt and restarted with the new zone binary
- `#reloadquests` run after first zone connection to flush Lua cache

**Recommended test character:** Level 20+ so recruitment rolls have good odds.
Use `#level 20` if needed.

**Important:** The LLM sidecar must be running for conversation tests to work.
If the sidecar is down, companions will be silent (existing behavior). The
feature cannot be validated without the sidecar.

**Note on LLM responses:** The exact wording of every response is LLM-generated
and will vary. Tests describe what the response should demonstrate, not the
exact words. Evaluate whether the response reflects the expected framing
(companion vs. NPC role) rather than comparing to a specific string.

---

### Test 1: Identity Shift After Recruitment

**Acceptance criterion:** "A recruited companion responds to conversation as
a group member, not as their original role. A former guard does not say
'Move along, citizen' or refer to their patrol duties as current activity."

**Prerequisite:** Any zone with a guard NPC that can be recruited (West Karana,
South Karana, Qeynos Hills, or the East Commonlands are good choices).

**Steps:**
1. Target a guard NPC (for example, a patrol guard in West Karana or a city
   guard in Qeynos Hills).
2. Say `join me` (or your server's recruitment keyword) to attempt recruitment.
   Repeat if the roll fails — use `#level 20` and try again.
3. Once recruited, wait 5 seconds for the companion to group up.
4. Say `Hail` or `Hello` to the companion.
5. Observe the companion's response in the chat window.
6. Then say `What are you doing here?` or `Tell me about your duties.`
7. Observe the response.

**Expected result:** The companion speaks as a group member. They should NOT
say things like "Move along, citizen," "I am on patrol," or reference their
current guard duty as an ongoing task. They may reference being a guard as
past experience ("I used to guard the south gate," "Back when I patrolled
these roads...") but frame it as history, not current identity.

**Pass if:** The companion's response does not describe an ongoing patrol duty
or currently active NPC role. The response treats adventuring with the player
as the present situation.

**Fail if:** The companion says "Move along, citizen," tells you to move to the
correct area, references their current patrol schedule, or otherwise speaks
as though they are still at their original post.

**GM commands for setup:**
```
#level 20
#zone qeynosstudent
```

---

### Test 2: Zone Situational Awareness

**Acceptance criterion:** "A companion references the current zone by name or
description in conversation when contextually appropriate."

**Prerequisite:** Companion recruited (from Test 1 or new recruitment). Test
in at least two different zone environments: an outdoor zone and a dungeon.

**Steps:**
1. With a companion in your group, zone into Blackburrow (`#zone blackburrow`).
2. Say `What do you think of this place?` or `Watch yourself in here.`
3. Observe the companion's response.
4. Zone into West Karana (`#zone westkarana`).
5. Say `What do you think of this place?` or `It is a nice day.`
6. Observe the companion's response.

**Expected result:** In Blackburrow (dungeon zone), the companion should
reference tunnels, underground conditions, darkness, or danger in confined
spaces. In West Karana (outdoor zone), the companion should reference
plains, open sky, weather, or the overland environment. The zone name or
zone character should be present in the response.

**Pass if:** The companion's response in each zone reflects an awareness
of where they are. The dungeon response feels different from the outdoor
response in a way that is contextually appropriate.

**Fail if:** The companion gives identical or zone-agnostic responses in
both environments ("I am ready to fight" with no zone reference), suggesting
the zone context is not reaching the sidecar.

**GM commands for setup:**
```
#zone blackburrow
#zone westkarana
```

---

### Test 3: Origin as Backstory

**Acceptance criterion:** "A companion references their origin (home zone,
former role) as backstory when appropriate."

**Prerequisite:** Companion recruited from a guard post in a named city
(Qeynos, East Commonlands, or West Karana).

**Steps:**
1. With the guard companion in your group (in any zone), say `Tell me about
   where you came from.`
2. Observe the companion's response.
3. Say `Do you miss your old life?` or `What do you think about Qeynos?`
4. Observe the response.

**Expected result:** The companion references their former role and home zone
as past experience. They might say something like "I used to guard the
south gate in Qeynos — it was honest work" or "Back in Qeynos, the gnolls
were a nuisance at the gates, nothing like this." The framing should be
retrospective: past tense, the old role as history, not as their current
identity.

**Pass if:** The companion mentions their former role or home zone in a
clearly past-tense frame. The response treats that identity as backstory
informing their perspective, not as their current situation.

**Fail if:** The companion says "I am a Qeynos guard" (present tense identity),
or the response shows no awareness of any origin beyond generic adventurer
framing.

---

### Test 4: Race Personality Differentiation (Erudite vs Barbarian)

**Acceptance criterion:** "Two companions of different races produce noticeably
different conversational styles when asked the same question in the same zone."

**Prerequisite:** Two companions of different races recruited and in the group.
An Erudite and a Barbarian are the recommended test pair per the PRD example.

**Steps:**
1. Recruit an Erudite companion (found in Erudin, The Hole, or zones around
   Odus). Use `#zone erudin` if needed.
2. After recruiting, recruit a Barbarian companion (found in Halas zones or
   as guards in northlands areas). Having both in group simultaneously requires
   a level-appropriate group — or test sequentially by dismissing one.
3. With each companion individually in your group, zone to the same location
   (for example, West Karana at approximately -1000, 2500, 3).
4. Say the same question to each: `What do you make of this place?`
5. Compare the two responses.

**Expected result:** The Erudite response should be analytical, precise, and
possibly reference magical theory or scholarly perspective. The Barbarian
response should be direct, physical, and reference strength or plain
observation without intellectual framing.

**Pass if:** The two responses are noticeably different in tone, vocabulary,
and perspective. Someone reading them should be able to identify which is
which without seeing the NPC name.

**Fail if:** Both companions give essentially the same response style — generic
adventurer commentary with no racial personality distinguishing them.

**GM commands for setup:**
```
#zone erudin
#zone halas
#zone westkarana
```

---

### Test 5: Unprompted Commentary Rate

**Acceptance criterion:** "Unprompted companion commentary occurs at a natural
rate — no more than once per 15 minutes, and not during active combat."

**Prerequisite:** Companion in group. Server must have been running for at
least 10 minutes since the companion spawned. This test requires patience —
the commentary interval is 10 minutes minimum with a 15 minute hard cap.

**Steps — Rate check:**
1. Recruit a companion and wait. Note the time.
2. Stand idle (no combat, no conversation) for 20+ minutes.
3. Count the number of unprompted comments the companion makes.
4. The companion should say at most one unprompted remark per 15 minutes.

**Steps — Combat suppression:**
1. With a companion in your group, engage a group of mobs in combat.
2. Stay in combat for 2-3 minutes.
3. Observe whether the companion makes any unprompted remarks during active combat.

**Expected result (rate):** Zero to one unprompted remarks per 15-minute window.
The companion should not speak unprompted every minute or every few minutes.

**Expected result (combat):** Zero unprompted remarks during active combat
(while the companion's hate list has entries).

**Pass if:** No more than one unprompted remark occurs in a 15-minute window.
No unprompted remarks fire during active combat.

**Fail if:** The companion speaks unprompted more than once in 15 minutes. The
companion makes unprompted remarks in the middle of a fight.

**Note:** The first unprompted remark will not fire in the first 2 minutes
after recruitment (grace period). If standing completely idle in the same
zone with no kills, the context change detection may reduce commentary
frequency further — a zone change or named kill is more likely to trigger
commentary than pure idle time.

---

### Test 6: Unprompted Commentary Contextual Relevance

**Acceptance criterion:** "Unprompted commentary is contextually relevant to
the current zone or recent activity, not random generic statements."

**Prerequisite:** Companion in group, LLM sidecar running.

**Steps:**
1. Zone into a dungeon (Blackburrow or Upper Guk are good choices).
2. Kill 3-4 named or notable mobs in the zone.
3. Wait for an unprompted comment (up to 15 minutes after a named kill, which
   is an immediate context change trigger).
4. Observe the comment content.

**Expected result:** The unprompted comment should reference the dungeon
environment, the recent fighting, or specific mobs killed — not be a generic
statement about life or the weather that could apply anywhere.

**Pass if:** The comment references the zone or recent activity in a way that
makes sense for the current location.

**Fail if:** The companion says something completely disconnected from the
current situation ("I wonder what's for dinner" in the middle of Blackburrow
with no reference to the dungeon).

**GM commands for setup:**
```
#zone blackburrow
```

---

### Test 7: Dismiss and Re-Recruit

**Acceptance criterion:** "A dismissed and re-recruited companion resumes
companion-style conversation (not reverting to original NPC dialogue) and
references shared history when appropriate."

**Prerequisite:** Companion that has been in the group for several minutes
and has had at least one conversation.

**Steps:**
1. Have a conversation with your companion — say a few things to them.
2. Dismiss the companion by saying `!dismiss` (or your server's dismiss keyword).
3. The companion returns to their original spawn point.
4. Find the companion again and say `join me` to re-recruit them.
5. Once re-recruited, say `Hail` or `Hello.`
6. Observe whether the companion speaks as a returning group member or as
   an NPC at their original post.

**Expected result:** After re-recruitment, the companion should respond as
someone who remembers you. They should not say "Move along, citizen" or
speak as though this is the first meeting. The `re_recruitment` event in
`companion_culture.lua` provides framing: the companion acknowledges returning
to a known arrangement or relationship.

**Pass if:** The companion's first response after re-recruitment does not
read as a fresh NPC encounter. There is some sense of recognition or
continuity.

**Fail if:** The companion immediately returns to generic NPC dialogue ("How
may I help you, adventurer?"), speaks as though they are at their patrol post,
or shows no continuity with the previous relationship.

---

### Test 8: Iksar Companion Lore Constraint

**Acceptance criterion:** "An Iksar companion does not reference old-world
good-aligned cities (Qeynos, Freeport, Felwithe, Kaladim, Erudin) as familiar
or friendly places."

**Prerequisite:** Iksar companion recruited. Iksar NPCs appear in Kunark zones
(Cabilis area, Field of Bone, Warsliks Wood) and are race ID 128.

**Steps:**
1. Zone to a Kunark zone with Iksar NPCs (`#zone cabilis` or `#zone fieldofbone`).
2. Recruit an Iksar companion.
3. Say `Tell me about Qeynos.` or `What do you think of Freeport?`
4. Observe the response.
5. Say `Where do you feel welcome?` or `Tell me about Cabilis.`
6. Observe the response.

**Expected result:** When asked about Qeynos, Freeport, Felwithe, Kaladim, or
Erudin, the Iksar companion should not speak of them as familiar or friendly.
They may speak of them with contempt, hostility, or as dangerous places where
they are unwelcome. When asked about Cabilis, the tone should be warmer —
it is their home.

**Pass if:** The Iksar companion does not describe old-world good-aligned cities
as places they have been or feel welcome in. The constraint in
`companion_culture.lua` lines 268-272 is reflected in dialogue.

**Fail if:** The Iksar companion casually mentions having visited Qeynos,
references the Qeynos Guard favorably, or otherwise treats KOS cities as
friendly familiar places.

**GM commands for setup:**
```
#zone fieldofbone
#level 20
```

---

### Test 9: Vah Shir Companion Oral Culture Trait

**Acceptance criterion:** "The companion context system works for all
recruitable NPC races in the Classic-through-Luclin era (including Vah Shir
when Luclin content is enabled)."

**Prerequisite:** Vah Shir companion recruited. Vah Shir NPCs appear in Luclin
zones (Shar Vahl, Shadeweaver's Thicket, Paludal Caverns). Vah Shir are race
ID 130.

**Steps:**
1. Zone to Shadeweaver's Thicket or Shar Vahl.
2. Recruit a Vah Shir companion.
3. Say `What do you know about the history of Luclin?`
4. Observe the response — look for oral tradition framing.
5. Say `I read in a book that the Vah Shir were exiled here.`
6. Observe whether the companion reacts to the reference to books/written
   records.

**Expected result (step 4):** The Vah Shir companion should cite knowledge
as "the hymnists say..." or "it is told that..." rather than "I read that..."
They should not reference books or scrolls as sources.

**Expected result (step 6):** The companion should react with some discomfort,
skepticism, or distrust toward books/written records as a source of truth.
The lore constraint in `companion_culture.lua` lines 278-287 establishes
this trait explicitly.

**Pass if:** The Vah Shir companion avoids "I read that" style phrasing and
uses oral tradition framing. If challenged about books, they show the
culturally appropriate distrust.

**Fail if:** The Vah Shir companion casually says "I read that..." or "According
to the texts..." — this violates the banned-written-records constraint.

**GM commands for setup:**
```
#zone shadeweaver
#level 25
```

---

### Test 10: No Post-Luclin Lore References

**Acceptance criterion:** "No post-Luclin lore references appear in any
companion dialogue or context data."

**Prerequisite:** Any companion recruited.

**Steps:**
1. Recruit a companion.
2. Have several conversations covering: history of Norrath, famous places,
   class abilities, deities.
3. Watch for any reference to: Planes of Power, Gates of Discord, Berserker
   class, Frogloks as a playable race, any post-Luclin deity, Omens of War,
   or any expansion content released after Luclin.
4. Specifically ask: `Tell me about the gods of Norrath.` and watch for
   post-Luclin deity references.
5. Specifically ask a Warrior or Barbarian companion: `Are you a Berserker?`
   — the answer should be no, and the class should not be recognized as valid.

**Expected result:** All dialogue stays within Classic-through-Luclin
content. No Planes of Power zones, no Berserker class pride, no Froglok
cultural identity as a player race.

**Pass if:** No post-Luclin lore appears in any response across the test
conversations.

**Fail if:** Any companion references Planes of Power by name as a destination,
claims to be a Berserker, references Frogloks as a player civilization, or
mentions content that was not available through Luclin.

---

### Test 11: Companions Do Not Interact With Each Other

**Acceptance criterion:** "Companions in a group with other companions do not
interact with each other or reference each other in conversation."

**Prerequisite:** Two companions in the group simultaneously (requires
multiple recruitments).

**Steps:**
1. Recruit two companions of different races.
2. Speak to Companion A: `What do you think of your traveling companions?`
3. Observe whether Companion A references Companion B by name or engages
   in a cross-companion dialogue.
4. Speak to Companion B: `Hail.` or `How are you?`
5. Observe whether Companion B refers to or addresses Companion A.

**Expected result:** Neither companion directly addresses or references the
other companion by name in dialogue. The `group_members` context field is
provided to the sidecar (for group composition awareness), but companion-to-
companion interaction is explicitly out of scope per the PRD.

**Pass if:** Neither companion references the other companion in direct
conversation.

**Fail if:** One companion says "Tell your Barbarian friend to stop that" or
directly addresses the other companion. (Note: the sidecar may acknowledge
the group has other members — this is acceptable. Direct interaction is not.)

---

### Test 12: Non-Companion NPC Dialogue Unaffected

**Acceptance criterion:** The system does not affect non-companion NPC dialogue.

**Prerequisite:** Any zone with regular NPCs.

**Steps:**
1. Dismiss all companions.
2. Talk to a regular NPC that uses LLM dialogue (a guard, merchant, or citizen
   with no local Perl script).
3. Say `Hail` and have a short conversation.
4. Observe that the conversation is standard NPC dialogue without companion
   framing.

**Expected result:** Non-companion NPCs respond as they did before this feature.
The context payload for non-companions does not include `is_companion=true` or
any companion fields.

**Pass if:** The NPC responds normally in their original role. No companion
framing appears in their speech.

**Fail if:** A regular guard NPC says something like "Back in my old job..." or
uses any framing that implies they have left their post.

---

## Edge Case Tests

### Test E1: GetTimeActive() Returns Valid Data

**Risk from architecture plan:** "Luabind inheritance prevents `GetTimeActive()`
on companion objects" — mitigated by adding directly to `Lua_Companion`.

**Steps:**
1. Recruit a companion.
2. Enable debug logging in llm_config.lua (`debug_logging = true`) and
   `#reloadquests`.
3. Have a conversation with the companion.
4. Check the zone log for the `llm_bridge: response OK` log line and any
   errors related to `GetTimeActive`.

**Pass if:** No "attempt to call a nil value (method 'GetTimeActive')" error
in the zone log. The companion context builds without error.

**Fail if:** The zone log shows a nil method error for `GetTimeActive` or
`GetRecruitedZoneID`. This would mean the rebuild did not include the new
Lua bindings or there is a luabind registration issue.

**Note:** If this fails, the responsible expert is c-expert. The fix would be
to verify the luabind registration in `lua_companion.cpp` at lines 242-244.

---

### Test E2: Luclin Fixed-Light Zone Suppresses Day/Night Commentary

**Risk from architecture plan:** "Luclin fixed-light zone list becomes stale
if new Luclin zones are added."

**Steps:**
1. Recruit a companion.
2. Zone into The Nexus (`#zone nexus`).
3. Say `It is getting late, what time is it?` or `The light seems strange here.`
4. Observe whether the companion makes any day/night reference as if normal
   time-of-day cycles exist.

**Expected result:** In The Nexus (a fixed-light Luclin zone), the companion's
context has `is_luclin_fixed_light=true` and `time_of_day="fixed_lighting"`.
The sidecar should not generate "it's getting dark" or "what a beautiful
sunrise" commentary for this zone.

**Pass if:** The companion does not make day/night commentary that implies
a normal time-of-day cycle is present. They may reference the unusual lighting
of the Nexus specifically.

**Fail if:** The companion says "It is dawn here" or "The sun is setting" in
a fixed-light Luclin zone.

**GM commands for setup:**
```
#zone nexus
```

---

### Test E3: Commentary Does Not Fire in First 2 Minutes

**Risk from architecture plan:** "Unprompted commentary fires too often or at
bad times — player is in the middle of something."

**Steps:**
1. Recruit a companion.
2. Immediately (within 1 minute of recruitment), wait silently without speaking.
3. Observe whether the companion makes any unprompted remarks.
4. The grace period is 120 seconds — no unprompted commentary should fire
   in the first 2 minutes.

**Pass if:** No unprompted commentary fires in the first 2 minutes after
recruitment.

**Fail if:** The companion speaks unprompted within 2 minutes of joining
the group.

---

### Test E4: Zone Change Triggers Commentary Context Change

**Risk from architecture plan:** "Entity variable loss on zone change — recent
kill tracking is reset." Acceptable, but verify zone-change detection works.

**Steps:**
1. Recruit a companion in West Karana.
2. Wait at least 2 minutes (grace period clears).
3. Zone into Blackburrow (`#zone blackburrow`).
4. Wait up to 10 minutes (the timer check interval) for an unprompted remark.

**Expected result:** A zone change sets `comp_last_zone` in entity variables.
The `detect_context_change()` function checks whether the current zone differs
from `comp_last_zone`. A zone change is one of the three valid context-change
triggers for unprompted commentary.

**Pass if:** After a zone change, the companion eventually makes an unprompted
remark about the new zone (within 10-15 minutes, subject to the 25%
probability roll — may need to repeat zone changes if first roll fails).

**Fail if:** The companion never makes zone-change-triggered commentary after
multiple zone transitions. (Note: the 25% probability means this may not fire
on the first attempt — try 3-4 zone changes before concluding failure.)

---

### Test E5: Companion With Zero zones_visited (Old Companion Data)

**Risk from architecture plan:** "`GetRecruitedZoneID()` returns 0 for
companions recruited before RecordZoneVisit was implemented."

**Steps:**
1. If there are any companions with existing `companion_data` rows that predate
   the zone-visit tracking feature, recruit one.
2. Have a conversation with them.
3. The companion should not crash or error out — they should fall through to
   "unknown origins" framing gracefully.

**Expected result:** When `GetRecruitedZoneID()` returns 0, `companion_context.lua`
calls `get_recruited_zone_name(0)` which returns "unknown", "an unknown land".
The evolution context uses the fallback "guard" role. Dialogue should still work.

**Pass if:** The companion converses normally even with no recruited zone data.
No error in zone logs.

**Fail if:** A Lua error fires when `GetRecruitedZoneID()` returns 0, crashing
the context build.

---

### Test E6: Named Kill Commentary Trigger

**Risk from architecture plan:** Named kill detection uses "a "/"an " prefix
check, which may misclassify some NPCs.

**Steps:**
1. Recruit a companion.
2. Kill a named NPC (one whose name does not start with "a " or "an ") — for
   example, "Gnoll Slave Overseer" or "Pithrak" in Blackburrow.
3. After the kill, wait for the companion to potentially comment (up to 10
   minutes for the timer check, 25% probability).

**Expected result:** The named kill sets `comp_named_kill="1"` in the companion's
entity variables. The next timer check detects this as a context change. With
25% probability, the companion speaks about the notable kill.

**Pass if:** After killing a named NPC, the companion eventually makes a
post-combat observation remark (may take a few minutes and may require
multiple named kills to observe the 25% roll succeed).

**Fail if:** Named kills never trigger any commentary after multiple tests. Check
the zone log for errors in `event_death_zone`.

---

## Rollback Instructions

This feature adds no database content and changes no server configuration.
Rollback is only needed if the Lua scripts cause runtime errors.

**Quest script rollback** (reverts to previous version of Lua scripts):

```bash
cd /mnt/d/Dev/eq/akk-stack
git checkout HEAD~1 -- server/quests/global/global_npc.lua
git checkout HEAD~1 -- server/quests/lua_modules/companion_commentary.lua
git checkout HEAD~1 -- server/quests/lua_modules/companion_context.lua
git checkout HEAD~1 -- server/quests/lua_modules/companion_culture.lua
git checkout HEAD~1 -- server/quests/lua_modules/llm_bridge.lua
git checkout HEAD~1 -- server/quests/lua_modules/llm_config.lua
```

Then in-game:
```
#reloadquests
```

No server restart is needed for a Lua-only rollback.

**C++ rollback** (reverts the Lua bindings — requires rebuild and restart):

```bash
cd /mnt/d/Dev/eq/eqemu
git checkout HEAD~1 -- zone/companion.cpp zone/companion.h zone/lua_companion.cpp zone/lua_companion.h
docker exec -it akk-stack-eqemu-server-1 bash -c "cd ~/code/build && ninja -j$(nproc)"
# Then restart the server via Spire or make restart
```

**Important:** If you revert the C++ changes but keep the Lua changes,
`companion_context.build()` will use `pcall`-guarded calls for
`GetTimeActive()` and `GetRecruitedZoneID()` — so it will fail silently with
default values (0 seconds active, zone_id=0), not crash. The companion
context will still function with degraded data.

---

## Blockers

| # | Blocker | Severity | Responsible Expert | Status |
|---|---------|----------|--------------------|--------|
| 1 | C++ rebuild required — zone binary predates companion.cpp changes | Critical | c-expert (rebuild is a user/infrastructure task, not a code change) | Open — must rebuild before any in-game testing |

---

## Recommendations

- After the first successful rebuild and server start, run `#reloadquests`
  before the first companion interaction to guarantee the new Lua modules
  are loaded fresh.

- Enable `debug_logging = true` in `llm_config.lua` during initial testing
  and watch the zone log. The `llm_bridge` emits `LOG_DEBUG` messages on
  successful responses (log category 38, QuestDebug — visible via gmsay).
  This confirms the sidecar is receiving the companion context fields.

- For Test 4 (race differentiation), test with Erudite vs. Barbarian first
  because these are the most dramatically different cultural framings in
  `companion_culture.lua`. If those produce indistinguishable responses, the
  sidecar is likely ignoring `type_framing` and `race_culture_id` fields.

- The Lua implementation correctly uses `pcall` around every new C++ method
  call (`GetTimeActive`, `GetRecruitedZoneID`, `GetHPRatio`, `GetZoneType`,
  `GetZoneTime`). If a method is missing (e.g., rebuild was incomplete), the
  code will fail silently with defaults rather than crashing the zone process.
  Watch zone logs for `[QUEST ERROR]` lines that might indicate silent
  failures still causing degraded output.

- The `is_luclin_fixed_light` lookup table includes `bazaar = false` and
  `dawnshroud = false`. These are correct: The Bazaar is an indoor structure
  on Luclin's surface with day/night. If testing in the Bazaar produces
  day/night commentary, that is correct behavior.

- The status.md shows Task 1 (C++ bindings) as "Not Started" but the git log
  shows commit `e203d3dc0` on 2026-03-02 with exactly those four C++ files.
  Update status.md to reflect Task 1 as Complete after confirming the build
  succeeds.
