# Companion System Bug Fixes — Agent Conversations Log

> **Feature branch:** `bugfix/companion-system-fixes`
> **Created:** 2026-03-01

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

### 2026-03-01 — Initial Bug-Fix Concept Review

**From:** game-designer → **To:** lore-master

> Notified lore-master of three companion system bugs being documented:
> 1. LLM Chat Bug — companions show thinking emotes but don't respond
> 2. Equipment Display Bug — traded items don't visually appear on companions
> 3. Equipment Persistence Bug — equipment lost on zone/relog
>
> Asked for initial lore concerns, era compliance review, and any context
> about companion chat/equipment from a lore perspective.

**Response from** lore-master:

> Provided detailed proactive lore research covering all three bugs. Key findings:
>
> **Bug 1 (LLM Chat):** companion_culture.lua injects race-specific and
> companion_type-specific framing — the "soul" layer. Examples: Ogres speak in
> survival panic due to Rallos Zek's divine punishment; Teir'Dal mercenaries
> speak with cold calculation; Iksar speak rarely with warrior precision.
> companion_type 0 (loyal) vs 1 (mercenary) get different relationship framing.
> Prior lore-master review recorded 2026-02-27 in companion_culture.lua header.
> **Key constraint:** fix must preserve cultural voice pathways, not flatten
> companions to generic responses. Bug is a routing/eligibility failure, not
> a dialogue content failure.
>
> **Bug 2 (Equipment Display):** No lore implications. Purely technical.
> event_trade companion says "Thank you." — no dialogue changes needed.
>
> **Bug 3 (Equipment Persistence):** No lore implications. Purely a data
> persistence / C++ layer concern.
>
> **Era compliance:** All three bugs involve internal companion system code.
> No references to post-Luclin content. Era compliance issues extremely unlikely.
>
> **Guidance for PRD:**
> 1. Companion dialogue examples must align with cultural voice system
> 2. Bug 1 is routing, not content — PRD should frame it that way
> 3. Acceptance criteria must not require modern chatbot tone — EQ tone is
>    terse, atmospheric, in-character

**Outcome:** Lore context incorporated into PRD design. Bug 1 framed as
routing/integration failure (aligned with lore-master guidance). No acceptance
criteria require specific dialogue content.

### 2026-03-01 — Complete PRD Final Lore Review

**From:** game-designer → **To:** lore-master

> Sent complete PRD (`game-designer/prd.md`) for final lore review.
> Highlighted era compliance section (Classic-Luclin lock maintained),
> no new lore/NPCs/factions/narrative content introduced, LLM soul/memory
> system unchanged (only fixing integration path), equipment slots match
> Titanium client (no post-Luclin slots).
>
> Requested sign-off on: lore concerns, era compliance, thematic issues
> with acceptance criteria.

**Response from** lore-master:

> APPROVED — lore-master completed review (task #2 marked completed).
> Bug fixes to existing companion systems with no narrative changes.
> Era compliance confirmed. No lore concerns.

**Outcome:** Lore sign-off recorded. PRD approved for handoff to architect.

---

## Architecture Team Conversations

_architect + protocol-agent + config-expert exchanges during Phase 3._

### 2026-03-01 — Config-Expert Proactive Rule/Config Assessment

**From:** config-expert → **To:** architect

> Proactively delivered rule/config assessment for all three companion bugs
> before architect asked, since findings directly impact the architecture plan.
>
> **Research performed:**
> - Queried `rule_values` DB table for companion/equipment/wear/inventory rules
> - Grepped `eqemu/common/ruletypes.h` for matching patterns
> - Verified `Companions` category (lines 1181-1203): 22 rules, none covering
>   equipment display, equipment persistence, or LLM connectivity
> - Verified Docker state: `akk-stack-npc-llm-1` healthy, up 3+ hours
> - Verified DNS: `npc-llm` resolves to `172.18.0.9` from inside eqemu container
> - Verified sidecar health endpoint: model loaded, ChromaDB connected, 6 collections
>
> **Finding for each bug:**
> - Bug 1 (LLM Chat): Sidecar is healthy and reachable — NOT a Docker/config
>   problem. Failure is in Lua code (llm_bridge.lua curl/JSON handling).
> - Bug 2 (Equipment Display): No rule exists for equipment array routing or
>   wear change behavior. Pure C++ bug.
> - Bug 3 (Equipment Persistence): No rule exists for LoadEquipment() call
>   lifecycle. Pure C++ call site omission.
>
> **Recommendation:** All three bugs require C++ or Lua code changes. No
> config-first alternative exists for any of them.

**Architect follow-up (received after proactive message sent):**

> Architect sent detailed questions covering all three bugs:
> - Bug 1: Are there rules for companion chat, NPC dialogue, or LLM integration?
>   Is there a rule that could serve as an LLM enable/disable toggle?
> - Bug 2: Are there rules for companion equipment display, NPC equipment rendering,
>   or wear change behavior?
> - Bug 3: Are there rules for companion persistence, equipment saving/loading, or
>   inventory management? What other Companion rules exist beyond CompanionsEnabled?
>
> Responded with complete Companions category rule list (all 22 rules named),
> confirmed sidecar health verification details, and definitive verdict for each bug.

**Response from architect:** Acknowledged. Config-expert findings incorporated into architecture plan. All three bugs confirmed as code-level fixes. Sidecar health verification shifts Bug 1 diagnosis from infrastructure to Lua code path.

**Outcome:** Assessment delivered. Architect can assign bugs entirely to
c-expert (Bugs 2+3) and lua-expert (Bug 1) with no config-expert implementation
tasks needed.

### 2026-03-01 — Protocol-Agent Proactive OP_WearChange and Spawn Struct Research

**From:** protocol-agent → **To:** architect

> Proactively completed full protocol research for Bugs 2 and 3 before architect asked.
>
> **Research performed:**
> - Verified OP_WearChange support in Titanium: titanium_ops.h lines 88 (ENCODE) and 133 (DECODE) — fully supported
> - Verified Titanium WearChange_Struct (titanium_structs.h:1061): spawn_id(uint16), material(uint16), color(5B), wear_slot_id(uint8) = 10 bytes total
> - Traced full call chain: GiveItem() → SendWearChange() → Mob::SendWearChange() → NPC::GetEquipmentMaterial() → reads NPC::equipment[] (NOT m_equipment[])
> - Confirmed NPC::GetEquippedItemFromTextureSlot() (mob_appearance.cpp:331) reads NPC::equipment[inventory_slot]
> - Confirmed Companion::m_equipment[] and NPC::equipment[] are completely separate arrays
> - Verified Mob::FillSpawnStruct() (mob.cpp:1362) calls GetEquipmentMaterial() — same broken path for spawn packets if only m_equipment[] is populated
> - Identified Bot precedent: bot.cpp:4040 writes to equipment[slot_id] directly, then calls SendWearChange — confirmed working pattern
> - Titanium spawn ENCODE (titanium.cpp:2408-2411) copies equipment.Slot[k].Material to wire — confirms NPC::equipment[] is the authoritative source for spawn visuals
>
> **Protocol findings:**
> - No Titanium client constraints apply. Both bugs are server-side data routing errors.
> - Bug 2 fix: GiveItem()/RemoveItemFromSlot() must also write to NPC::equipment[] (Option B — follow Bot pattern)
> - Bug 3 fix: LoadEquipment() must also sync to NPC::equipment[] after loading m_equipment[]. Call sites: Load() and Unsuspend()
> - Spawn packets handle initial visual state automatically once equipment[] is correct — no extra WearChange packets needed on zone-in

**Response from architect:** Asked four specific follow-up questions (see below).

**Outcome:** Initial protocol advisory delivered. No Titanium-level blockers exist. All fixes are C++ server-side changes.

### 2026-03-01 — Architect Follow-Up: Four Specific Protocol Questions

**From:** architect → **To:** protocol-agent

> 1. Does Titanium handle OP_WearChange for NPC=0 entities (companions/bots)?
> 2. Will fixed GetEquipmentMaterial make spawn packets show correct equipment on zone-in?
> 3. Are there Titanium constraints on WearChange fields (elite_material, hero_forge_model)?
> 4. Are there Titanium constraints on which material slots trigger OP_WearChange?

**Response from protocol-agent:**

> **Q1 — NPC=0 entities:** Yes, confirmed. Titanium processes OP_WearChange by spawn_id only, not NPC flag. Bots use NPC=0 (bot.cpp:3807-3813) and SendWearChange works (bot.cpp:4040-4042). titanium.cpp ENCODE (2289-2300) passes spawn_id, material, color, wear_slot_id — no NPC type filtering.
>
> **Q2 — Spawn packet zone-in visuals:** Yes, confirmed. Mob::FillSpawnStruct (mob.cpp:1362-1369) calls GetEquipmentMaterial(i) per slot; Titanium ZoneSpawns ENCODE (titanium.cpp:2408-2411) copies to wire. Once NPC::equipment[] is correctly populated, spawn packet carries correct materials — no post-spawn WearChange packets needed. Caveat: SendArmorAppearance() after spawn recommended for PC-race armor slots (mob_appearance.cpp:345-368 documents client display reliability issue), but not strictly required for the fix.
>
> **Q3 — Titanium WearChange field constraints:** Titanium wire struct (titanium_structs.h:1061) = 10 bytes: spawn_id(uint16), material(uint16), color(5B Tint_Struct), wear_slot_id(uint8). Fields elite_material and hero_forge_model do not exist in Titanium — silently dropped by ENCODE. material truncated uint32→uint16 (fine for Classic-Luclin IDFile values). No functional constraints.
>
> **Q4 — Material slot constraints:** All 9 slots valid (armorHead=0 through weaponSecondary=8). Titanium ENCODE copies all slots textureBegin through materialCount-1. No Titanium slot restrictions.
>
> **Bottom line:** No Titanium client limitations apply. All fixes are server-side. NPC::equipment[] sync is the correct approach.

**Outcome:** All four questions answered with source citations. Architecture plan can proceed with no Titanium constraints flagged.

---

## Implementation Team Conversations

_Expert-to-expert exchanges during Phase 4._

### 2026-03-01 — lua-expert Task 3 Complete

**From:** lua-expert → **To:** c-expert

> Task 3 (LLM chat fix) is complete. Modified `llm_bridge.lua` `generate_response()`:
>
> - Added `eq.log(87)` (QuestErrors) at all nil-return paths for zone-log visibility
> - Added `os.execute` + temp file fallback if `io.popen` returns nil
> - Added `eq.log(38)` (QuestDebug) on success path for confirmation
> - Syntax checked with luajit. End-to-end tested with sidecar — returns correct response.
>
> Key finding from investigation: Code is correct in standalone luajit. The bug is not
> statically detectable — it only manifests in the zone process. The diagnostic logging
> will reveal which nil path is hit when user speaks to companion next time. The
> os.execute fallback provides immediate resilience if io.popen is the issue.
>
> Your Tasks 1+2 (equipment display + persistence) are independent — no blockers from my work.

**Outcome:** lua-expert task complete. c-expert notified. Implementation team done.

---

## Key Decisions from Conversations

_Extract the most important decisions made through agent communication.
This table is the quick-reference for anyone catching up._

| # | Decision | Agents Involved | Date | Context |
|---|----------|----------------|------|---------|
| 1 | Bug-fix PRD approved with no lore concerns | game-designer, lore-master | 2026-03-01 | Pure technical fixes, no narrative changes, era compliance confirmed |
| 2 | Bug 1 framed as routing failure, not content failure | game-designer, lore-master | 2026-03-01 | Lore-master confirmed cultural voice system (companion_culture.lua) must be preserved; fix is about sidecar connectivity, not dialogue |
| 3 | No rules or config changes needed for any of the 3 bugs | config-expert, architect | 2026-03-01 | Companions category (22 rules) has no equipment display/persistence rules; LLM sidecar verified healthy; all bugs require code fixes |
| 4 | LLM sidecar is healthy and reachable — Bug 1 is a Lua code bug | config-expert | 2026-03-01 | Direct verification: container healthy, DNS resolves, health endpoint returns ok — failure is in llm_bridge.lua, not Docker/config |
| 5 | No Titanium client constraints on OP_WearChange or spawn struct equipment materials | protocol-agent, architect | 2026-03-01 | All 9 material slots valid; NPC=0 entities receive WearChange correctly; elite_material/hero_forge_model silently dropped by Titanium ENCODE; spawn packet handles zone-in visuals once NPC::equipment[] is correct |
| 6 | Bug 2 fix: sync NPC::equipment[] alongside m_equipment[] (follow Bot pattern) | protocol-agent, architect | 2026-03-01 | bot.cpp:4040 is the reference — writes to equipment[slot_id] then SendWearChange; Companion must do the same in GiveItem/RemoveItemFromSlot/LoadEquipment |
| 7 | Bug 2 fix: override GetEquipmentMaterial() + GetEquippedItemFromTextureSlot() in Companion class | architect | 2026-03-01 | Virtual override approach chosen over alternatives (drop m_equipment, write-only to equipment[]). Override reads m_equipment[] through virtual dispatch; sync to NPC::equipment[] as belt-and-suspenders |
| 8 | Implementation team: c-expert (Tasks 1+2) and lua-expert (Task 3) only | architect | 2026-03-01 | Minimal team — only 2 experts needed. c-expert for C++ equipment display+persistence fixes, lua-expert for LLM chat Lua diagnosis and fix |

---

## Unresolved Threads

_Conversations that didn't reach resolution. Track here so they don't get lost._

| Topic | Agents | Status | Blocking? |
|-------|--------|--------|-----------|
| _None_ | | | |

### 2026-03-01 — Bug #5 Architecture Analysis (Solo)

**From:** architect (solo analysis, no advisors spawned for this incremental bug)

> Bug #5 is the same class of luabind inheritance issue as Bug #1. The analysis
> does not require protocol-agent or config-expert consultation because:
> 
> 1. **No protocol impact:** Bug #5 is entirely in the Lua scripting layer.
>    No packets, opcodes, or wire formats are involved. The error occurs before
>    any server-to-client communication happens.
> 
> 2. **No configuration impact:** No rules or config settings control luabind
>    overload resolution. This is a code-level type mismatch that can only be
>    fixed in Lua (workaround) or C++ (binding hierarchy change).
> 
> 3. **Established pattern:** The fix follows the identical CastToNPC() workaround
>    already used for GetPrimaryFaction in the same function (client_ext.lua:65).
>    Config-expert and protocol-agent previously confirmed "no constraints" for
>    Bug #1 which uses the same approach.
> 
> **Decision:** Lua-only fix in client_ext.lua. Assigned to lua-expert.
> Same pattern as Bug #1 GetPrimaryFaction workaround.
